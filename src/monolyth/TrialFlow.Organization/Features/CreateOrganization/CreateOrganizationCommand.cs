using MediatR;
using TrialFlow.Organization.Domain;

namespace TrialFlow.Organization.Features.CreateOrganization;

public record CreateOrganizationCommand(string Name, OrganizationRole Role) : IRequest<CreateOrganizationResult>;

public record CreateOrganizationResult(Guid OrganizationId, string Name, string Role, DateTimeOffset CreatedAt);
