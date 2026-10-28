using Microsoft.EntityFrameworkCore;
using MyApp.Domain.Data;
using MyApp.Domain.Models;

namespace MyApp.Domain.Repositories;

/// <summary>DbContext は factory から都度生成する。singleton にしない。</summary>
public sealed class EfExampleRepository(IDbContextFactory<AppDbContext> factory) : IExampleRepository
{
    public async Task<IReadOnlyList<Example>> AllAsync(CancellationToken ct = default)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        return await db.Examples.AsNoTracking().OrderByDescending(x => x.CreatedAt).ToListAsync(ct);
    }

    public async Task<Example> InsertAsync(Example example, CancellationToken ct = default)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        db.Examples.Add(example);
        await db.SaveChangesAsync(ct);
        return example;
    }

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        await db.Examples.Where(x => x.Id == id).ExecuteDeleteAsync(ct);
    }
}
