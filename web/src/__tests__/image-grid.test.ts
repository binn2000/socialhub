import { describe, expect, it } from "vitest";
import { getImageGridLayout } from "@/lib/image-grid";

describe("getImageGridLayout", () => {
  it("shows every picture up to five", () => {
    for (const count of [1, 2, 3, 4, 5]) {
      expect(getImageGridLayout(count)).toEqual({ visible: count, hidden: 0 });
    }
  });

  it("hides the rest behind +N from six pictures on", () => {
    expect(getImageGridLayout(6)).toEqual({ visible: 5, hidden: 1 });
    expect(getImageGridLayout(8)).toEqual({ visible: 5, hidden: 3 });
    expect(getImageGridLayout(10)).toEqual({ visible: 5, hidden: 5 });
  });

  it("copes with no pictures", () => {
    expect(getImageGridLayout(0)).toEqual({ visible: 0, hidden: 0 });
  });
});
