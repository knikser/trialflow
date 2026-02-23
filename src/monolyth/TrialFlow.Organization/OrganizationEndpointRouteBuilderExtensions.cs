using Microsoft.AspNetCore.Routing;
using TrialFlow.Organization.Features.CreateOrganization;

namespace TrialFlow.Organization;

public static class OrganizationEndpointRouteBuilderExtensions
{
    public static IEndpointRouteBuilder MapOrganizationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapCreateOrganization();
        return app;
    }
}
