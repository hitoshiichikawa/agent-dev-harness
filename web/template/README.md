# <project name>

web パターン（dev-harness/web）から生成。設計判断は dev-harness/web/README.md を参照。

## 起動

    task dev        # api + postgres + vite

## 完了条件

    task check

## 構成

- `api/` Go API（chi + sqlc + goose）
- `frontend/` Vite + React SPA
- `infra/` AWS CDK
- `openapi/` 契約（web / mobile 共有）
