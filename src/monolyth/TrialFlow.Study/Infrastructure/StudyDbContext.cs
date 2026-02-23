using Microsoft.EntityFrameworkCore;
using TrialFlow.Study.Domain;

namespace TrialFlow.Study.Infrastructure;

public sealed class StudyDbContext : DbContext
{
    public StudyDbContext(DbContextOptions<StudyDbContext> options)
        : base(options)
    {
    }

    public DbSet<Domain.Study> Studies => Set<Domain.Study>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("study");
        modelBuilder.Entity<Domain.Study>(e =>
        {
            e.ToTable("studies");
            e.HasKey(x => x.Id);
            e.Property(x => x.Title).HasMaxLength(500).IsRequired();
            e.Property(x => x.Description).HasMaxLength(4000);
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.SponsorId);
            e.Property(x => x.CreatedAt);
            e.Property(x => x.UpdatedAt);
        });
    }
}
