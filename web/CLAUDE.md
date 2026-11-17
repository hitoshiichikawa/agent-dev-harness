# CLAUDE.md — web（Go API + Vite/React SPA + AWS CDK）

@.claude/CLAUDE.common.md

## 責任範囲と境界

- 担当はこのリポジトリの中（`api/`、`frontend/`、`infra/`、`openapi/`）。API と Web フロントは 1 つの PR で両側を直す
- 契約は `openapi/openapi.yaml` で、持ち主はこのリポジトリ。API の変更は必ず yaml から始め、ハンドラだけを足さない
- この契約を取り込む別リポジトリ（モバイルなど）は編集しない。相手に影響する変更は、相手側の対応状況を PR 本文に書く

## 実行環境と前提

- Docker が動くローカル環境。`task dev` と Go のテストは、実 Postgres をコンテナで起動する
- Docker が使えない環境では `task check` は通らない。通した部分と通せなかった理由を報告し、完了とは言わない

## コマンド（必ずこれを使う。直接 go/pnpm を叩かない）

```
task dev          # docker compose で api + postgres 起動、vite dev 起動
task check        # 完了条件。lint / 型 / テスト / 依存方向 / cdk synth / 生成コードの鮮度
task gen          # OpenAPI → Go サーバースタブ + TS クライアント、sqlc → Go
task test         # go test + vitest（check の部分集合、速い）
task e2e          # playwright（起動済みの dev サーバーに対して）
task migrate:new name=<snake_case>   # goose マイグレーション SQL を生成（適用はしない）
```

## 人間だけが叩く操作

- `task migrate:up`（マイグレーションの適用）と `cdk deploy`。フックが止める
- 必要になったら、叩くコマンド・理由・戻し方を書いて依頼する。別の書き方で回避しない

## 構成と依存方向

```
api/cmd/api/main.go              起動・DI・ルーター組み立てだけ
api/internal/<domain>/           handler.go / service.go / repo.go / *_test.go
api/internal/platform/           db 接続、ログ、設定、認証ミドルウェア（横断）
api/db/                          migrations/（goose）、queries/（sqlc の入力）
frontend/src/app/                ルート定義、レイアウト、プロバイダ。画面ロジックを置かない
frontend/src/features/<domain>/  pages/ components/ hooks/ schema.ts（zod）
frontend/src/lib/                api クライアント初期化、認証、ユーティリティ
*/generated/                     oapi-codegen・sqlc・orval の出力。触らない
infra/lib/                       CDK。network / database / api / frontend の 4 スタック
```

- API：handler（変換と呼び出し）→ service（ビジネスロジック）→ repo（sqlc の薄いラッパ）。`internal/<domain>` 同士は直接 import しない
- フロント：`app → features → lib`。逆は dependency-cruiser が落とす
- ファイルごとの書き方は `.claude/rules/`（`api.md`、`frontend.md`、`db.md`、`infra.md`、`contract.md`）。該当するファイルを開くと読み込まれる

## 手本と追加手順

- 手本は `example` の縦 1 本（`api/internal/example/`、`api/db/queries/example.sql`、`frontend/src/features/example/`）。機能を足すときはこれを真似る
- 順番：`openapi.yaml` → `task migrate:new` と `db/queries/<domain>.sql` → `task gen` → `api/internal/<domain>/` とテスト → `main.go` で組み立て → `frontend/src/features/<domain>/` と `app/routes/` → `task check`

## 唯一の定義場所

| 概念 | 場所 |
|---|---|
| API の型と列挙値 | `openapi/openapi.yaml`。Go と TS は生成された型を使い、`'1'` や `'active'` の文字列リテラルで比較しない |
| 判定（しきい値・権限の可否・集計） | API の service。結果を応答に含め、フロントは表示するだけ |
| 権限（どのロールがどの操作を呼べるか） | ルーター登録時の宣言。ミドルウェアが一括で検査する |
| 時刻の変換 | API は `internal/platform/clock`、表示用の整形は `frontend/src/lib/time.ts`。API 上は RFC 3339 UTC |
| 設定値 | `internal/platform/config.go`（環境変数のみ）。本番値は `cdk.context.json` か環境変数 |

## 使わないもの

- `useEffect` + `fetch` → TanStack Query（`generated/` のフック）
- Zustand などの状態管理ライブラリ → `useState`、足りなければ Context
- CSS ファイルの追加 → Tailwind
- GORM などの ORM → sqlc + pgx

## テスト

- API：`testcontainers-go` で実 Postgres を起動し、service と repo を試す
- フロント：Vitest。手本は `features/example/schema.test.ts`
- Playwright（`task e2e`）は `check` に含まれない。起動済みの dev サーバーに対して回す

## 止まって確認する判断

- AWS のリソースや IAM の権限を足す・変える（費用と到達範囲が変わる）
- 認証の方式やトークンの有効期間を変える

## 互換性の制約

- 公開した API は、契約を取り込む側が古い版のまま動き続ける。項目の削除・型の変更・必須項目の追加は、後方互換を壊す変更として確認を取る
- 適用済みのマイグレーションは書き換えない。直すときは新しいマイグレーションを足す

## 確認手段と証拠

- API：`task dev` の後 `curl localhost:8080/healthz`。エンドポイントは `/docs`、DB の中は `task db:psql`
- 画面：`http://localhost:5173`。UI を変えたら Playwright かブラウザでスクリーンショットを取り、報告に添える
- インフラ：`cdk diff` の出力を変更の説明に添える

## プロジェクト固有（ここを埋める。当てはまらない欄は「該当なし」と書く）

- 目的と利用者、やらないこと：
- ドメイン用語：
- 主要エンティティと関係：
- 破ってはならない業務ルール：
- 契約の段階（0〜2）、相手リポジトリ、契約の版：
- 外部連携と、ローカルでの代わり（スタブ）：
- 環境（ローカル / 検証 / 本番）と、エージェントが届く範囲：
- 外に出ている版（互換の対象）：
- 触ってはいけない場所：
- 依頼の入口と、状態・決定の記録先：
