# CLAUDE.md — desktop-mac（SwiftUI + MVVM + GRDB、XcodeGen）

@.claude/CLAUDE.common.md

## 責任範囲と境界

- 担当はこのリポジトリの中だけ。スタンドアロンで、サーバーも他のコンポーネントとの契約も無い
- 外との境界は、利用者の手元に残るデータ（SQLite、`UserDefaults`）と配布物。旧版が書いたデータを新版が読めることが、このタイプでの契約にあたる（「互換性の制約」）

## 実行環境と前提

- macOS のローカルで Xcode が要る。道具は `xcodegen`、`swiftformat`、`swiftlint`
- `Packages/Domain` だけは Linux でも `swift test` が通る。macOS 以外では `make test-domain` までを回し、`make check` を通せなかったことを報告する

## コマンド（必ずこれを使う）

```
make check          # 完了条件。format / lint / swift test (Domain) / xcodebuild test (App)
make test-domain    # swift test だけ（速い。ロジック変更時はまずこれ）
make test           # xcodebuild test（App ターゲット含む）
make gen            # xcodegen generate（project.yml を変えたら）
make build          # Debug ビルド
make run            # ビルドして起動
make screenshot     # 起動中のアプリのウィンドウをキャプチャ（アクセシビリティの権限が要る）
```

## 人間だけが叩く操作

- `xcodebuild archive`、`-exportArchive`、`codesign`、`notarytool`、`create-dmg`、fastlane。フックが止める
- 必要になったら、叩くコマンド・理由・戻し方を書いて依頼する。別の書き方で回避しない

## 構成と依存方向

```
project.yml                          XcodeGen。ターゲット・設定・entitlements。.xcodeproj は生成物
Packages/Domain/Sources/Domain/      Models/ Database/ Repositories/ Services/
Packages/Domain/Tests/DomainTests/   in-memory DB で回す
App/App.swift                        @main。AppDatabase と Service の組み立て、WindowGroup
App/Features/<Domain>/               <Domain>View.swift / <Domain>ViewModel.swift
App/Core/                            AppKit ブリッジ、Sparkle、共通部品
AppUITests/                          XCUITest の smoke
```

- 依存方向は **View → ViewModel → Domain(Service → Repository → GRDB)**。逆流・飛び越し禁止
- `Packages/Domain` は **SwiftUI / AppKit を import しない**。Foundation と GRDB だけ。Linux でも `swift test` が通る状態を保つ
- ターゲットやファイルの追加は `project.yml` を直して `make gen`。Xcode 上で追加しない
- ファイルごとの書き方は `.claude/rules/`（`swift.md`、`project-yml.md`）。該当するファイルを開くと読み込まれる

## 手本と追加手順

- 手本は Example の縦 1 本（`Packages/Domain/Sources/Domain/` の `Models/Example.swift`、`Repositories/ExampleRepository.swift`、`Services/ExampleService.swift` と、`App/Features/Example/`）
- 順番：Model → `AppDatabase.migrator` にマイグレーションを追記 → Repository → Service とテスト（`make test-domain`）→ ViewModel → View → `App.swift` で組み立て → `make check`

## 唯一の定義場所

| 概念 | 場所 |
|---|---|
| DB スキーマ | `Packages/Domain/Sources/Domain/Database/` の `AppDatabase.migrator`。`registerMigration("vN_説明")` で追記する |
| 列挙値（種別・状態） | `Packages/Domain/Sources/Domain/Models/` の enum。画面表記はその enum の拡張 |
| 設定のキー | `App/Core/SettingsKeys.swift` の定数。`@AppStorage` はこれを使う |
| サンドボックス外のファイルへのアクセス | `App/Core/Bookmarks.swift`（security-scoped bookmark） |
| ターゲット・ビルド設定・署名設定 | `project.yml`。configuration は `Debug` / `Release-AppStore` / `Release-DeveloperID` の 3 つ |

## 使わないもの

- `ObservableObject` / `@Published` → `@Observable` + `@MainActor`
- SwiftData、Core Data → GRDB
- 単体テストの XCTest → Swift Testing（`@Test`）。XCTest は UI テストだけ

## テスト

- Domain：Swift Testing（`@Test`）。`AppDatabase.inMemory()` で実 SQLite に対して回す。モックしない
- ViewModel：Domain の Service に fake Repository を渡して `@Test`
- UI：XCUITest は起動〜主要画面の smoke 1 本のみ

## 止まって確認する判断

- entitlements を足す（サンドボックスの外へのアクセスが増える）
- 対応する macOS の最低バージョンを変える
- `project.yml` の configuration や署名設定を変える

## 互換性の制約

- 利用者の手元の DB は、旧版のまま更新を受ける。既存のマイグレーションは書き換えず、追記だけにする
- `@AppStorage` のキー名や値の形式を変えるときは、旧い値からの移行を書く

## 確認手段と証拠

- `make run` → `make screenshot` でウィンドウ画像を取り、UI 変更の報告に添える
- Domain の挙動は `make test-domain` が速い（数秒）

## プロジェクト固有（ここを埋める。当てはまらない欄は「該当なし」と書く）

- 目的と利用者、やらないこと：
- ドメイン用語：
- 主要エンティティと DB スキーマ：
- 破ってはならない業務ルール：
- 契約の段階（0〜2）、相手リポジトリ、契約の版：該当なし（スタンドアロン）
- 外部連携と、ローカルでの代わり（スタブ）：
- 環境（ローカル / 検証 / 本番）と、エージェントが届く範囲：
- 外に出ている版（互換の対象）：
- 触ってはいけない場所：
- 依頼の入口と、状態・決定の記録先：
- 必要な entitlements（サンドボックス外アクセス）：
- 配布レーン（App Store / DMG / 両方）：
