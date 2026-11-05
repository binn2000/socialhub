import { describe, expect, it } from "vitest";
import { checkChatFiles, describeRejected, pastedImageName, MAX_CHAT_FILE_BYTES } from "@/lib/chat-files";

const file = (name: string, size = 10) => ({ name, size });

describe("checkChatFiles", () => {
  it("keeps what the server takes and says why the rest is left out", () => {
    const { accepted, rejected } = checkChatFiles([
      file("a.JPG"),
      file("b.pdf"),
      file("c.gif"),
      file("d.mp4"),
      file("e.png", MAX_CHAT_FILE_BYTES + 1),
      file("noext"),
    ]);
    expect(accepted.map((f) => f.name)).toEqual(["a.JPG", "b.pdf"]);
    expect(rejected.map((r) => [r.file.name, r.reason])).toEqual([
      ["c.gif", "type"],
      ["d.mp4", "type"],
      ["e.png", "size"],
      ["noext", "type"],
    ]);
    expect(describeRejected(rejected)).toContain("Không gửi được loại tệp này");
    expect(describeRejected([{ file: file("big.png"), reason: "size" }])).toContain("quá 10 MB");
    expect(describeRejected([])).toBeNull();
  });
});

describe("pastedImageName", () => {
  const now = new Date("2026-11-05T08:00:00.000Z");

  it("gives a pasted screenshot a name that matches its real type", () => {
    expect(pastedImageName("image/png", "image.png", now)).toBe("anh-dan-2026-11-05T08-00-00-000Z.png");
    // A JPEG copied from a web page and called image.png must not reach the server as .png.
    expect(pastedImageName("image/jpeg", "image.png", now)).toMatch(/\.jpg$/);
    expect(pastedImageName("image/webp", "cat.webp", now)).toBe("cat.webp");
    expect(pastedImageName("image/png", "", now)).toMatch(/\.png$/);
  });

  it("refuses picture types the server does not take", () => {
    expect(pastedImageName("image/gif", "anim.gif", now)).toBeNull();
    expect(pastedImageName("image/heic", "photo.heic", now)).toBeNull();
  });
});

import { quickReactionOf, QUICK_REACTIONS } from "@/lib/quick-reactions";

describe("quickReactionOf", () => {
  it("falls back to 👍 for anything empty and preserves any emoji", () => {
    expect(quickReactionOf("❤️")).toBe("❤️");
    expect(quickReactionOf(undefined)).toBe("👍");
    expect(quickReactionOf("")).toBe("👍");
    expect(quickReactionOf("🦄")).toBe("🦄");
    expect(QUICK_REACTIONS).toHaveLength(12);
  });
});
