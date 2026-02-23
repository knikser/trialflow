namespace TrialFlow.Contracts.Utilities.Api;

/// <summary>
/// Non-generic API response envelope (no data payload).
/// </summary>
public sealed record ApiResponse(
    bool Success,
    string? TraceId,
    ApiError? Error = null)
{
    public static ApiResponse Ok(string traceId)
        => new(true, traceId, null);

    public static ApiResponse Fail(ApiError error, string traceId)
        => new(false, traceId, error);
}
