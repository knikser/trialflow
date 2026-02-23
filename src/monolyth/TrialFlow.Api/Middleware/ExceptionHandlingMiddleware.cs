using System.Text.Json;
using FluentValidation;
using Microsoft.AspNetCore.Http;
using TrialFlow.Contracts.Utilities.Api;

namespace TrialFlow.Api.Middleware;

/// <summary>
/// Catches all unhandled exceptions, logs them, and returns a unified ApiResponse envelope.
/// Never leaks stack traces or exception messages to the client for 500 errors.
///
/// Domain exception → ApiError mapping:
/// | Exception type           | HTTP | ApiError              |
/// |--------------------------|------|------------------------|
/// | ValidationException      | 400  | ApiError.Validation()  |
/// | NotFoundException        | 404  | ApiError.NotFound()    |
/// | DomainException          | 409  | ApiError.Conflict()    |
/// | UnauthorizedException    | 401  | ApiError.Unauthorized()|
/// | ForbiddenException       | 403  | ApiError.Forbidden()   |
/// | (any other)              | 500  | ApiError.Internal()    |
/// </summary>
public sealed class ExceptionHandlingMiddleware
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception ex)
    {
        var traceId = context.TraceIdentifier;

        var (statusCode, apiError) = MapExceptionToApiError(ex);

        if (statusCode == StatusCodes.Status500InternalServerError)
            _logger.LogError(ex, "Unhandled exception. TraceId: {TraceId}", traceId);
        else
            _logger.LogWarning(ex, "Domain/validation exception mapped to {StatusCode}. TraceId: {TraceId}", statusCode, traceId);

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";

        var response = ApiResponse.Fail(apiError, traceId);
        await context.Response.WriteAsJsonAsync(response, JsonOptions);
    }

    private static (int StatusCode, ApiError Error) MapExceptionToApiError(Exception ex)
    {
        return ex switch
        {
            ValidationException validationEx => (
                StatusCodes.Status400BadRequest,
                ApiError.Validation(
                    validationEx.Message,
                    validationEx.Errors
                        .GroupBy(e => JsonNamingPolicy.CamelCase.ConvertName(e.PropertyName))
                        .ToDictionary(g => g.Key, g => g.Select(f => f.ErrorMessage).ToArray()))),
            _ when IsNotFoundException(ex) => (
                StatusCodes.Status404NotFound,
                ApiError.NotFound(ex.Message)),
            _ when IsDomainException(ex) => (
                StatusCodes.Status409Conflict,
                ApiError.Conflict(ex.Message)),
            _ when IsUnauthorizedException(ex) => (
                StatusCodes.Status401Unauthorized,
                ApiError.Unauthorized()),
            _ when IsForbiddenException(ex) => (
                StatusCodes.Status403Forbidden,
                ApiError.Forbidden()),
            _ => (
                StatusCodes.Status500InternalServerError,
                ApiError.Internal())
        };
    }

    private static bool IsNotFoundException(Exception ex)
    {
        return ex.GetType().Name == "NotFoundException";
    }

    private static bool IsDomainException(Exception ex)
    {
        return ex.GetType().Name == "DomainException";
    }

    private static bool IsUnauthorizedException(Exception ex)
    {
        return ex is UnauthorizedAccessException || ex.GetType().Name == "UnauthorizedException";
    }

    private static bool IsForbiddenException(Exception ex)
    {
        return ex.GetType().Name == "ForbiddenException";
    }
}
