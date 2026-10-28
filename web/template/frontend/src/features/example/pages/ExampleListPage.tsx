import { useListExamples } from "@/generated/example/example";
import { ExampleCreateForm } from "../components/ExampleCreateForm";

type Props = { onSelect: (id: string) => void };

/** ページ = 生成された Query フック + コンポーネントの組み立て。useEffect + fetch は書かない。 */
export function ExampleListPage({ onSelect }: Props) {
  const { data, isPending, error } = useListExamples({ limit: 20 });

  if (isPending) return <p>読み込み中…</p>;
  if (error) return <p role="alert">読み込みに失敗しました</p>;

  return (
    <section className="space-y-4">
      <h1 className="text-xl font-semibold">Examples</h1>
      <ExampleCreateForm />
      <ul className="divide-y">
        {data.items.map((it) => (
          <li key={it.id}>
            <button type="button" className="w-full py-2 text-left hover:bg-muted" onClick={() => onSelect(it.id)}>
              {it.name}
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
