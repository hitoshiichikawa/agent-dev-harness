import { zodResolver } from "@hookform/resolvers/zod";
import { useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { getListExamplesQueryKey, useCreateExample } from "@/generated/example/example";
import { type ExampleCreateInput, exampleCreateSchema } from "../schema";

export function ExampleCreateForm() {
  const qc = useQueryClient();
  const { register, handleSubmit, reset, formState } = useForm<ExampleCreateInput>({
    resolver: zodResolver(exampleCreateSchema),
  });
  const create = useCreateExample({
    mutation: {
      onSuccess: () => {
        reset();
        qc.invalidateQueries({ queryKey: getListExamplesQueryKey() });
      },
    },
  });

  return (
    <form className="flex gap-2" onSubmit={handleSubmit((v) => create.mutate({ data: v }))}>
      <input className="flex-1 rounded border px-2 py-1" placeholder="name" {...register("name")} />
      <button type="submit" className="rounded bg-primary px-3 py-1 text-primary-foreground" disabled={create.isPending}>
        追加
      </button>
      {formState.errors.name && <p role="alert" className="text-sm text-destructive">{formState.errors.name.message}</p>}
    </form>
  );
}
