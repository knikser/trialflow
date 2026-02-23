using MediatR;

namespace TrialFlow.Study.Features.CreateStudy;

public record CreateStudyCommand(string Title, string Description) : IRequest<CreateStudyResult>;

public record CreateStudyResult(Guid StudyId, string Title, DateTimeOffset CreatedAt);
