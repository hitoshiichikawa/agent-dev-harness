using MyApp.Domain.Models;

namespace MyApp.Domain.Repositories;

/// <summary>Service が必要とする操作だけを宣言する。</summary>
public interface IExampleRepository
{
    Task<IReadOnlyList<Example>> AllAsync(CancellationToken ct = default);
    Task<Example> InsertAsync(Example example, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}
