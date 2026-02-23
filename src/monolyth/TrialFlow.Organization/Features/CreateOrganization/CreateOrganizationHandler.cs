using MassTransit;
using MediatR;
using TrialFlow.Contracts.Events;
using TrialFlow.Organization.Infrastructure;

namespace TrialFlow.Organization.Features.CreateOrganization;

public sealed class CreateOrganizationHandler : IRequestHandler<CreateOrganizationCommand, CreateOrganizationResult>
{
    private readonly OrganizationDbContext _dbContext;
    private readonly IPublishEndpoint _publishEndpoint;

    public CreateOrganizationHandler(OrganizationDbContext dbContext, IPublishEndpoint publishEndpoint)
    {
        _dbContext = dbContext;
        _publishEndpoint = publishEndpoint;
    }

    public async Task<CreateOrganizationResult> Handle(CreateOrganizationCommand request, CancellationToken cancellationToken)
    {
        var organization = Domain.Organization.Create(request.Name, request.Role);
        _dbContext.Organizations.Add(organization);
        await _dbContext.SaveChangesAsync(cancellationToken);

        await _publishEndpoint.Publish(
            new OrganizationCreated(organization.Id, organization.Name, organization.Role.ToString(), organization.CreatedAt),
            cancellationToken);

        return new CreateOrganizationResult(
            organization.Id,
            organization.Name,
            organization.Role.ToString(),
            organization.CreatedAt);
    }
}
