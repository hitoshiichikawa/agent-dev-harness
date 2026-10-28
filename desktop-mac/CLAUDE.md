# CLAUDE.md — desktop-mac（SwiftUI + MVVM + GRDB、XcodeGen）

@.claude/CLAUDE.common.md

## コマンド（必ずこれを使う）

```
make check          # 完了条件。format / lint / swift test (Domain) / xcodebuild test (App)
make test-domain    # swift test だけ（速い。ロジック変更時はまずこれ）
make test           # xcodebuild test（App ターゲット含む）
make gen            # xcodegen generate（project.yml を変えたら）
make build          # Debug ビルド
make run            # ビルドして起動
make screenshot     # 起動中のアプリのウィンドウをキャプチャ
```

`xcodebuild archive`、`-exportArchive`、`codesign`、`notarytool`、`create-dmg`、fastlane はフックでブロックされている。

## 構成と依存方向

```
project.yml                    XcodeGen。ターゲット・設定・entitlements。.xcodeproj は生成物
Packages/Domain/Sources/Domain/
  Models/                      struct + Codable + GRDB の FetchableRecord/PersistableRecord
  Database/                    AppDatabase（接続・マイグレーション）
  Repositories/                protocol + GRDB 実装
  Services/                    ビジネスロジック。Repository を protocol で受ける
Packages/Domain/Tests/DomainTests/   in-memory DB で回す
App/App.swift                  @main。AppDatabase と Service の組み立て、WindowGroup
App/Features/<Domain>/
  <Domain>View.swift           SwiftUI View。ViewModel を観察するだけ
  <Domain>ViewModel.swift      @Observable @MainActor。Domain の Service を呼ぶ
App/Core/                      AppKit ブリッジ、Sparkle、共通部品
```

- 依存方向は **View → ViewModel → Domain(Service → Repository → GRDB)**。逆流・飛び越し禁止
- `Packages/Domain` は **SwiftUI / AppKit を import しない**。Foundation と GRDB だけ。Linux でも `swift test` が通る状態を保つ
- ViewModel は `@Observable` + `@MainActor`。`ObservableObject` / `@Published` は使わない
- View の `@State` は純粋な UI 状態（選択、シート表示）のみ。データは ViewModel
- Repository は protocol で宣言し、Service はそれに依存。テストでは in-memory GRDB か fake を注入
- DB アクセスは `AppDatabase` の `read` / `write` 経由。View や ViewModel から `DatabaseQueue` を触らない
- マイグレーションは `AppDatabase.migrator` に `registerMigration("vN_説明")` で追記。既存マイグレーションを書き換えない
- エラーは `throws` で上げ、ViewModel で `error` プロパティに乗せ、View が alert で出す。握りつぶさない
- サンドボックス前提。ファイルは Application Support か `NSOpenPanel` / `NSSavePanel` で得た URL のみ。security-scoped bookmark が要るなら `Core/Bookmarks.swift` 経由
- 設定は `@AppStorage`。キーは `Core/SettingsKeys.swift` に定数化

## project.yml のルール

- ターゲット・ファイル追加は `project.yml` を直す。Xcode 上で追加しない
- configuration は `Debug` / `Release-AppStore` / `Release-DeveloperID` の 3 つ。署名設定はここでしか切り替えない
- 変更したら `make gen`。PostToolUse フックが自動で呼ぶが、失敗したら止まる

## テスト

- Domain：Swift Testing（`@Test`）。`AppDatabase.inMemory()` で実 SQLite に対して回す。モックしない
- ViewModel：Domain の Service に fake Repository を渡して `@Test`
- UI：XCUITest は起動〜主要画面の smoke 1 本のみ

## 確認手段

- `make run` → `make screenshot` でウィンドウ画像を取り、UI 変更の報告に添える
- Domain の挙動は `make test-domain` が速い（数秒）

## プロジェクト固有（新規プロジェクトでここを埋める）

- アプリの目的とドメイン用語：
- 主要エンティティと DB スキーマ：
- 必要な entitlements（サンドボックス外アクセス）：
- 配布レーン（App Store / DMG / 両方）：
