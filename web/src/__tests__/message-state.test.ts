import { describe, expect, it } from "vitest";
import { applyStates, withMyReaction } from "@/lib/message-state";
import type { Message } from "@/types";

const base = (over: Partial<Message> = {}): Message => ({
  id: "m1",
  conversationId: "c1",
  senderId: "u1",
  text: "Xin chào",
  isRecalled: false,
  reactions: {},
  myReaction: null,
  attachments: [],
  createdAt: "2026-11-05T05:00:00Z",
  ...over,
});

describe("withMyReaction", () => {
  it("adds, changes and removes my reaction and keeps the counts right", () => {
    const loved = withMyReaction(base(), "😂");
    expect(loved.reactions).toEqual({ "😂": 1 });
    expect(loved.myReaction).toBe("😂");

    const changed = withMyReaction(base({ reactions: { "😂": 2 }, myReaction: "😂" }), "😡");
    expect(changed.reactions).toEqual({ "😂": 1, "😡": 1 });

    const removed = withMyReaction(base({ reactions: { "😂": 1 }, myReaction: "😂" }), null);
    expect(removed.reactions).toEqual({});
    expect(removed.myReaction).toBeNull();
  });
});

describe("applyStates", () => {
  it("takes reactions and recalls from the server", () => {
    const list = [base(), base({ id: "m2", text: "Tin hai" })];
    const next = applyStates(list, {
      m1: { reactions: { "👍": 1 }, myReaction: "👍", isRecalled: false },
      m2: { reactions: {}, myReaction: null, isRecalled: true },
    });
    expect(next[0].reactions).toEqual({ "👍": 1 });
    expect(next[1].isRecalled).toBe(true);
    expect(next[1].text).toBe("");
  });

  it("returns the same list when nothing changed", () => {
    const list = [base()];
    expect(applyStates(list, { m1: { reactions: {}, myReaction: null, isRecalled: false } })).toBe(list);
    expect(applyStates(list, undefined)).toBe(list);
  });
});
