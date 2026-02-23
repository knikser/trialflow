using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrialFlow.Organization.Infrastructure;

namespace TrialFlow.Organization;

public static class OrganizationContextServiceCollectionExtensions
{
    public static IServiceCollection AddOrganizationContext(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<OrganizationDbContext>(options =>
            options.UseNpgsql(connectionString));
        return services;
    }
}
