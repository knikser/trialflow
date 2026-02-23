using MediatR;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using TrialFlow.Contracts.Utilities.Api;
using TrialFlow.Organization.Domain;

namespace TrialFlow.Organization.Features.CreateOrganization;

public static class CreateOrganizationEndpoint
{
    public static IEndpointRouteBuilder MapCreateOrganization(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/organizations", async (HttpContext httpContext, CreateOrganizationRequest request, IMediator mediator, CancellationToken ct) =>
        {
            var role = Enum.Parse<OrganizationRole>(request.Role, ignoreCase: true);
            var result = await mediator.Send(
                new CreateOrganizationCommand(request.Name, role),
                ct);
            var response = ApiResponse<CreateOrganizationResult>.Ok(result, httpContext.TraceIdentifier);
            return Results.Created($"/api/organizations/{result.OrganizationId}", response);
        })
        .RequireAuthorization()
        .WithName("CreateOrganization")
        .WithTags("Organization");

        return app;
    }

    public record CreateOrganizationRequest(string Name, string Role);
}
