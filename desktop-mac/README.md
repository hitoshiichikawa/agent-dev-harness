# desktop-mac — 典型的な mac アプリケーション

スタンドアロン（サーバーなし）の Shoebox 型アプリ。アプリがデータを内部で一括管理する（メモ.app、写真.app の形）。
Document 型（ユーザーがファイルを開く・保存する）は末尾の「Document 型にする場合」を参照。

## 決定事項

| 項目 | 決定 | 見送ったもの | 理由 |
|---|---|---|---|
| UI | **SwiftUI**（AppKit は必要箇所だけ `NSViewRepresentable`） | AppKit | 現在の標準。macOS は iOS より SwiftUI の穴が多いので AppKit ブリッジは前提 |
| 最低バージョン | **macOS 14 (Sonoma)** | 13 | `@Observable`、SwiftUI の安定度がここで変わる |
| アーキテクチャ | **MVVM**（`@Observable` ViewModel） | TCA | TCA は厳密だが学習コストと変更追随が重い |
| プロジェクト定義 | **XcodeGen**（`project.yml` → `.xcodeproj` 生成） | Tuist, 手動 | `.pbxproj` はエージェントにも人間にも編集不能。YAML から生成して `.xcodeproj` は git に入れない |
| 依存管理 | **Swift Package Manager** | CocoaPods | 公式 |
| ドメイン層 | **ローカル Swift Package**（`Packages/Domain`） | アプリターゲット内 | Xcode なしで `swift test` が回る。検証ループが速い |
| 永続化 | **GRDB**（SQLite） | SwiftData, Core Data | SQL ベースで型安全。sqlc / drift と同じ思想。SwiftData はまだ不安定で学習量も少ない |
| 設定 | `UserDefaults`（`@AppStorage`） | — | — |
| テスト | **Swift Testing**（`@Test`）+ XCTest（UI テスト） | XCTest のみ | Swift Testing は Xcode 16 以降の標準。XCUITest はまだ XCTest |
| Lint/Format | **SwiftFormat + SwiftLint** | — | SwiftFormat が gofmt 相当。SwiftLint はルール厳しめで |
| サンドボックス | **最初から有効** | — | App Store の制約が厳しい側。合わせておけば DMG にも出せる。逆は大改修 |
| 配布 | **2 レーン**：App Store / Developer ID + notarization + DMG（**Sparkle** で自動更新） | どちらか片方 | 差はコードではなく署名・配布設定。1 コードベースで両方持つ |
| CI | GitHub Actions (macOS runner) + `xcodebuild` + fastlane | Xcode Cloud | fastlane は mobile と共通化 |

## 構成

```
template/
├── Makefile                      # make check / test / gen / run  ← エージェントのエントリポイント
├── project.yml                   # XcodeGen。configurations で AppStore / DeveloperID を切替
├── .swiftformat / .swiftlint.yml
├── Packages/Domain/              # UI 非依存のドメイン層（Swift Package）
│   ├── Package.swift
│   ├── Sources/Domain/           # Models / Repositories / Services / Database（GRDB）
│   └── Tests/DomainTests/        # swift test で回る
├── App/                          # アプリターゲット
│   ├── App.swift                 # @main。DI と WindowGroup だけ
│   ├── Features/<domain>/        # <Domain>View.swift / <Domain>ViewModel.swift
│   ├── Core/                     # AppKit ブリッジ、Sparkle 設定、共通 UI 部品
│   ├── Resources/Assets.xcassets
│   ├── App.entitlements          # サンドボックス
│   └── Info.plist
├── AppUITests/
└── fastlane/Fastfile             # lane :appstore / lane :dmg（人間が叩く）
```

依存方向：**View → ViewModel → Domain（Service → Repository → GRDB）**。View は ViewModel を観察するだけ。ViewModel は Domain を呼ぶだけで、GRDB を直接触らない。

## scaffold 手順

```bash
cp -r dev-harness/desktop-mac/template MyApp && cd MyApp
cp dev-harness/desktop-mac/CLAUDE.md . && cp -r dev-harness/desktop-mac/.claude . \
  && cp -r dev-harness/common/.claude/hooks .claude/hooks/common && cp dev-harness/common/CLAUDE.md .claude/CLAUDE.common.md
brew install xcodegen swiftformat swiftlint
# project.yml の name / bundleIdPrefix / DEVELOPMENT_TEAM を書き換える
make gen      # xcodegen generate → MyApp.xcodeproj
make check
```

## 検証ループ

| タイミング | 何が走るか |
|---|---|
| 編集のたび（PostToolUse フック） | `swiftformat` → `swiftlint lint`（そのファイル） |
| `make check`（完了条件） | format 差分なし、swiftlint 警告ゼロ、`swift test`（Domain）、`xcodebuild build test`（App） |
| `project.yml` 変更時 | `make gen` で `.xcodeproj` 再生成（PostToolUse が自動で呼ぶ） |
| UI 変更時 | `make run` で起動 → スクリーンショットを取って報告 |
| リリース | archive・署名・notarization・DMG 作成・App Store 提出はフックでブロック。人間が `fastlane` を叩く |

## mac 固有の制約

- ビルドは macOS 上でしか動かない。このパターンのハーネスは **ローカル Mac での実行が前提**。Linux のクラウド環境では `swift build` は通るが SwiftUI はコンパイルできない
- `Packages/Domain` は Linux でもテストできるよう **Foundation と GRDB 以外に依存しない**。クラウドのエージェントはここだけ検証できる

## Document 型にする場合

- `WindowGroup` を `DocumentGroup(newDocument:)` に変え、`FileDocument`（or `ReferenceFileDocument`）を実装する
- 永続化は GRDB ではなくファイル（Codable + JSON / 独自形式）。GRDB は「アプリ全体の索引」など補助用途に残す
- `project.yml` の `info` に `CFBundleDocumentTypes` / `UTExportedTypeDeclarations` を足す
- サンドボックスでは `com.apple.security.files.user-selected.read-write` が必要

## エージェントが間違えやすい点

- `.xcodeproj` を直接編集しようとする → `project.yml` を直して `make gen`。フックで編集はブロック済み
- View に `@State` でビジネスデータを持つ → ViewModel に `@Observable` で持つ
- ViewModel から GRDB を直接呼ぶ → Domain の Service / Repository 経由
- `ObservableObject` + `@Published` を書く → macOS 14 以降は `@Observable`
- サンドボックス外のパス（`~/Documents` 直書き等）に書く → `FileManager.default.urls(for: .applicationSupportDirectory, ...)` か `NSOpenPanel` 経由
- UI テストを増やしすぎる → XCUITest は起動〜主要画面の smoke のみ。ロジックは Domain のテストで
