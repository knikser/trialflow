using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TrialFlow.Study.Infrastructure;

namespace TrialFlow.Study;

public static class StudyContextServiceCollectionExtensions
{
    public static IServiceCollection AddStudyContext(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<StudyDbContext>(options =>
            options.UseNpgsql(connectionString)
                .UseSnakeCaseNamingConvention());
        return services;
    }
}