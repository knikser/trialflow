namespace TrialFlow.Study.Domain;

/// <summary>
/// Study aggregate. Created without a Sponsor (catalog entry); can be linked via StudyLinked event.
/// Only Draft studies can be updated or deleted. Must be linked to Sponsor before publishing.
/// </summary>
public sealed class Study
{
    public Guid Id { get; private set; }
    public string Title { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public StudyStatus Status { get; private set; }
    public Guid? SponsorId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    private Study() { }

    /// <summary>
    /// Factory: create a new study in Draft status, without a sponsor.
    /// </summary>
    public static Study Create(string title, string description)
    {
        var now = DateTimeOffset.UtcNow;
        return new Study
        {
            Id = Guid.NewGuid(),
            Title = title,
            Description = description,
            Status = StudyStatus.Draft,
            SponsorId = null,
            CreatedAt = now,
            UpdatedAt = now
        };
    }
}
