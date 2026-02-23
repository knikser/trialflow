using MediatR;
using TrialFlow.Contracts.Events;
using TrialFlow.Identity.Domain;
using TrialFlow.Identity.Infrastructure;
using MassTransit;

namespace TrialFlow.Identity.Features.RegisterAccount;

public sealed class RegisterAccountHandler : IRequestHandler<RegisterAccountCommand, RegisterAccountResult>
{
    private readonly IdentityDbContext _dbContext;
    private readonly IPublishEndpoint _publishEndpoint;

    public RegisterAccountHandler(IdentityDbContext dbContext, IPublishEndpoint publishEndpoint)
    {
        _dbContext = dbContext;
        _publishEndpoint = publishEndpoint;
    }

    public async Task<RegisterAccountResult> Handle(RegisterAccountCommand request, CancellationToken cancellationToken)
    {
        // Stub: store password as-is (no real hashing yet)
        var passwordHash = "[stub]" + request.Password;
        var account = Account.Create(request.Email, passwordHash);
        _dbContext.Accounts.Add(account);
        await _dbContext.SaveChangesAsync(cancellationToken);

        await _publishEndpoint.Publish(
            new AccountCreated(account.Id, account.Email, account.CreatedAt),
            cancellationToken);

        return new RegisterAccountResult(account.Id, account.Email, account.CreatedAt);
    }
}
