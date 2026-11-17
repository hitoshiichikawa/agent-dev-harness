# agent-dev-harness

AI エージェント（主に Claude Code）で開発を進めるための **ハーネス** のテンプレート集。
4 つのアプリケーションパターンそれぞれに、文脈（CLAUDE.md）・権限とフック（.claude/）・雛形（template/）をセットで持つ。

ハーネス = モデルの周りに置く仕組み全部。「何を知らせるか・何を使わせるか・何を禁じるか・どうやって正しさを確認するか」。
信頼性はほぼ **検証ループとフック** で決まる。CLAUDE.md は「毎回間違えるから毎回言うこと」だけに絞る。

考え方の全体と、プロジェクトを始める手順は [`docs/guide.md`](docs/guide.md)。まずこれを読む。

このリポジトリがなぜこの形で、どこへ向かうか（継承の構造、IF による分割、リポジトリの分け方、人が確認する場所、知見の入れ方）は [`docs/design.md`](docs/design.md)。

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

# git を始めてから完了条件を通す。生成コードの鮮度の検査が git を使うので、git init が先。
# 生成コードは git add してから check する（追跡していないと、検査が差分を見られず素通りする）
git init
task gen && git add -A && task check    # web。mobile / mac は make gen && git add -A && make check、windows は git add -A && make check

