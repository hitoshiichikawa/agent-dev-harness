using System.Windows.Controls;

namespace MyApp.Features.Example;

public partial class ExampleView : UserControl
{
    public ExampleView()
    {
        InitializeComponent();
        // 初回ロードは Loaded イベントではなく ViewModel のコマンドを Behavior で呼ぶのが理想だが、
        // 雛形では最小構成として DataContext 設定後に一度だけ呼ぶ。
        DataContextChanged += (_, e) => (e.NewValue as ExampleViewModel)?.LoadCommand.Execute(null);
    }
}
