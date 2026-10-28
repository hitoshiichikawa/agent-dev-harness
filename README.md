# agent-dev-harness

AI エージェント（主に Claude Code）で開発を進めるための **ハーネス** のテンプレート集。
4 つのアプリケーションパターンそれぞれに、文脈（CLAUDE.md）・権限とフック（.claude/）・雛形（template/）をセットで持つ。

ハーネス = モデルの周りに置く仕組み全部。「何を知らせるか・何を使わせるか・何を禁じるか・どうやって正しさを確認するか」。
信頼性はほぼ **検証ループとフック** で決まる。CLAUDE.md は「毎回間違えるから毎回言うこと」だけに絞る。

## パターン一覧

| ディレクトリ | 何を作るか | 主なスタック | 検証ループの要 |
|---|---|---|---|
| [`web/`](web/) | 業務系 web アプリ（ログイン後が主体） | Go API + Postgres / Vite+React SPA / AWS ECS+S3+CloudFront (CDK) | `task check`（go vet / golangci-lint / go test / tsc / biome / vitest）、OpenAPI 再生成 |
| [`mobile-flutter/`](mobile-flutter/) | iOS / Android アプリ（web と同じ Go API を使う） | Flutter + Riverpod + go_router / OpenAPI 生成クライアント | `flutter analyze` / `flutter test`（golden 含む） |
| [`desktop-mac/`](desktop-mac/) | スタンドアロン mac アプリ（Shoebox 型） | SwiftUI + MVVM / GRDB / XcodeGen / App Store と DMG の 2 レーン | `swift test`（Domain）/ `xcodebuild test` |
| [`desktop-windows-wpf/`](desktop-windows-wpf/) | スタンドアロン Windows アプリ（Shoebox 型） | .NET 10 WPF + CommunityToolkit.Mvvm / EF Core + SQLite / MSIX と Velopack の 2 レーン | `dotnet build`（警告=エラー）/ `dotnet test` |

`common/` は全パターン共通の層（作業手順・禁止事項・PR 運用・共通フック）。各パターンの CLAUDE.md はこれを前提に差分だけ書く。

## 4 層モデル

| 層 | 変わる頻度 | 置き場所 |
|---|---|---|
| A. 普遍層（手順・禁止事項・完了の定義） | ほぼ変わらない | `common/` → `~/.claude/CLAUDE.md` や組織プラグインに昇格させてよい |
| B. スタック層（言語・FW の規約、検証コマンド） | スタックを変えるとき | 各パターンの `CLAUDE.md` と `template/` の設定ファイル |
| C. アプリ種別層（確認手段、環境依存） | 種別ごと | 同上 |
| D. プロジェクト固有層（このリポジトリの構成、ドメイン用語） | 毎プロジェクト | 新規プロジェクトの `CLAUDE.md` に **ここだけ** 書く |

## 使い方

### 1. 新規プロジェクトの立ち上げ（最初の 1 回）

```bash
# このリポジトリはテンプレート置き場。手元にクローンしておく
git clone https://github.com/hitoshiichikawa/agent-dev-harness.git

# パターンをコピーして新プロジェクトにする（例: web）
cp -r agent-dev-harness/web/template my-app && cd my-app
cp    ../agent-dev-harness/web/CLAUDE.md CLAUDE.md
cp -r ../agent-dev-harness/web/.claude   .claude

# 共通層を合流（CLAUDE.md は @.claude/CLAUDE.common.md で参照している）
cp    ../agent-dev-harness/common/CLAUDE.md        .claude/CLAUDE.common.md
cp -r ../agent-dev-harness/common/.claude/hooks    .claude/hooks/common

# 各パターンの README「scaffold 手順」に従ってアプリ本体を生成
#   pnpm create vite / flutter create / xcodegen / dotnet restore など。
#   template/ は設定・構造・最小コードだけを持ち、アプリ本体は各ツールの scaffold で作る

# 完了条件が通ることを確認してから git init
task check    # web。mobile / mac / windows は make check

# CLAUDE.md 末尾の「プロジェクト固有」節を埋める（ここだけが毎プロジェクト書く場所）
```

### 2. 日々の開発

プロジェクトのルートで `claude` を起動すると、以下が自動で効く。

