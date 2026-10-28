import { describe, expect, it } from "vitest";
import { exampleCreateSchema } from "./schema";

describe("exampleCreateSchema", () => {
  it("trims and accepts a valid name", () => {
    expect(exampleCreateSchema.parse({ name: "  ok  " })).toEqual({ name: "ok" });
  });
  it("rejects empty", () => {
    expect(exampleCreateSchema.safeParse({ name: "   " }).success).toBe(false);
  });
});
