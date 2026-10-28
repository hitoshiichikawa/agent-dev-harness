# CLAUDE.md — web（Go API + Vite/React SPA + AWS CDK）

@.claude/CLAUDE.common.md

## コマンド（必ずこれを使う。直接 go/pnpm を叩かない）

```
task dev          # docker compose で api + postgres 起動、vite dev 起動
task check        # 完了条件。lint / 型 / テスト / 依存方向 / cdk synth をすべて実行
task gen          # OpenAPI → Go サーバースタブ + TS クライアント、sqlc → Go
task test         # go test + vitest（check の部分集合、速い）
task e2e          # playwright（起動済みの dev サーバーに対して）
task migrate:new name=<snake_case>   # goose マイグレーション SQL を生成（適用はしない）
```

`task migrate:up`、`cdk deploy` はフックでブロックされている。必要なときは人間に依頼する。

## 構成と依存方向

### API（Go, `api/`）

```
cmd/api/main.go            起動・DI・ルーター組み立てだけ
internal/<domain>/         handler.go / service.go / repo.go / *_test.go
internal/generated/api/    oapi-codegen 出力。触らない
internal/generated/db/     sqlc 出力。触らない
internal/platform/         db 接続、ログ、設定、認証ミドルウェア（横断）
db/migrations/             goose。*.sql
db/queries/                sqlc 入力。<domain>.sql
```

- `internal/<domain>` 同士は直接 import しない。必要なら interface を呼ぶ側のパッケージに定義し、`main.go` で実装を渡す
- handler は OpenAPI 生成の `ServerInterface` を実装する。リクエストの検証は生成コード側のミドルウェアに任せ、handler で再検証しない
- service にビジネスロジック。handler は変換と呼び出しだけ、repo は sqlc の薄いラッパ
- エラーは `fmt.Errorf("...: %w", err)` でラップ。HTTP ステータスへの変換は handler の 1 箇所で
- context は第一引数で必ず渡す。goroutine を起動するときは `errgroup` を使い、裸の `go` は書かない
- テストは `testcontainers-go` で実 Postgres を起動する。DB をモックしない
- 設定は環境変数のみ（`internal/platform/config.go`）。デフォルト値はローカル開発用

### フロント（`frontend/src/`）

```
app/                ルート定義（TanStack Router）、レイアウト、プロバイダ。画面ロジックを置かない
features/<domain>/  pages/ components/ hooks/ schema.ts（zod）
lib/                api クライアント初期化、認証、ユーティリティ
generated/          orval 出力。触らない
components/ui/      shadcn/ui。追加は `pnpm dlx shadcn add <name>`
```

- 依存方向は `app → features → lib`。逆は dependency-cruiser が落とす
- `features/` からルーターを import しない。ナビゲーションが要るときは `app/` が渡す
- サーバー状態は TanStack Query（`generated/` のフックを使う）。`useEffect` + `fetch` は書かない
- クライアント状態は `useState` で足りなければ Context。Zustand 等は入れない
- フォームは react-hook-form + zod。スキーマは `features/<domain>/schema.ts`
- スタイルは Tailwind のみ。CSS ファイルを増やさない

### 契約（`openapi/openapi.yaml`）

- API の変更は **必ず yaml から**。yaml → `task gen` → Go の `ServerInterface` が変わる → 実装 → TS 側の型が変わる → 画面修正、の順
- 後方互換を壊す変更（必須フィールド追加、型変更、エンドポイント削除）は確認を取る
- `operationId` は `<verb><Resource>`（`listUsers`, `createOrder`）。これが生成される関数名になる

### DB

- マイグレーションは `task migrate:new` で雛形を作り、up/down を両方書く
- カラム削除・型変更は確認を取る
- クエリは `db/queries/<domain>.sql` に sqlc 形式で書く。`SELECT *` は使わない

### インフラ（`infra/`）

- スタックは `network` / `database` / `api` / `frontend` の 4 つ。1 スタックに全部書かない
- `cdk synth` が `task check` に含まれる。`cdk diff` は変更の説明に使う
- 本番値（ドメイン、証明書 ARN）は `cdk.context.json` か環境変数。コードに書かない

## 確認手段

- API：`task dev` 後 `curl localhost:8080/healthz`。エンドポイントは生成された OpenAPI の `/docs` で確認
- 画面：`http://localhost:5173`。UI 変更は Playwright かブラウザでスクリーンショットを取って報告
- DB：`task db:psql` で中を見られる

## プロジェクト固有（新規プロジェクトでここを埋める）

- ドメイン用語：
- 主要エンティティと関係：
- 触ってはいけない場所：
- 外部連携：
