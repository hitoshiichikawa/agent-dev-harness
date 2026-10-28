using Microsoft.EntityFrameworkCore;
using MyApp.Domain.Models;

namespace MyApp.Domain.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Example> Examples => Set<Example>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Example>(e =>
        {
            e.ToTable("example");
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).IsRequired().HasMaxLength(100);
            e.HasIndex(x => x.CreatedAt);
        });
    }
}
