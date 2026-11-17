---
paths:
  - "api/db/**/*.sql"
---

# DB（goose と sqlc）の書き方

- マイグレーションは `task migrate:new` で雛形を作り、up/down を両方書く
- 適用済みのマイグレーションは書き換えない。直すときは新しいマイグレーションを足す
- カラム削除・型変更は確認を取る
- クエリは `db/queries/<domain>.sql` に sqlc 形式で書く。`SELECT *` は使わない
- 書いたら `task gen`。`internal/generated/db/` を手で直さない
