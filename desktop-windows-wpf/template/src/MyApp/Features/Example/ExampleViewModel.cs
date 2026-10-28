using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyApp.Core;
using MyApp.Domain.Models;
using MyApp.Domain.Services;

namespace MyApp.Features.Example;

/// <summary>[ObservableProperty] と [RelayCommand] のみ。Domain の Service を呼ぶだけ。</summary>
public sealed partial class ExampleViewModel(ExampleService service, IDialogService dialogs) : ObservableObject
{
    public ObservableCollection<Domain.Models.Example> Items { get; } = [];

    [ObservableProperty]
    private Domain.Models.Example? _selected;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(AddCommand))]
    private string _draftName = string.Empty;

    [ObservableProperty]
    private bool _isLoading;

    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;
        try
        {
            Items.Clear();
            foreach (var item in await service.ListAsync())
            {
                Items.Add(item);
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            dialogs.ShowError(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }

    private bool CanAdd() => !string.IsNullOrWhiteSpace(DraftName);

    [RelayCommand(CanExecute = nameof(CanAdd))]
    private async Task AddAsync()
    {
        try
        {
            var added = await service.AddAsync(DraftName);
            Items.Insert(0, added);
            DraftName = string.Empty;
        }
        catch (ValidationException ex)
        {
            dialogs.ShowError(ex.Message);
        }
    }

    [RelayCommand]
    private async Task RemoveAsync(Domain.Models.Example? item)
    {
        if (item is null || !dialogs.Confirm($"Delete \"{item.Name}\"?"))
        {
            return;
        }

        await service.RemoveAsync(item.Id);
        Items.Remove(item);
    }
}
