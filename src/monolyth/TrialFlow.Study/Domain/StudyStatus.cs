namespace TrialFlow.Study.Domain;

/// <summary>
/// Study lifecycle: Draft → Published → Deleted.
/// </summary>
public enum StudyStatus
{
    Draft = 0,
    Published = 1,
    Deleted = 2
}
