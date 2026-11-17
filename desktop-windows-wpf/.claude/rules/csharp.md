---
paths:
  - "src/**/*.{cs,xaml}"
  - "tests/**/*.cs"
---

# C# / XAML の書き方

- ViewModel は `partial class` + `ObservableObject`。プロパティは `[ObservableProperty]`、コマンドは `[RelayCommand]`。手書きの `INotifyPropertyChanged` は書かない
- `async void` 禁止。非同期コマンドは `[RelayCommand] private async Task Xxx()`
- View のコードビハインドは `InitializeComponent()` のみ。イベントハンドラは Behavior か Command で
- ダイアログ・ファイル選択は `IDialogService` を注入して呼ぶ。ViewModel から `MessageBox` / `OpenFileDialog` を直接使わない
- `DbContext` は `IDbContextFactory<AppDbContext>` から都度生成し `await using`。singleton にしない
- エラーは例外で上げ、ViewModel の `[ObservableProperty] string? error` に乗せ、View が表示。握りつぶさない
- 設定は `appsettings.json` → `IOptions<AppOptions>`。ハードコードしない
- ログは `ILogger<T>`。`Console.WriteLine` / `Debug.WriteLine` は書かない
- 文字列リソースは `Resources/Strings.resx`（雛形では定数クラス）
