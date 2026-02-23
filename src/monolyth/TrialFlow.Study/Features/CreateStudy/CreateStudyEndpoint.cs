using MediatR;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using TrialFlow.Contracts.Utilities.Api;

namespace TrialFlow.Study.Features.CreateStudy;

public static class CreateStudyEndpoint
{
    public static IEndpointRouteBuilder MapCreateStudy(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/studies", async (HttpContext httpContext, CreateStudyRequest request, IMediator mediator, CancellationToken ct) =>
        {
            var result = await mediator.Send(
                new CreateStudyCommand(request.Title, request.Description),
                ct);
            var response = ApiResponse<CreateStudyResult>.Ok(result, httpContext.TraceIdentifier);
            return Results.Created($"/api/studies/{result.StudyId}", response);
        })
        .RequireAuthorization()
        .WithName("CreateStudy")
        .WithTags("Study");

        return app;
    }

    public record CreateStudyRequest(string Title, string Description);
}
