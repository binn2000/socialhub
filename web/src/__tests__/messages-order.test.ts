import { describe, expect, it } from "vitest";
import { oldestFirst } from "@/lib/messages";

describe("oldestFirst", () => {
  it("puts the newest message last", () => {
    const fromApi = [{ id: "m3" }, { id: "m2" }, { id: "m1" }];
    expect(oldestFirst(fromApi).map((m) => m.id)).toEqual(["m1", "m2", "m3"]);
  });

  it("does not change the list it was given and copes with nothing", () => {
    const fromApi = [{ id: "b" }, { id: "a" }];
    oldestFirst(fromApi);
    expect(fromApi.map((m) => m.id)).toEqual(["b", "a"]);
    expect(oldestFirst(undefined)).toEqual([]);
    expect(oldestFirst(null)).toEqual([]);
  });
});
