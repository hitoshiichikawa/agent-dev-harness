import { defineConfig } from "orval";

/** OpenAPI → TanStack Query フック + zod スキーマ。出力は src/generated（触らない） */
export default defineConfig({
  api: {
    input: "../openapi/openapi.yaml",
    output: {
      target: "src/generated/api.ts",
      schemas: "src/generated/model",
      client: "react-query",
      mode: "tags-split",
      clean: true,
      override: {
        mutator: { path: "src/lib/fetcher.ts", name: "fetcher" },
        query: { useQuery: true, useInfinite: true, useInfiniteQueryParam: "cursor" },
      },
    },
  },
  zod: {
    input: "../openapi/openapi.yaml",
    output: { target: "src/generated/zod", client: "zod", mode: "tags-split", clean: true },
  },
});
