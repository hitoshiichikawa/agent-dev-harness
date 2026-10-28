using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using MyApp.Domain.Data;
using MyApp.Domain.Repositories;
using MyApp.Domain.Services;

namespace MyApp.Domain.Tests;

/// <summary>SQLite in-memory で実 EF Core を回す。InMemory プロバイダは使わない。</summary>
public sealed class ExampleServiceTests : IDisposable
{
    private readonly SqliteConnection _conn = new("DataSource=:memory:");
    private readonly ExampleService _svc;

    public ExampleServiceTests()
    {
        _conn.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_conn).Options;
        using (var db = new AppDbContext(options))
        {
            db.Database.EnsureCreated();
        }

        _svc = new ExampleService(new EfExampleRepository(new TestFactory(options)));
    }

    [Fact]
    public async Task Add_TrimsAndPersists()
    {
        var added = await _svc.AddAsync("  hello  ");
        added.Name.Should().Be("hello");
        added.Id.Should().BeGreaterThan(0);
        (await _svc.ListAsync()).Should().ContainSingle();
    }

    [Fact]
    public async Task Add_RejectsBlank()
    {
        var act = () => _svc.AddAsync("   ");
        await act.Should().ThrowAsync<ValidationException>();
    }

    [Fact]
    public async Task Remove_Deletes()
    {
        var added = await _svc.AddAsync("x");
        await _svc.RemoveAsync(added.Id);
        (await _svc.ListAsync()).Should().BeEmpty();
    }

    public void Dispose() => _conn.Dispose();

    private sealed class TestFactory(DbContextOptions<AppDbContext> options) : IDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext() => new(options);
    }
}
