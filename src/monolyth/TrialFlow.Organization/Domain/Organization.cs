namespace TrialFlow.Organization.Domain;

public sealed class Organization
{
    public Guid Id { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public OrganizationRole Role { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    private Organization() { }

    public static Organization Create(string name, OrganizationRole role)
    {
        var now = DateTimeOffset.UtcNow;
        return new Organization
        {
            Id = Guid.NewGuid(),
            Name = name,
            Role = role,
            CreatedAt = now
        };
    }
}
