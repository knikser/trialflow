namespace TrialFlow.Contracts.Events;

/// <summary>
/// Published when a new organization is created (Sponsor or ResearchSite).
/// </summary>
public record OrganizationCreated(
    Guid OrganizationId,
    string Name,
    string Role,
    DateTimeOffset CreatedAt);
