using System.Security.Claims;
using Microsoft.Extensions.Options;

namespace TrialFlow.Api.Auth;

/// <summary>
/// JWT stub: reads Authorization header, extracts or injects claims (user_id, org_id, role, group, permissions, permissions_version).
/// No real validation — for local development until Auth0 is integrated.
/// </summary>
public sealed class JwtStubMiddleware
{
    public const string UserIdClaim = "user_id";
    public const string OrgIdClaim = "org_id";
    public const string RoleClaim = "role";
    public const string GroupClaim = "group";
    public const string PermissionsClaim = "permissions";
    public const string PermissionsVersionClaim = "permissions_version";

    private readonly RequestDelegate _next;
    private readonly JwtStubOptions _options;

    public JwtStubMiddleware(RequestDelegate next, IOptions<JwtStubOptions> options)
    {
        _next = next;
        _options = options.Value;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (!_options.Enabled)
        {
            await _next(context);
            return;
        }

        var claims = new List<Claim>();

        // Try to parse a stub token: "Bearer stub:user_id=...;org_id=...;role=...;group=...;permissions=..."
        var authHeader = context.Request.Headers.Authorization.FirstOrDefault();
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
                            "user_id" => new Claim(UserIdClaim, value),
                            "org_id" => new Claim(OrgIdClaim, value),
                            "role" => new Claim(RoleClaim, value),
                            "group" => new Claim(GroupClaim, value),
                            "permissions" => new Claim(PermissionsClaim, value),
                            "permissions_version" => new Claim(PermissionsVersionClaim, value),
                            _ => new Claim(key, value)
                        });
                    }
                }
            }
        }

        // Fill defaults for any missing claims
        if (!claims.Any(c => c.Type == UserIdClaim))
            claims.Add(new Claim(UserIdClaim, _options.DefaultUserId));
        if (!claims.Any(c => c.Type == OrgIdClaim))
            claims.Add(new Claim(OrgIdClaim, _options.DefaultOrgId));
        if (!claims.Any(c => c.Type == RoleClaim))
            claims.Add(new Claim(RoleClaim, _options.DefaultRole));
        if (!claims.Any(c => c.Type == GroupClaim))
            claims.Add(new Claim(GroupClaim, _options.DefaultGroup));
        if (!claims.Any(c => c.Type == PermissionsClaim))
            claims.Add(new Claim(PermissionsClaim, _options.DefaultPermissions));
        if (!claims.Any(c => c.Type == PermissionsVersionClaim))
            claims.Add(new Claim(PermissionsVersionClaim, _options.PermissionsVersion.ToString()));

        var identity = new ClaimsIdentity(claims, "Stub");
        context.User = new ClaimsPrincipal(identity);

        await _next(context);
    }
}
