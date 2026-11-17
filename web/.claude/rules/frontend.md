---
paths:
  - "frontend/src/**/*.{ts,tsx}"
---

# フロント（React）の書き方

- 依存方向は `app → features → lib`。逆は dependency-cruiser が落とす
- `features/` からルーターを import しない。ナビゲーションが要るときは `app/` が渡す
- サーバー状態は TanStack Query（`generated/` のフックを使う）。`useEffect` + `fetch` は書かない
- クライアント状態は `useState` で足りなければ Context。Zustand 等は入れない
- フォームは react-hook-form + zod。スキーマは `features/<domain>/schema.ts`
- スタイルは Tailwind のみ。CSS ファイルを増やさない
- `components/ui/` は shadcn/ui。追加は `pnpm dlx shadcn add <name>`
- 判定（しきい値超過・権限の可否・集計）はサーバーが行い、応答に結果を含める。フロントで再計算・再判定しない
- 列挙値は `generated/` の型（OpenAPI の enum）を使い、`'1'` や `'active'` の文字列リテラルで比較しない
- 時刻は API では RFC 3339 UTC。表示用の整形は `lib/time.ts` だけに置く
