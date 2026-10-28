# CLAUDE.md — desktop-windows-wpf（.NET 10 WPF + CommunityToolkit.Mvvm + EF Core/SQLite）

@.claude/CLAUDE.common.md

## コマンド（必ずこれを使う）

```
make check          # 完了条件。format / build (-warnaserror) / test
make test-domain    # Domain のテストだけ（速い。Linux でも動く）
make test           # 全テスト
make build          # Debug ビルド
make run            # 起動
make migrate name=<PascalCase>   # EF Core マイグレーション生成（適用はしない）
make screenshot     # 起動中アプリのウィンドウをキャプチャ
```

`dotnet publish`、`vpk`（Velopack）、`MakeAppx`、`SignTool`、Store 提出はフックでブロックされている。

## 構成と依存方向

```
src/MyApp.Domain/              WPF を参照しない。Microsoft.Extensions.* と EF Core のみ
  Models/                      record / class。EF の Entity
  Data/AppDbContext.cs         DbContext。OnModelCreating でマッピング
  Data/Migrations/             EF が生成。手で直さない
  Repositories/                I<Domain>Repository + Ef<Domain>Repository
  Services/                    ビジネスロジック。Repository を interface で受ける
src/MyApp/
  App.xaml.cs                  Host の組み立て（DI、設定、ログ）、MainWindow 表示。ロジックを置かない
  Features/<Domain>/
    <Domain>View.xaml          Binding だけ。コードビハインドは InitializeComponent のみ
    <Domain>ViewModel.cs       ObservableObject + [ObservableProperty] + [RelayCommand]
  Core/                        IDialogService、Converter、Behavior、ナビゲーション
tests/MyApp.Domain.Tests/      xUnit。SQLite in-memory で実 EF Core を回す
tests/MyApp.Tests/             ViewModel テスト。Service に fake Repository
```

- 依存方向は **View → ViewModel → Domain(Service → Repository → EF Core)**。逆流・飛び越し禁止
- `MyApp.Domain` は `PresentationFramework` を参照しない（csproj で保証）。`System.Windows` を import したら設計が間違っている
- ViewModel は `partial class` + `ObservableObject`。プロパティは `[ObservableProperty]`、コマンドは `[RelayCommand]`。手書きの `INotifyPropertyChanged` は書かない
- `async void` 禁止。非同期コマンドは `[RelayCommand] private async Task Xxx()`
- View のコードビハインドは `InitializeComponent()` のみ。イベントハンドラは Behavior か Command で
- ダイアログ・ファイル選択は `IDialogService` を注入して呼ぶ。ViewModel から `MessageBox` / `OpenFileDialog` を直接使わない
- `DbContext` は `IDbContextFactory<AppDbContext>` から都度生成し `await using`。singleton にしない
- エラーは例外で上げ、ViewModel の `[ObservableProperty] string? error` に乗せ、View が表示。握りつぶさない
- 設定は `appsettings.json` → `IOptions<AppOptions>`。ハードコードしない
- ログは `ILogger<T>`。`Console.WriteLine` / `Debug.WriteLine` は書かない
- 文字列リソースは `Resources/Strings.resx`（雛形では定数クラス）

## EF Core のルール

- モデルを変えたら `make migrate name=Xxx` でマイグレーションを生成し、差分を報告に含める
- 既存マイグレーションファイルを書き換えない。`Data/Migrations/` はフックで編集ブロック
- 適用はアプリ起動時の `Database.Migrate()`。手動 `database update` は人間
- クエリは `AsNoTracking()` を既定。更新するときだけ追跡

## テスト

- Domain：`SqliteConnection("DataSource=:memory:")` を開いたまま `UseSqlite` で実 EF Core を回す。InMemory プロバイダは使わない（SQLite と挙動が違う）
- ViewModel：fake Repository を Service に渡して xUnit。UI スレッド不要
- UI 自動テストは持たない。UI は `make run` + スクリーンショットで確認

## 確認手段

- `make run` → `make screenshot`（PowerShell でウィンドウキャプチャ）
- Domain のロジックは `make test-domain`（数秒）

## プロジェクト固有（新規プロジェクトでここを埋める）

- アプリの目的とドメイン用語：
- 主要エンティティと DB スキーマ：
- 配布レーン（MSIX / Velopack / 両方）：
- 対応 Windows バージョン：
