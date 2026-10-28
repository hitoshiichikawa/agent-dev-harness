import { createFileRoute } from "@tanstack/react-router";
import { ExampleListPage } from "@/features/example/pages/ExampleListPage";

/** ルートは features のページを置くだけ。ナビゲーションが要るなら props で関数を渡す。 */
export const Route = createFileRoute("/")({
  component: () => <ExampleListPage onSelect={(id) => Route.useNavigate()({ to: "/examples/$id", params: { id } })} />,
});
