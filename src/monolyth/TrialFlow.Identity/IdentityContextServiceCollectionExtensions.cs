using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrialFlow.Identity.Infrastructure;

namespace TrialFlow.Identity;

public static class IdentityContextServiceCollectionExtensions
{
    public static IServiceCollection AddIdentityContext(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<IdentityDbContext>(options =>
            options.UseNpgsql(connectionString)
                .UseSnakeCaseNamingConvention());
        return services;
    }
}