---
paths:
  - "openapi/**/*.yaml"
---

# 契約（OpenAPI）の書き方

- 変更の順番は yaml → `task gen` → Go の `ServerInterface` が変わる → 実装 → TS 側の型が変わる → 画面修正
- 後方互換を壊す変更（必須フィールド追加、型変更、エンドポイント削除）は確認を取る
- `operationId` は `<verb><Resource>`（`listUsers`, `createOrder`）。これが生成される関数名になる