# CLAUDE.md 末尾の「プロジェクト固有」節を埋める（ここだけが毎プロジェクト書く場所）
```

### 2. 日々の開発

プロジェクトのルートで `claude` を起動すると、以下が自動で効く。

| 仕組み | 何が起きるか |
|---|---|
| `CLAUDE.md` | 毎セッション冒頭で読まれる。責任範囲・コマンド・構成・依存方向・定義の置き場所を知った状態で始まる。欄は全パターン共通（[`docs/design.md`](docs/design.md) 2 章） |
| `.claude/rules/` | ファイルごとの書き方。該当するファイルを開いたときだけ読まれる |
| `permissions.allow` | `task check` や `go test` は確認なしで実行される。毎回承認しなくていい |
| `permissions.deny` + `guard-bash.sh` | `cdk deploy`、`goose up`、`git push --force` などを叩こうとすると止まり、「人間に依頼して」とフィードバックが返る |
| `guard-edit.sh` | 生成コード・`.env`・ロックファイル・`.xcodeproj` を書き換えようとすると止まる |
| `post-edit.sh` | ファイル編集のたびにフォーマッタと軽い静的検査が走り、落ちればその場でエージェントに返る |
| `check-gate.sh` | ファイルを編集したのに `check` を通していないまま終わろうとすると止まり、「`check` を回して直して」と返る |

典型的な流れ：

1. 「`examples` に `description` を足して一覧と作成 API に反映して」と頼む
2. エージェントは `openapi.yaml` → `task gen` → handler → SQL → `task migrate:new` → 画面、の順で進める（CLAUDE.md にその順序が書いてある）
3. 編集のたびにフックが整形・検査。マイグレーションを書いた時点で「適用は人間に依頼」と自分で言う
4. 最後に `task check` を回して緑を確認してから「完了」と報告する
5. 人間は `task migrate:up` を叩き、PR をレビューする

「テスト通した？」「生成した？」と毎回聞かなくていい。聞かなくても通さないと完了にならない仕組みになっている。

### 3. ハーネス自体の育て方

- 知見と失敗は、まず [`docs/learnings.md`](docs/learnings.md) に 1 件ずつ記録し、行き先を決めてから反映する。プロジェクト側では `docs/harness-feedback.md` に書き留める
- エージェントが同じ間違いを 2 回したら、それはハーネスに足す材料
  - 指示で直るもの → パターンの `CLAUDE.md` の該当する欄か、`.claude/rules/` に 1 行足す。基底と合わせて 200 行未満を保ち、足すなら削る。このリポジトリにも反映して次のプロジェクトに効かせる
  - 指示しても繰り返すもの → フックか lint ルールにして機械的に止める
- フックを変えたら `bash tests/run.sh` を回す。ガードの穴や誤検知を見つけたら、直す前に `tests/cases/*.txt` に 1 行足す（期待・パターン・コマンドを並べるだけ）
- 一度も引っかからないルールは削る。CLAUDE.md は短いほど効く
- 禁止だけ書くと、無いときにまた直書きされる。「無ければどこに新設して使うか」まで書く（`common/CLAUDE.md`「唯一の定義場所」）
- 契約文書や相手側リポジトリの更新漏れは原則では防げない。PR 前のチェックリスト（完了の定義）に足す
- 組織で固定できる A 層は `~/.claude/CLAUDE.md` や `~/.claude/settings.json` に昇格させると、プロジェクトごとのコピーが不要になる。ただしチーム開発ではクローンした他の人に効かないので、プロジェクト側に置く

## 既存システムの隣に作るとき

古い本体の隣に新しい機能や別クライアントを足すとき、エージェントは既存コードの流儀に合わせようとして **既存の壊れ方まで真似る**（業務ロジックをコピーして分岐させる、判定をクライアントで再実装する、時刻変換を画面ごとに書く）。
新しいリポジトリは既存リポジトリの兄弟ディレクトリに置き、既存側は参照専用の clone を読むだけにして、書き換えられないように設定する。
着手前に既存コードの保守性を測り、新しいコードには「真似ない流儀」と「唯一の定義場所」の表を CLAUDE.md に書く。手順と規約は [`common/brownfield.md`](common/brownfield.md)。

## 気をつけること

### 実行環境

- **mac / Windows パターンはその OS のローカルで `claude` を起動する前提**。クラウド実行ではビルドできない。Domain 層（`Packages/Domain`、`MyApp.Domain`）だけは Linux でもテストが通るように作ってあるので、そこだけはクラウドで検証できる
- フックは bash スクリプト。Windows では Git for Windows 同梱の Git Bash で動く。Claude Code は Windows でも bash を使うので追加設定は不要
- フックスクリプトは `jq` があれば使い、なければ `python3`、どちらもなければ `sed` にフォールバックする。`jq` を入れておくのが一番確実

### テンプレートの状態

- **template/ のコードは実ビルドで検証していない。** 生成コード（oapi-codegen、sqlc、orval、freezed、riverpod_generator 等）が存在する前提で書いてあり、初回 scaffold で `gen` を回したときに生成される型名・引数名との細かいズレが出る可能性がある。最初のプロジェクトで潰し、直したものをこのリポジトリに反映する
- **フックは試験している。** `bash tests/run.sh` が各パターンを一時ディレクトリに組み立て、macOS 標準の bash 3.2 と新しい bash の両方でガードを回す。Windows の Git Bash 上と、フォーマッタ・lint を呼ぶ分岐（道具が要る）は未検証
- `package.json` / `pubspec.yaml` / `Directory.Packages.props` のバージョンは「意図のメモ」。scaffold 時にパッケージマネージャに解決させ、ロックファイルを正とする
- Go の module path（`github.com/ORG/APP/api`）、Swift / .NET の `MyApp`、Flutter の `my_app` はプレースホルダ。scaffold 時に一括置換する

### フックと権限

- 防御は **二重**：`permissions.deny`（コマンド名の前方一致）と `guard-bash.sh`（正規表現）。片方だけだと引数順の違い（`git push origin main --force`）で抜ける。パターン固有の追加は `extra-deny.txt` に正規表現で書く
- `rm` はリポジトリルート（`.`）・親（`..`）・ホーム（`~`、`$HOME`）・`/` と、その直下すべて（`./*` など）、裸の `*` をブロックしている。`rm -rf ./build` は通る。もっと厳しくしたいなら `guard-bash.sh` の `PATTERNS` を足す
- フックは **コマンド文字列を見ているだけ** で、スクリプトファイルの中身や Makefile のターゲットの中までは追えない。`make deploy` のようなターゲットを作るなら、それ自体を `extra-deny.txt` に足す
- フックは善意のエージェントの事故を防ぐ **ガードレールで、越えられない境界ではない**（`bash -c '...'` のような書き方は見ない）。境界が要るもの（本番への到達、強制 push）は、認証情報を持たせない・ブランチ保護をかけるなど権限側で作る
- 逆に、操作に触れているだけの文字列（`cdk deploy` と書いたコミットメッセージ、検索パターン）でも止まる。止まったら文言を変えるかファイルに書く
- ガードは **動けないときは止める**。スクリプトが無い・途中で落ちた・入力が読めない場合は素通しにせずブロックする。セットアップを誤ると全コマンドが止まるので、すぐ気づける
- フックを書くときの決まり（呼び出しパス、終了コード、エージェントへの伝え方）は [`common/README.md`](common/README.md)「フックを書くときの決まり」

### check の門番

「完了は機械判定」を指示任せにしないための仕組み。`check-gate.sh` が Stop フックとして働く。

- エージェントがファイルを編集すると印が付く。終わろうとしたとき、今の中身で `check` が通っていなければ終了を止める。`check` 全体が通ると、その中身が記録されて通れるようになる
- `check` そのものはフックの中では走らせない。エージェントが自分で走らせ、出力を見て直す。`check` の最後の 1 行（`check-gate.sh record`）が「通った」を記録する。`task check:api` のような一部だけでは記録されない
- 見ているのは作業ツリーの中身だけ。`check` が通った後に `git add` や `git commit` をしても、通ったままになる
- **同じ中身で 2 回目に終わろうとすると通す**。質問のために止まる場合や、どうしても通らず報告して止まる場合の逃げ道。このとき利用者には「check が通っていないまま終わった」という警告が出る。警告が出た回の「完了」は完了ではない
- 対象は Edit / Write での編集。Bash だけで書き換えた場合（`sed -i` など）は印が付かない
- git リポジトリでなければ働かない。立ち上げ時は `git init` の後から有効になる。状態は `.git/harness/` に置くので、コミットにも差分にも現れない
- ガードと違い、門番が壊れているときは止めない（終われなくなるより、通すほうが害が小さい）
- `permissions.allow` に `powershell:*` / `pwsh:*`（Windows）を入れている。PowerShell 経由なら何でも実行できるので、気になるなら外して個別に許可する
- `post-edit.sh` で `go vet` や `dotnet build` をファイル単位で回している。大きなプロジェクトで遅くなったら、フックは format だけにして検査は `check` に寄せる

### 生成コードとロックファイル

- **生成コードはコミットする**。`check:gen` / `gen-check` が `git diff --exit-code` で「生成し忘れ」を検出する仕組みなので、`.gitignore` に入れない
- ロックファイル（`pnpm-lock.yaml`、`go.sum`、`pubspec.lock`、`Package.resolved`）はエージェントの直接編集をブロックしている。依存を足すときはパッケージマネージャのコマンド経由

### 秘密情報

- `.env`、鍵、証明書、provisioning profile はエージェントが読めないよう `permissions.deny` に入れている。ローカル開発用の値は `docker-compose.yml` や `.env.example` に直書きしてよいが、本番値は SSM / Secrets Manager / Keychain に置く
- `.env.example` だけは見本なので読み書きできる（`permissions.deny` の `Read(!.env.example)` と `guard-edit.sh` の両方で通している）。`.env.local` など他の `.env.*` は止まる
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
