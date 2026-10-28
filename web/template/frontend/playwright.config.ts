import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  use: { baseURL: "http://localhost:5173", screenshot: "only-on-failure", trace: "retain-on-failure" },
  reporter: [["list"], ["html", { open: "never" }]],
  // task dev で起動済みの想定。CI では webServer を使う
  webServer: process.env.CI ? { command: "pnpm dev", url: "http://localhost:5173", reuseExistingServer: false } : undefined,
});
