using FluentValidation;
using MassTransit;
using MediatR;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using TrialFlow.Api.Auth;
using TrialFlow.Api.Behaviors;
using TrialFlow.Api.Middleware;
using TrialFlow.Contracts.Utilities.Api;
using TrialFlow.Study;
using TrialFlow.Identity;
using TrialFlow.Organization;
using TrialFlow.Study.Infrastructure;
using TrialFlow.Identity.Infrastructure;
using TrialFlow.Organization.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// OpenTelemetry
var otelServiceName = builder.Configuration["OpenTelemetry:ServiceName"] ?? "TrialFlow.Api";
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService(otelServiceName))
    .WithTracing(t =>
    {
        t.AddAspNetCoreInstrumentation();
        t.AddSource("TrialFlow.*");
        t.AddOtlpExporter(o =>
        {
            o.Endpoint = new Uri(builder.Configuration["OpenTelemetry:Otlp:Endpoint"] ??
                                 "http://localhost:4317/v1/traces");
        });
    })
    .WithMetrics(m =>
    {
        m.AddAspNetCoreInstrumentation();
        m.AddRuntimeInstrumentation();
        m.AddOtlpExporter(o =>
        {
            o.Endpoint = new Uri(builder.Configuration["OpenTelemetry:Otlp:MetricsEndpoint"] ??
                                 "http://localhost:4317/v1/metrics");
        });
    });

// MediatR + FluentValidation pipeline
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(typeof(StudyAssemblyMarker).Assembly);
    cfg.RegisterServicesFromAssembly(typeof(IdentityAssemblyMarker).Assembly);
    cfg.RegisterServicesFromAssembly(typeof(OrganizationAssemblyMarker).Assembly);
});
builder.Services.AddValidatorsFromAssembly(typeof(StudyAssemblyMarker).Assembly);
builder.Services.AddValidatorsFromAssembly(typeof(IdentityAssemblyMarker).Assembly);
builder.Services.AddValidatorsFromAssembly(typeof(OrganizationAssemblyMarker).Assembly);
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));

// Bounded contexts
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
                       ?? "Host=localhost;Port=5432;Database=trialflow;Username=trialflow;Password=trialflow";
builder.Services.AddStudyContext(connectionString);
builder.Services.AddIdentityContext(connectionString);
builder.Services.AddOrganizationContext(connectionString);

// MassTransit + RabbitMQ
builder.Services.AddMassTransit(x =>
{
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMQ:Host"] ?? "localhost", "/", h =>
        {
            h.Username(builder.Configuration["RabbitMQ:Username"] ?? "guest");
            h.Password(builder.Configuration["RabbitMQ:Password"] ?? "guest");
        });
        cfg.ConfigureEndpoints(context);
    });
});

// JWT stub auth
builder.Services.AddJwtStubAuth(builder.Configuration);

builder.Services.AddOpenApi();

var app = builder.Build();

// Outermost: unified exception handling and ApiResponse envelope
app.UseMiddleware<ExceptionHandlingMiddleware>();

app.UseHttpsRedirection();
app.UseJwtStubAuth();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapStudyEndpoints();
app.MapIdentityEndpoints();
app.MapOrganizationEndpoints();

// Health for Docker
app.MapGet("/health", (HttpContext ctx) => Results.Ok(ApiResponse.Ok(ctx.TraceIdentifier)))
    .WithName("Health")
    .AllowAnonymous();

app.Run();