using MediatR;
using TrialFlow.Contracts.Events;
using TrialFlow.Study.Domain;
using TrialFlow.Study.Infrastructure;
using MassTransit;

namespace TrialFlow.Study.Features.CreateStudy;

public sealed class CreateStudyHandler : IRequestHandler<CreateStudyCommand, CreateStudyResult>
{
    private readonly StudyDbContext _dbContext;
    private readonly IPublishEndpoint _publishEndpoint;

    public CreateStudyHandler(StudyDbContext dbContext, IPublishEndpoint publishEndpoint)
    {
        _dbContext = dbContext;
        _publishEndpoint = publishEndpoint;
    }

    public async Task<CreateStudyResult> Handle(CreateStudyCommand request, CancellationToken cancellationToken)
    {
        var study = Domain.Study.Create(request.Title, request.Description);
        _dbContext.Studies.Add(study);
        await _dbContext.SaveChangesAsync(cancellationToken);

        await _publishEndpoint.Publish(
            new StudyCreated(study.Id, study.Title, study.CreatedAt),
            cancellationToken);

        return new CreateStudyResult(study.Id, study.Title, study.CreatedAt);
    }
}