---
paths:
  - "api/**/*.go"
---

# API（Go）の書き方

- `internal/<domain>` 同士は直接 import しない。必要なら interface を呼ぶ側のパッケージに定義し、`main.go` で実装を渡す
- handler は OpenAPI 生成の `ServerInterface` を実装する。リクエストの検証は生成コード側のミドルウェアに任せ、handler で再検証しない
- service にビジネスロジック。handler は変換と呼び出しだけ、repo は sqlc の薄いラッパ
- エラーは `fmt.Errorf("...: %w", err)` でラップ。HTTP ステータスへの変換は handler の 1 箇所で
- 権限（どのロールがどの操作を呼べるか）はルーター登録時に宣言し、ミドルウェアが一括で検査する。handler 本文でロールを見ない
- 時刻の変換は `internal/platform/clock` だけ。`time.Now().Add(9*time.Hour)` のような手変換を書かない
- context は第一引数で必ず渡す。goroutine を起動するときは `errgroup` を使い、裸の `go` は書かない
- テストは `testcontainers-go` で実 Postgres を起動する。DB をモックしない
- 設定は環境変数のみ（`internal/platform/config.go`）。デフォルト値はローカル開発用