| 仕組み | 何が起きるか |
|---|---|
| `CLAUDE.md` | 毎セッション冒頭で読まれる。コマンド・構成・依存方向・間違えやすい点を知った状態で始まる |
| `permissions.allow` | `task check` や `go test` は確認なしで実行される。毎回承認しなくていい |
| `permissions.deny` + `guard-bash.sh` | `cdk deploy`、`goose up`、`git push --force` などを叩こうとすると止まり、「人間に依頼して」とフィードバックが返る |
| `guard-edit.sh` | 生成コード・`.env`・ロックファイル・`.xcodeproj` を書き換えようとすると止まる |
| `post-edit.sh` | ファイル編集のたびにフォーマッタと軽い静的検査が走り、落ちればその場でエージェントに返る |

典型的な流れ：

1. 「`examples` に `description` を足して一覧と作成 API に反映して」と頼む
2. エージェントは `openapi.yaml` → `task gen` → handler → SQL → `task migrate:new` → 画面、の順で進める（CLAUDE.md にその順序が書いてある）
3. 編集のたびにフックが整形・検査。マイグレーションを書いた時点で「適用は人間に依頼」と自分で言う
4. 最後に `task check` を回して緑を確認してから「完了」と報告する
5. 人間は `task migrate:up` を叩き、PR をレビューする

「テスト通した？」「生成した？」と毎回聞かなくていい。聞かなくても通さないと完了にならない仕組みになっている。

### 3. ハーネス自体の育て方

- エージェントが同じ間違いを 2 回したら、それはハーネスに足す材料
  - 指示で直るもの → パターンの `CLAUDE.md` の「間違えやすい点」に 1 行足す。このリポジトリにも反映して次のプロジェクトに効かせる
  - 指示しても繰り返すもの → フックか lint ルールにして機械的に止める
- 一度も引っかからないルールは削る。CLAUDE.md は短いほど効く
- 組織で固定できる A 層は `~/.claude/CLAUDE.md` や `~/.claude/settings.json` に昇格させると、プロジェクトごとのコピーが不要になる。ただしチーム開発ではクローンした他の人に効かないので、プロジェクト側に置く

## 気をつけること

### 実行環境

- **mac / Windows パターンはその OS のローカルで `claude` を起動する前提**。クラウド実行ではビルドできない。Domain 層（`Packages/Domain`、`MyApp.Domain`）だけは Linux でもテストが通るように作ってあるので、そこだけはクラウドで検証できる
- フックは bash スクリプト。Windows では Git for Windows 同梱の Git Bash で動く。Claude Code は Windows でも bash を使うので追加設定は不要
- フックスクリプトは `jq` があれば使い、なければ `python3`、どちらもなければ `sed` にフォールバックする。`jq` を入れておくのが一番確実

### テンプレートの状態

- **template/ のコードは実ビルドで検証していない。** 生成コード（oapi-codegen、sqlc、orval、freezed、riverpod_generator 等）が存在する前提で書いてあり、初回 scaffold で `gen` を回したときに生成される型名・引数名との細かいズレが出る可能性がある。最初のプロジェクトで潰し、直したものをこのリポジトリに反映する
- `package.json` / `pubspec.yaml` / `Directory.Packages.props` のバージョンは「意図のメモ」。scaffold 時にパッケージマネージャに解決させ、ロックファイルを正とする
- Go の module path（`github.com/ORG/APP/api`）、Swift / .NET の `MyApp`、Flutter の `my_app` はプレースホルダ。scaffold 時に一括置換する

### フックと権限

- 防御は **二重**：`permissions.deny`（コマンド名の前方一致）と `guard-bash.sh`（正規表現）。片方だけだと引数順の違い（`git push origin main --force`）で抜ける。パターン固有の追加は `extra-deny.txt` に正規表現で書く
- `rm -rf` はリポジトリルート・ホーム・`/`・`..` 相当だけブロックしている。`rm -rf ./build` は通る。もっと厳しくしたいなら `guard-bash.sh` の `COMMON_DENY` を足す
- フックは **コマンド文字列を見ているだけ** で、スクリプトファイルの中身や Makefile のターゲットの中までは追えない。`make deploy` のようなターゲットを作るなら、それ自体を `extra-deny.txt` に足す
- `permissions.allow` に `powershell:*` / `pwsh:*`（Windows）を入れている。PowerShell 経由なら何でも実行できるので、気になるなら外して個別に許可する
- `post-edit.sh` で `go vet` や `dotnet build` をファイル単位で回している。大きなプロジェクトで遅くなったら、フックは format だけにして検査は `check` に寄せる

