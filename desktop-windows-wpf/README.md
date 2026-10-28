# desktop-windows-wpf — 典型的な Windows アプリケーション（WPF）

スタンドアロン（サーバーなし）の Shoebox 型アプリ。mac パターンと同じ構造を .NET で。

## 決定事項

| 項目 | 決定 | 見送ったもの | 理由 |
|---|---|---|---|
| UI | **WPF**（.NET 10、Fluent テーマ） | WinUI 3, MAUI | WinUI 3 はまだ品質が安定せず学習量も少ない。WPF は枯れていて Fluent テーマで見た目も現代的 |
| ランタイム | **.NET 10 (LTS)** | .NET 8 | 2025-11 の LTS |
| MVVM | **CommunityToolkit.Mvvm** | Prism, ReactiveUI | Microsoft 公式。`[ObservableProperty]` `[RelayCommand]` で定型コードが消える |
| DI / 起動 | **Microsoft.Extensions.Hosting**（Generic Host） | 自前 | 設定・ログ・DI が ASP.NET と同じ作法。エージェントが最もよく知る形 |
| ドメイン層 | **別プロジェクト `App.Domain`**（WPF 参照なし） | 1 プロジェクト | `dotnet test` が UI なしで回る。mac の Domain パッケージと同じ |
| 永続化 | **EF Core + SQLite** | Dapper + DbUp | .NET 圏の標準。マイグレーション内蔵。「その言語圏の標準」を思想統一より優先 |
| 設定 | `appsettings.json` + `IOptions<T>` | Registry | Host に乗せる |
| ログ | `Microsoft.Extensions.Logging` + **Serilog**（ファイル） | — | — |
| テスト | **xUnit + FluentAssertions** | NUnit, MSTest | 事実上標準。ViewModel は UI なしでテスト |
| Lint/Format | **`dotnet format` + Roslyn Analyzers**（`.editorconfig`、`TreatWarningsAsErrors`） | StyleCop | 標準 analyzer をレベル最大。StyleCop は古い |
| 配布 | **2 レーン**：**MSIX**（Store / サイドロード）+ **Velopack**（exe インストーラ + 自動更新） | WiX, Inno Setup | mac の App Store / DMG+Sparkle に対応 |
| CI | GitHub Actions (windows runner) + `dotnet` CLI | — | Visual Studio 不要で全部 CLI |

## 構成

```
template/
├── Makefile                         # make check / test / run / migrate  ← エージェントのエントリポイント
├── MyApp.sln
├── Directory.Build.props            # 全プロジェクト共通のビルド設定（Nullable, 警告=エラー, Analyzers）
├── Directory.Packages.props         # 中央パッケージ管理（バージョンは 1 箇所）
├── .editorconfig                    # コードスタイル + analyzer ルール
├── global.json                      # SDK バージョン固定
├── src/
│   ├── MyApp.Domain/                # WPF 参照なし
│   │   ├── Models/
│   │   ├── Data/                    # AppDbContext, Migrations/
│   │   ├── Repositories/            # interface + EF 実装
│   │   └── Services/                # ビジネスロジック
│   └── MyApp/                       # WPF
│       ├── App.xaml(.cs)            # Host 起動、DI
│       ├── Features/<Domain>/       # <Domain>View.xaml / <Domain>ViewModel.cs
│       ├── Core/                    # 共通 Converter、Behavior、ナビゲーション
│       ├── appsettings.json
│       └── Package.appxmanifest     # MSIX
├── tests/
│   ├── MyApp.Domain.Tests/
│   └── MyApp.Tests/                 # ViewModel テスト
└── build/                           # velopack.ps1 / msix.ps1（人間が叩く）
```

依存方向：**View → ViewModel → Domain（Service → Repository → EF Core）**。View のコードビハインドにロジックを書かない（lint では縛れないので CLAUDE.md で明示）。

## scaffold 手順

```powershell
# Windows 上で
cp -r dev-harness/desktop-windows-wpf/template MyApp; cd MyApp
cp dev-harness/desktop-windows-wpf/CLAUDE.md .; cp -r dev-harness/desktop-windows-wpf/.claude .
cp -r dev-harness/common/.claude/hooks .claude/hooks/common; cp dev-harness/common/CLAUDE.md .claude/CLAUDE.common.md
# プロジェクト名を MyApp から置換（ファイル名・名前空間・.sln）
dotnet tool restore
dotnet restore
make check
```

フックは bash スクリプト。Windows では Git Bash（Git for Windows 同梱）で動く。Claude Code は Windows でも bash を使うので追加設定は不要。

## 検証ループ

| タイミング | 何が走るか |
|---|---|
| 編集のたび（PostToolUse フック） | `.cs` → `dotnet format` + そのプロジェクトの `dotnet build`（analyzer が警告=エラーで落とす）。`.xaml` → `dotnet build` |
| `make check`（完了条件） | format 差分なし、`dotnet build -warnaserror`、`dotnet test` |
| モデル変更時 | `make migrate name=Xxx` で EF マイグレーション生成 → 差分を人間がレビュー。適用はアプリ起動時に `Migrate()` |
| UI 変更時 | `make run` で起動 → スクリーンショット |
| リリース | `dotnet publish -c Release`、MSIX パッケージング、署名、Velopack の `vpk pack`、Store 提出はフックでブロック |

## Windows 固有の制約

- ビルドは Windows 上でのみ。ハーネスはローカル Windows 前提。`MyApp.Domain` と `MyApp.Domain.Tests` は Linux でも `dotnet test` が通るので、クラウドのエージェントはそこだけ検証できる

## エージェントが間違えやすい点

- コードビハインド（`*.xaml.cs`）にロジックを書く → ViewModel に `[RelayCommand]`
- `INotifyPropertyChanged` を手書きする → `[ObservableProperty]`
- ViewModel から `DbContext` を直接使う → Domain の Service 経由
- `DbContext` を singleton にする → `AddDbContextFactory` で都度生成
- UI スレッド以外から `ObservableCollection` を触る → `Dispatcher` か `[RelayCommand]` の async（UI スレッドに戻る）
- `async void` を書く → `[RelayCommand]` の `Task` 戻り値
- `MessageBox.Show` を ViewModel から呼ぶ → `IDialogService` を注入
