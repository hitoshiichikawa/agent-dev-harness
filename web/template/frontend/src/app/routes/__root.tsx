import { Outlet, createRootRoute } from "@tanstack/react-router";
import { Providers } from "../providers";

/** ルートレイアウト。画面ロジックは置かない。 */
export const Route = createRootRoute({
  component: () => (
    <Providers>
      <main className="mx-auto max-w-5xl p-4">
        <Outlet />
      </main>
    </Providers>
  ),
});
