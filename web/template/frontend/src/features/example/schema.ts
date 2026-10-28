import { z } from "zod";

/** フォーム入力の検証。API 契約は OpenAPI が正なので、ここは UI 側の追加ルールだけ。 */
export const exampleCreateSchema = z.object({
  name: z.string().trim().min(1, "名前は必須です").max(100, "100 文字以内"),
});
export type ExampleCreateInput = z.infer<typeof exampleCreateSchema>;