### 生成コードとロックファイル

- **生成コードはコミットする**。`check:gen` / `gen-check` が `git diff --exit-code` で「生成し忘れ」を検出する仕組みなので、`.gitignore` に入れない
- ロックファイル（`pnpm-lock.yaml`、`go.sum`、`pubspec.lock`、`Package.resolved`）はエージェントの直接編集をブロックしている。依存を足すときはパッケージマネージャのコマンド経由

### 秘密情報

- `.env`、鍵、証明書、provisioning profile はエージェントが読めないよう `permissions.deny` に入れている。ローカル開発用の値は `docker-compose.yml` や `.env.example` に直書きしてよいが、本番値は SSM / Secrets Manager / Keychain に置く
- `guard-bash.sh` は AWS アクセスキーや秘密鍵らしき文字列を含むコマンドをブロックするが、網羅的ではない。秘密情報をコマンドラインに乗せない運用が前提

### 破壊的操作は人間が叩く

エージェントがブロックされるもの（各パターンの `settings.json` と `extra-deny.txt`）：

| パターン | ブロック対象 |
|---|---|
| 共通 | `git push --force`、`git reset --hard`、`git clean -f`、`sudo`、`curl \| sh` |
| web | `cdk deploy` / `destroy`、`goose up` / `down`、`task migrate:up`、`docker push`、`docker compose down -v`、`aws` CLI |
| mobile-flutter | `flutter build`、`fastlane`、`codesign`、`notarytool`、`keytool`、`gradlew bundleRelease` |
| desktop-mac | `xcodebuild archive`、`-exportArchive`、`codesign`、`notarytool`、`create-dmg`、`hdiutil`、`fastlane`、`security import` |
| desktop-windows-wpf | `dotnet publish`、`dotnet ef database`、`vpk`、`MakeAppx`、`SignTool`、`Add-AppxPackage` |

ブロックされたとき、エージェントには「人間に依頼して」というメッセージが返る。その操作が必要なら人間が手で叩く。

## 設計上の約束（全パターン共通）

- **完了の定義は機械判定**：テスト・型・lint が緑であること。人間の目視は最後の補助
- **破壊的操作はフックで止める**：指示文だけに頼らない
- **生成コードは触らない**：OpenAPI・sqlc・freezed・ソースジェネレータの出力は `generated/` に隔離し、元を直して再生成する
- **縦割り構成**：`features/<domain>/` にその機能の UI・ロジック・データアクセスをまとめる。横断は `core/` または `lib/`
- **ドメインロジックは UI フレームワークから独立**：UI なしで単体テストが回る層を必ず作る（Go の `internal/`、Flutter の Notifier、Swift の Domain Package、.NET の App.Domain）
- **SQL は読める形で**：sqlc / GRDB / EF Core の順でその言語圏の標準を取り、ORM の魔法に頼らない
- **デスクトップはサンドボックス前提で 1 コードベース 2 レーン**：App Store / DMG、MSIX / Velopack の差は署名・配布設定だけ

## 各パターンのディレクトリ構成

```
<pattern>/
├── README.md            # そのパターンの決定事項、見送った理由、scaffold 手順、間違えやすい点
├── CLAUDE.md            # エージェントに毎回読ませる文脈（B+C 層）。末尾に D 層の空欄
├── .claude/
│   ├── settings.json    # 権限の許可/拒否、フック定義
│   └── hooks/           # そのパターン固有のフックスクリプト、extra-deny.txt
└── template/            # コピーして使う雛形（設定ファイル・ディレクトリ構造・各層 1 ファイルずつの最小コード）
```

## 決定の経緯

スタック選定は「contemporary に stable」= 枯れていて採用例が多く、エージェントがすでに大量に学習している構成、を基準にした。尖った選択はエージェントの精度を落とす。各パターンの README に、採用したものと見送ったものの理由を残してある。

## ライセンス

MIT
