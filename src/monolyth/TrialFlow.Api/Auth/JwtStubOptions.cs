namespace TrialFlow.Api.Auth;

public sealed class JwtStubOptions
{
    public const string SectionName = "JwtStub";

    /// <summary>
    /// When true, stub accepts any Bearer token and parses claims from header or uses defaults.
    /// </summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Default user_id claim when not present in token (for local dev).
    /// </summary>
    public string DefaultUserId { get; set; } = "00000000-0000-0000-0000-000000000001";

    /// <summary>
    /// Default org_id claim when not present.
    /// </summary>
    public string DefaultOrgId { get; set; } = "00000000-0000-0000-0000-000000000002";

    /// <summary>
    /// Default role claim when not present.
    /// </summary>
    public string DefaultRole { get; set; } = "Admin";

    /// <summary>
    /// Default group claim when not present.
    /// </summary>
    public string DefaultGroup { get; set; } = "Default";

    /// <summary>
    /// Default permissions (comma-separated) when not present.
    /// </summary>
    public string DefaultPermissions { get; set; } = "study:create,organization:create";

    /// <summary>
    /// Permissions version for cache invalidation.
    /// </summary>
    public int PermissionsVersion { get; set; } = 1;
}
