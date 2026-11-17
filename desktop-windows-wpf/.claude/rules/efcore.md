---
paths:
  - "src/*.Domain/Models/**/*.cs"
  - "src/*.Domain/Data/**/*.cs"
  - "src/*.Domain/Repositories/**/*.cs"
---

# EF Core の書き方

- モデルを変えたら `make migrate name=Xxx` でマイグレーションを生成し、差分を報告に含める
- 既存マイグレーションファイルを書き換えない。`Data/Migrations/` はフックで編集ブロック
- 適用はアプリ起動時の `Database.Migrate()`。手動 `database update` は人間
- クエリは `AsNoTracking()` を既定。更新するときだけ追跡
- テストは SQLite の in-memory で回す。InMemory プロバイダは使わない（SQLite と挙動が違う）
