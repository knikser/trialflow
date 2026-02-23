namespace TrialFlow.Contracts.Utilities.Api;

/// <summary>
/// Unified error representation for API responses. Use factory methods to create.
/// </summary>
public sealed record ApiError(
    string Code,
    string? Message = null,
    IReadOnlyDictionary<string, string[]>? FieldErrors = null)
{
    public static ApiError Validation(string message, IReadOnlyDictionary<string, string[]>? fieldErrors = null)
        => new("Validation", message, fieldErrors);

    public static ApiError NotFound(string message)
        => new("NotFound", message, null);

    public static ApiError Conflict(string message)
        => new("Conflict", message, null);

    public static ApiError Unauthorized()
        => new("Unauthorized", "Authentication is required.", null);

    public static ApiError Forbidden()
        => new("Forbidden", "You do not have permission to perform this action.", null);

    public static ApiError Internal()
        => new("Internal", "An unexpected error occurred.", null);
}
