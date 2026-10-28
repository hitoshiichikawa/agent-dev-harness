# web — 典型的な web アプリケーション

ログインして使う業務系 web アプリ。公開ページ（SEO が要るもの）はスコープ外（必要なら Astro 等で別サイトに切り出す）。

## 決定事項

| 項目 | 決定 | 見送ったもの | 理由 |
|---|---|---|---|
| API | **Go**（stdlib `net/http` + chi） | TypeScript (Hono/NestJS) | 文法が平易で誰が書いても似る。gofmt で整形が一意。シングルバイナリ。エージェント親和性が高い |
| API 契約 | **OpenAPI 3** → `oapi-codegen`（Go）/ `orval`（TS）/ `openapi-generator`（Dart） | Connect/gRPC, tRPC | Go・TS・Dart の 3 言語で枯れている。mobile と同じ契約を共有 |
| DB | **Postgres**（本番 Aurora Serverless v2）| DynamoDB | リレーショナルな業務ドメイン。ローカルはコンテナで完結 |
| データアクセス | **sqlc + pgx** | GORM, ent | SQL をそのまま書いて型付き Go を生成。「工夫の余地を減らす」思想と一致 |
| マイグレーション | **goose** | golang-migrate | SQL ファイルで管理、Go から埋め込める |
| 認証 | Go 側で **短命 access + refresh トークン**、外部 IdP は OIDC | Cognito | Cognito はローカルエミュレータなし・ユーザープール移行不可。ロックイン回避とローカル完結を優先 |
| フロント | **Vite + React + TypeScript** SPA | Next.js | API が Go にあるので SSR/RSC の利点が薄い。Node サーバーを本番に置かない |
| ルーティング / データ | **TanStack Router + TanStack Query** | React Router | 型安全なルート。サーバー状態は Query に任せ、クライアント状態は最小 |
| UI | **Tailwind + shadcn/ui** | MUI, Chakra | コンポーネントがリポジトリ内にコピーされ、エージェントが読んで直せる |
| バリデーション | **zod**（フロント）/ OpenAPI スキーマ（API） | — | 契約は OpenAPI が正。フォームの入力検証だけ zod |
| Lint/Format | **gofmt + golangci-lint** / **Biome** | ESLint + Prettier | Biome は 1 ツール 1 ファイルで高速。フックで毎編集回せる |
| 依存方向 | **dependency-cruiser**（TS）/ パッケージ構造（Go） | — | `app → features → lib` の逆流を機械検出 |
| テスト | **Go `testing` + testcontainers** / **Vitest + Playwright** | モック DB | DB は実物（コンテナ）でテスト。Playwright はエージェントのブラウザ確認にも使う |
| 配信 | SPA は **S3 + CloudFront**、API は **ECS Fargate** | Go に embed、OpenNext/Lambda | フロントと API のデプロイを独立させる。静的資産を CDN に |
| IaC | **AWS CDK (TypeScript)** | Terraform | 決定済み。`synth`/`diff` までエージェント、`deploy` は人間 |
| タスクランナー | **Task**（`Taskfile.yml`）| Make, npm scripts | Go/TS 横断で 1 つのエントリポイント。`task check` が完了条件 |
| モノレポ | **pnpm workspace**（frontend, infra）+ Go module（api） | — | Go は pnpm の外。Taskfile が束ねる |

## 構成

```
template/
├── Taskfile.yml           # task dev / check / gen / test  ← エージェントのエントリポイント
├── docker-compose.yml     # api + postgres（ローカル完結）
├── openapi/openapi.yaml   # 契約のソース・オブ・トゥルース（mobile と共有）
├── api/                   # Go
│   ├── cmd/api/main.go
│   ├── internal/<domain>/ # handler / service / repo を縦割り
│   ├── internal/generated/ # oapi-codegen, sqlc の出力（触らない）
│   ├── db/migrations/     # goose
│   ├── db/queries/        # sqlc 入力 SQL
│   ├── sqlc.yaml / oapi-codegen.yaml / .golangci.yml
│   └── Dockerfile
├── frontend/              # Vite + React
│   ├── src/app/           # ルート定義・レイアウトのみ
│   ├── src/features/<domain>/  # 画面・hooks・zod スキーマ
│   ├── src/lib/           # 横断ユーティリティ
│   ├── src/generated/     # orval の出力（触らない）
│   ├── biome.json / .dependency-cruiser.cjs / orval.config.ts
│   └── playwright.config.ts
└── infra/                 # CDK
    ├── bin/app.ts
    └── lib/{network,database,api,frontend}-stack.ts
```

## scaffold 手順

`template/` は設定ファイルと構造を持つ。アプリ本体は以下で生成してから、template の設定で上書きする。

```bash
cp -r agent-dev-harness/web/template my-app && cd my-app

# frontend
cd frontend && pnpm create vite . --template react-ts && pnpm add @tanstack/react-router @tanstack/react-query zod \
  && pnpm add -D @biomejs/biome dependency-cruiser orval vitest @playwright/test tailwindcss \
  && pnpm dlx shadcn@latest init && cd ..

# api
cd api && go mod init github.com/<org>/my-app/api && go get github.com/jackc/pgx/v5 github.com/go-chi/chi/v5 github.com/pressly/goose/v3 \
  && go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest && cd ..

# infra
cd infra && pnpm add aws-cdk-lib constructs && pnpm add -D aws-cdk && cd ..

task gen && task check
```

## 検証ループ

| タイミング | 何が走るか |
|---|---|
| 編集のたび（PostToolUse フック） | `.go` → `gofmt -l` + `go vet`、`.ts/.tsx` → `biome check` |
| `task check`（完了条件） | golangci-lint、go test、tsc、biome、dependency-cruiser、vitest、`cdk synth` |
| `openapi.yaml` / `db/queries/*.sql` を変えたら | `task gen` → 生成コードの差分が出る → 両側の型チェックで壊れを検出 |
| UI 変更時 | `task dev` で起動 → Playwright またはブラウザでスクリーンショット |
| DB スキーマ変更 | `task migrate:new` で SQL を生成 → 人間がレビュー → `task migrate:up` は人間が叩く |
| インフラ | `cdk diff` までエージェント。`cdk deploy` はフックでブロック |

## エージェントが間違えやすい点（CLAUDE.md に書いてある理由）

- `features/` から `react-router` や `@tanstack/react-router` を直接 import してしまう → ルーティングは `app/` だけ。features は props で受ける
- Go で `internal/<domain>` 同士を直接 import してしまう → ドメイン間は interface 経由。循環が出たら設計が間違っている
- sqlc の出力を手で直す → `db/queries/*.sql` を直して `task gen`
- OpenAPI を更新せずハンドラだけ足す → 契約が正。先に yaml を直す
- `useEffect` でデータ取得 → TanStack Query を使う
