using MassTransit;
using MediatR;
using TrialFlow.Contracts.Events;
using TrialFlow.Study.Infrastructure;

namespace TrialFlow.Study.Features.CreateStudy;

public sealed class CreateStudyHandler(StudyDbContext dbContext, IPublishEndpoint publishEndpoint)
    : IRequestHandler<CreateStudyCommand, CreateStudyResult>
{
    public async Task<CreateStudyResult> Handle(CreateStudyCommand request, CancellationToken cancellationToken)
    {
        var study = Domain.Study.Create(request.Title, request.Description);
        dbContext.Studies.Add(study);
        await dbContext.SaveChangesAsync(cancellationToken);

        await publishEndpoint.Publish(
            new StudyCreated(study.Id, study.Title, study.CreatedAt),
            cancellationToken);

        return new CreateStudyResult(study.Id, study.Title, study.CreatedAt);
    }
}