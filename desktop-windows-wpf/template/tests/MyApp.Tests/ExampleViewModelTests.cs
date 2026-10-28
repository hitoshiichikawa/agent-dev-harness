using FluentAssertions;
using MyApp.Core;
using MyApp.Domain.Models;
using MyApp.Domain.Repositories;
using MyApp.Domain.Services;
using MyApp.Features.Example;

namespace MyApp.Tests;

/// <summary>ViewModel は fake Repository + fake Dialog で UI なしにテストする。</summary>
public sealed class ExampleViewModelTests
{
    private sealed class FakeRepo : IExampleRepository
    {
        private readonly List<Example> _items = [];
        public Task<IReadOnlyList<Example>> AllAsync(CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<Example>>(_items.ToList());
        public Task<Example> InsertAsync(Example e, CancellationToken ct = default)
        {
            e.Id = _items.Count + 1;
            _items.Add(e);
            return Task.FromResult(e);
        }
        public Task DeleteAsync(int id, CancellationToken ct = default)
        {
            _items.RemoveAll(x => x.Id == id);
            return Task.CompletedTask;
        }
    }

    private sealed class FakeDialogs : IDialogService
    {
        public List<string> Errors { get; } = [];
        public void ShowError(string message) => Errors.Add(message);
        public bool Confirm(string message) => true;
    }

    [Fact]
    public async Task Add_InsertsAtTopAndClearsDraft()
    {
        var dialogs = new FakeDialogs();
        var vm = new ExampleViewModel(new ExampleService(new FakeRepo()), dialogs) { DraftName = " a " };

        await vm.AddCommand.ExecuteAsync(null);

        vm.Items.Should().ContainSingle(x => x.Name == "a");
        vm.DraftName.Should().BeEmpty();
        dialogs.Errors.Should().BeEmpty();
    }

    [Fact]
    public void Add_IsDisabledWhenDraftBlank()
    {
        var vm = new ExampleViewModel(new ExampleService(new FakeRepo()), new FakeDialogs()) { DraftName = "  " };
        vm.AddCommand.CanExecute(null).Should().BeFalse();
    }
}
