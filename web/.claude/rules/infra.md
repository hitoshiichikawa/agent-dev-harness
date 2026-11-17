---
paths:
  - "infra/**/*.ts"
---

# インフラ（CDK）の書き方

- スタックは `network` / `database` / `api` / `frontend` の 4 つ。1 スタックに全部書かない
- `cdk synth` が `task check` に含まれる。`cdk diff` は変更の説明に使う
- 本番値（ドメイン、証明書 ARN）は `cdk.context.json` か環境変数。コードに書かない
