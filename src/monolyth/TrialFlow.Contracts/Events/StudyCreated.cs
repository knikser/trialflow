namespace TrialFlow.Contracts.Events;

/// <summary>
/// Published when a new study is created (catalog entry, no sponsor yet).
/// </summary>
public record StudyCreated(
    Guid StudyId,
    string Title,
    DateTimeOffset CreatedAt);
