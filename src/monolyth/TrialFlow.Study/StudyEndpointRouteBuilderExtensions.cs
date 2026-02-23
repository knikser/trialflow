using Microsoft.AspNetCore.Routing;
using TrialFlow.Study.Features.CreateStudy;

namespace TrialFlow.Study;

public static class StudyEndpointRouteBuilderExtensions
{
    public static IEndpointRouteBuilder MapStudyEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapCreateStudy();
        return app;
    }
}
