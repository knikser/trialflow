namespace TrialFlow.Identity.Domain;

public sealed class Account
{
    public Guid Id { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string PasswordHash { get; private set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; private set; }

    private Account() { }

    public static Account Create(string email, string passwordHash)
    {
        var now = DateTimeOffset.UtcNow;
        return new Account
        {
            Id = Guid.NewGuid(),
            Email = email,
            PasswordHash = passwordHash,
            CreatedAt = now
        };
    }
}
