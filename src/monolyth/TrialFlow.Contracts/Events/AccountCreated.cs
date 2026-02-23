namespace TrialFlow.Contracts.Events;

/// <summary>
/// Published when a new account is registered.
/// </summary>
public record AccountCreated(
    Guid AccountId,
    string Email,
    DateTimeOffset CreatedAt);
