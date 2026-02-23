using MediatR;

namespace TrialFlow.Identity.Features.RegisterAccount;

public record RegisterAccountCommand(string Email, string Password) : IRequest<RegisterAccountResult>;

public record RegisterAccountResult(Guid AccountId, string Email, DateTimeOffset CreatedAt);
