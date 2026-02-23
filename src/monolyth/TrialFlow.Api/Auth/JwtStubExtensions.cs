using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;

namespace TrialFlow.Api.Auth;

public static class JwtStubExtensions
{
    public static IServiceCollection AddJwtStubAuth(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<JwtStubOptions>(configuration.GetSection(JwtStubOptions.SectionName));
        services.AddAuthentication("Stub")
            .AddScheme<AuthenticationSchemeOptions, JwtStubAuthenticationHandler>("Stub", _ => { });
        services.AddAuthorizationBuilder()
            .SetDefaultPolicy(new AuthorizationPolicyBuilder("Stub")
                .RequireAuthenticatedUser()
                .Build());
        return services;
    }

    public static IApplicationBuilder UseJwtStubAuth(this IApplicationBuilder app)
    {
        app.UseAuthentication();
        app.UseAuthorization();
        return app;
    }
}
