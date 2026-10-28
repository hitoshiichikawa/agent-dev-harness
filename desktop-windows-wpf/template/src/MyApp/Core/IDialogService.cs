using System.Windows;

namespace MyApp.Core;

/// <summary>ViewModel から MessageBox / ファイルダイアログを直接呼ばないための抽象。</summary>
public interface IDialogService
{
    void ShowError(string message);
    bool Confirm(string message);
}

public sealed class DialogService : IDialogService
{
    public void ShowError(string message) =>
        MessageBox.Show(message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);

    public bool Confirm(string message) =>
        MessageBox.Show(message, "Confirm", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
}
