/** 依存方向を機械的に守らせる。app → features → lib。features 同士は禁止。 */
module.exports = {
  forbidden: [
    {
      name: "features-must-not-import-app",
      severity: "error",
      from: { path: "^src/features" },
      to: { path: "^src/app" },
    },
    {
      name: "lib-must-not-import-features-or-app",
      severity: "error",
      from: { path: "^src/lib" },
      to: { path: "^src/(features|app)" },
    },
    {
      name: "no-cross-feature-import",
      severity: "error",
      comment: "features 同士は直接依存しない。共有が必要なら lib に下ろすか、app が組み合わせる",
      from: { path: "^src/features/([^/]+)/" },
      to: { path: "^src/features/([^/]+)/", pathNot: "^src/features/$1/" },
    },
    {
      name: "features-must-not-import-router",
      severity: "error",
      comment: "ナビゲーションは app/ が担当。features は props で受ける",
      from: { path: "^src/features" },
      to: { path: "@tanstack/react-router" },
    },
    {
      name: "no-direct-generated-import-from-app",
      severity: "warn",
      comment: "生成 API は features 経由で使う",
      from: { path: "^src/app" },
      to: { path: "^src/generated" },
    },
    { name: "no-circular", severity: "error", from: {}, to: { circular: true } },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" },
    tsPreCompilationDeps: true,
  },
};
