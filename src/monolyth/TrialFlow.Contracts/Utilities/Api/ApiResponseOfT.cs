namespace TrialFlow.Contracts.Utilities.Api;

/// <summary>
/// Generic API response envelope with data payload.
/// </summary>
public sealed record ApiResponse<T>(
    bool Success,
    T? Data,
    string? TraceId,
    ApiError? Error = null)
{
    public static ApiResponse<T> Ok(T data, string traceId)
        => new(true, data, traceId, null);

    public static ApiResponse<T> Fail(ApiError error, string traceId)
        => new(false, default, traceId, error);
}
