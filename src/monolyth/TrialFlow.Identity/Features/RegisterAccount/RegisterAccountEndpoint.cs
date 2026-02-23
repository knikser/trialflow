using MediatR;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using TrialFlow.Contracts.Utilities.Api;

namespace TrialFlow.Identity.Features.RegisterAccount;

public static class RegisterAccountEndpoint
{
    public static IEndpointRouteBuilder MapRegisterAccount(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/accounts/register", async (HttpContext httpContext, RegisterAccountRequest request, IMediator mediator, CancellationToken ct) =>
        {
            var result = await mediator.Send(
                new RegisterAccountCommand(request.Email, request.Password),
                ct);
            var response = ApiResponse<RegisterAccountResult>.Ok(result, httpContext.TraceIdentifier);
            return Results.Created($"/api/accounts/{result.AccountId}", response);
        })
        .RequireAuthorization()
        .WithName("RegisterAccount")
        .WithTags("Identity");

        return app;
    }

    public record RegisterAccountRequest(string Email, string Password);
}
