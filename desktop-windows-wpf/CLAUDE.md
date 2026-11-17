# CLAUDE.md — desktop-windows-wpf（.NET 10 WPF + CommunityToolkit.Mvvm + EF Core/SQLite）

@.claude/CLAUDE.common.md

## 責任範囲と境界

- 担当はこのリポジトリの中だけ。スタンドアロンで、サーバーも他のコンポーネントとの契約も無い
- 外との境界は、利用者の手元に残るデータ（SQLite、設定ファイル）と配布物。旧版が書いたデータを新版が読めることが、このタイプでの契約にあたる（「互換性の制約」）

## 実行環境と前提

- Windows のローカルで動かす。コマンドは Git Bash から叩く
- `MyApp.Domain` とそのテストだけは Linux でも通る。Windows 以外では `make test-domain` までを回し、`make check` を通せなかったことを報告する

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

## 人間だけが叩く操作

- `dotnet publish`、`vpk`（Velopack）、`MakeAppx`、`SignTool`、Store 提出、手動の `database update`。フックが止める
- 必要になったら、叩くコマンド・理由・戻し方を書いて依頼する。別の書き方で回避しない

## 構成と依存方向

```
src/MyApp.Domain/              WPF を参照しない。Microsoft.Extensions.* と EF Core のみ
  Models/ Data/ Repositories/ Services/    Data/Migrations/ は EF が生成。手で直さない
src/MyApp/App.xaml.cs          Host の組み立て（DI、設定、ログ）、MainWindow 表示。ロジックを置かない
src/MyApp/Features/<Domain>/   <Domain>View.xaml（Binding だけ）/ <Domain>ViewModel.cs
src/MyApp/Core/                IDialogService、AppPaths、Converter、Behavior、ナビゲーション
tests/MyApp.Domain.Tests/      xUnit。SQLite in-memory で実 EF Core を回す
tests/MyApp.Tests/             ViewModel テスト。Service に fake Repository
```

- 依存方向は **View → ViewModel → Domain(Service → Repository → EF Core)**。逆流・飛び越し禁止
- `MyApp.Domain` は `PresentationFramework` を参照しない（csproj で保証）。`System.Windows` を import したら設計が間違っている
- ファイルごとの書き方は `.claude/rules/`（`csharp.md`、`efcore.md`）。該当するファイルを開くと読み込まれる

## 手本と追加手順

- 手本は Example の縦 1 本（`src/MyApp.Domain/` の `Models/Example.cs`、`Repositories/`、`Services/ExampleService.cs` と、`src/MyApp/Features/Example/`、`tests/`）
- 順番：Model と `AppDbContext` → `make migrate name=Xxx` → Repository → Service とテスト（`make test-domain`）→ ViewModel とテスト → View → `App.xaml.cs` で DI に登録 → `make check`

## 唯一の定義場所

| 概念 | 場所 |
|---|---|
| DB スキーマ | `MyApp.Domain` の `Models/` と `Data/AppDbContext.cs`（`OnModelCreating`）。マイグレーションは `make migrate` が生成する |
| 列挙値（種別・状態） | `MyApp.Domain/Models/` の enum。画面表記はその enum の拡張メソッド |
| 設定値 | `appsettings.json` → `IOptions<AppOptions>` |
| 書き込み先のパス | `Core/AppPaths.cs`（`LocalApplicationData` 配下のみ） |
| ダイアログ・ファイル選択 | `Core/IDialogService`。ViewModel に注入して呼ぶ |
| 画面の文言 | `Resources/Strings.resx`（雛形では定数クラス） |
| パッケージの版とビルド設定 | `Directory.Packages.props`、`Directory.Build.props`、`.editorconfig` |

## 使わないもの

- 手書きの `INotifyPropertyChanged` → `[ObservableProperty]` と `[RelayCommand]`
- `async void` → `[RelayCommand] private async Task Xxx()`
- ViewModel からの `MessageBox` / `OpenFileDialog` → `IDialogService`

## テスト

- Domain：`SqliteConnection("DataSource=:memory:")` を開いたまま `UseSqlite` で実 EF Core を回す。InMemory プロバイダは使わない（SQLite と挙動が違う）
- ViewModel：fake Repository を Service に渡して xUnit。UI スレッド不要
- UI 自動テストは持たない。UI は `make run` とスクリーンショットで確かめる

## 止まって確認する判断

- P/Invoke やレジストリへのアクセスを足す
- `Package.appxmanifest` の capability を足す
- 対応する Windows や .NET の版を変える（`global.json`）

## 互換性の制約

- 利用者の手元の DB は、起動時の `Database.Migrate()` で旧版から更新される。既存のマイグレーションは書き換えず、新しいものを足す
- `appsettings.json` のキーや保存したファイルの形式を変えるときは、旧い値でも起動できるようにする

## 確認手段と証拠

- `make run` → `make screenshot`（PowerShell でウィンドウキャプチャ）を取り、UI 変更の報告に添える
- Domain のロジックは `make test-domain`（数秒）

## プロジェクト固有（ここを埋める。当てはまらない欄は「該当なし」と書く）

- 目的と利用者、やらないこと：
- ドメイン用語：
- 主要エンティティと DB スキーマ：
- 破ってはならない業務ルール：
- 契約の段階（0〜2）、相手リポジトリ、契約の版：該当なし（スタンドアロン）
- 外部連携と、ローカルでの代わり（スタブ）：
- 環境（ローカル / 検証 / 本番）と、エージェントが届く範囲：
- 外に出ている版（互換の対象）と、対応 Windows バージョン：
- 触ってはいけない場所：
- 依頼の入口と、状態・決定の記録先：
- 配布レーン（MSIX / Velopack / 両方）：
