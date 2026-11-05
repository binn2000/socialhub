import { describe, expect, it } from "vitest";
import { lastSeenOfMine, sendState } from "@/lib/message-status";
import { findMatchingMessageIds, normalizeForSearch } from "@/lib/chat-search";
import type { Message } from "@/types";

const msg = (id: string, text: string, over: Partial<Message> = {}): Message => ({
  id,
  conversationId: "c1",
  senderId: "me",
  text,
  isRecalled: false,
  reactions: {},
  myReaction: null,
  attachments: [],
  createdAt: "2026-11-05T05:00:00Z",
  ...over,
});

describe("sendState", () => {
  it("is sent, then delivered, then seen as the other person's markers move", () => {
    expect(sendState("m3", null, null)).toBe("sent");
    expect(sendState("m3", "m2", null)).toBe("sent");
    expect(sendState("m3", "m3", null)).toBe("delivered");
    expect(sendState("m3", "m5", "m2")).toBe("delivered");
    expect(sendState("m3", "m5", "m3")).toBe("seen");
    expect(sendState("m1", "m5", "m3")).toBe("seen");
  });
});

describe("lastSeenOfMine", () => {
  it("is the newest of my messages up to what the other person read", () => {
    const list = [msg("m1", "a"), msg("m2", "b", { senderId: "them" }), msg("m3", "c"), msg("m4", "d")];
    expect(lastSeenOfMine(list, "me", "m3")).toBe("m3");
    expect(lastSeenOfMine(list, "me", "m2")).toBe("m1");
    expect(lastSeenOfMine(list, "me", null)).toBeNull();
  });

  it("skips a recalled message", () => {
    const list = [msg("m1", "a"), msg("m2", "", { isRecalled: true })];
    expect(lastSeenOfMine(list, "me", "m2")).toBe("m1");
  });
});

describe("in-chat search", () => {
  it("ignores accents and case", () => {
    expect(normalizeForSearch("Hà Nội, Đà Lạt")).toBe("ha noi, da lat");
    const list = [msg("m1", "Hẹn ở Hà Nội nhé"), msg("m2", "Tối nay")];
    expect(findMatchingMessageIds(list, "ha noi")).toEqual(["m1"]);
    expect(findMatchingMessageIds(list, "TOI")).toEqual(["m2"]);
    expect(findMatchingMessageIds(list, "  ")).toEqual([]);
  });

  it("looks at what was written, not at quotes, stickers or recalled messages", () => {
    const list = [
      msg("m1", "[reply:m0:Lan:số tài khoản]\nĐược rồi"),
      msg("m2", "[sticker:3d_haha:https://fonts.gstatic.com/x.webp]"),
      msg("m3", "bí mật", { isRecalled: true }),
    ];
    expect(findMatchingMessageIds(list, "tai khoan")).toEqual([]); // only in the quote
    expect(findMatchingMessageIds(list, "duoc")).toEqual(["m1"]);
    expect(findMatchingMessageIds(list, "haha")).toEqual([]);
    expect(findMatchingMessageIds(list, "bi mat")).toEqual([]);
  });
});
