---
paths:
  - "App/**/*.swift"
  - "Packages/**/*.swift"
  - "AppUITests/**/*.swift"
---

# Swift の書き方

- ViewModel は `@Observable` + `@MainActor`。`ObservableObject` / `@Published` は使わない
- View の `@State` は純粋な UI 状態（選択、シート表示）のみ。データは ViewModel
- Repository は protocol で宣言し、Service はそれに依存。テストでは in-memory GRDB か fake を注入
- DB アクセスは `AppDatabase` の `read` / `write` 経由。View や ViewModel から `DatabaseQueue` を触らない
- マイグレーションは `AppDatabase.migrator` に `registerMigration("vN_説明")` で追記。既存マイグレーションを書き換えない
- エラーは `throws` で上げ、ViewModel で `error` プロパティに乗せ、View が alert で出す。握りつぶさない
- サンドボックス前提。ファイルは Application Support か `NSOpenPanel` / `NSSavePanel` で得た URL のみ。security-scoped bookmark が要るなら `Core/Bookmarks.swift` 経由
- 設定は `@AppStorage`。キーは `Core/SettingsKeys.swift` に定数化
