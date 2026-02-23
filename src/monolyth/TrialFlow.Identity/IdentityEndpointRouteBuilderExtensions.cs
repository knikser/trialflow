using Microsoft.AspNetCore.Routing;
using TrialFlow.Identity.Features.RegisterAccount;

namespace TrialFlow.Identity;

public static class IdentityEndpointRouteBuilderExtensions
{
    public static IEndpointRouteBuilder MapIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapRegisterAccount();
        return app;
    }
}
