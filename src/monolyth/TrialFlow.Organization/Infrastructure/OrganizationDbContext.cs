using Microsoft.EntityFrameworkCore;
using TrialFlow.Organization.Domain;

namespace TrialFlow.Organization.Infrastructure;

public sealed class OrganizationDbContext : DbContext
{
    public OrganizationDbContext(DbContextOptions<OrganizationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Domain.Organization> Organizations => Set<Domain.Organization>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("organization");
        modelBuilder.Entity<Domain.Organization>(e =>
        {
            e.ToTable("organizations");
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(300).IsRequired();
            e.Property(x => x.Role).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.CreatedAt);
        });
    }
}