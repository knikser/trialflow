using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace TrialFlow.Api.Auth;

/// <summary>
/// JWT stub: reads Authorization header, extracts or injects claims (user_id, org_id, role, group, permissions, permissions_version).
/// No real validation — for local development until Auth0 is integrated.
/// </summary>
public sealed class JwtStubAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly JwtStubOptions _options;

    public JwtStubAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        IOptions<JwtStubOptions> stubOptions,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder)
    {
        _options = stubOptions.Value;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!_options.Enabled)
        {
            var anon = new ClaimsPrincipal(new ClaimsIdentity());
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(anon, Scheme.Name)));
        }

        var claims = new List<Claim>();
        var authHeader = Context.Request.Headers.Authorization.FirstOrDefault();
        if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            var token = authHeader["Bearer ".Length..].Trim();
            if (token.StartsWith("stub:", StringComparison.OrdinalIgnoreCase))
            {
                var pairs = token["stub:".Length..].Split(';');
                foreach (var pair in pairs)
                {
                    var kv = pair.Split('=', 2, StringSplitOptions.TrimEntries);
                    if (kv.Length == 2)
                    {
                        var key = kv[0].ToLowerInvariant();
                        var value = kv[1];
                        claims.Add(key switch
                        {
                            "user_id" => new Claim(JwtStubMiddleware.UserIdClaim, value),
                            "org_id" => new Claim(JwtStubMiddleware.OrgIdClaim, value),
                            "role" => new Claim(JwtStubMiddleware.RoleClaim, value),
                            "group" => new Claim(JwtStubMiddleware.GroupClaim, value),
                            "permissions" => new Claim(JwtStubMiddleware.PermissionsClaim, value),
                            "permissions_version" => new Claim(JwtStubMiddleware.PermissionsVersionClaim, value),
                            _ => new Claim(key, value)
                        });
                    }
                }
            }
        }

        if (!claims.Any(c => c.Type == JwtStubMiddleware.UserIdClaim))
            claims.Add(new Claim(JwtStubMiddleware.UserIdClaim, _options.DefaultUserId));
        if (!claims.Any(c => c.Type == JwtStubMiddleware.OrgIdClaim))
            claims.Add(new Claim(JwtStubMiddleware.OrgIdClaim, _options.DefaultOrgId));
        if (!claims.Any(c => c.Type == JwtStubMiddleware.RoleClaim))
            claims.Add(new Claim(JwtStubMiddleware.RoleClaim, _options.DefaultRole));
        if (!claims.Any(c => c.Type == JwtStubMiddleware.GroupClaim))
            claims.Add(new Claim(JwtStubMiddleware.GroupClaim, _options.DefaultGroup));
        if (!claims.Any(c => c.Type == JwtStubMiddleware.PermissionsClaim))
            claims.Add(new Claim(JwtStubMiddleware.PermissionsClaim, _options.DefaultPermissions));
        if (!claims.Any(c => c.Type == JwtStubMiddleware.PermissionsVersionClaim))
            claims.Add(new Claim(JwtStubMiddleware.PermissionsVersionClaim, _options.PermissionsVersion.ToString()));

        var identity = new ClaimsIdentity(claims, "Stub");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, Scheme.Name);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
