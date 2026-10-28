using MyApp.Domain.Models;
using MyApp.Domain.Repositories;

namespace MyApp.Domain.Services;

/// <summary>ビジネスロジック。UI も DbContext も知らない。</summary>
public sealed class ExampleService(IExampleRepository repo)
{
    public Task<IReadOnlyList<Example>> ListAsync(CancellationToken ct = default) => repo.AllAsync(ct);

    public async Task<Example> AddAsync(string name, CancellationToken ct = default)
    {
        var trimmed = name.Trim();
        if (trimmed.Length == 0)
        {
            throw new ValidationException("name is empty");
        }

        return await repo.InsertAsync(new Example { Name = trimmed }, ct);
    }

    public Task RemoveAsync(int id, CancellationToken ct = default) => repo.DeleteAsync(id, ct);
}

public sealed class ValidationException(string message) : Exception(message);
