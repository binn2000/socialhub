import { describe, it, expect } from "vitest";
import {
  MESSAGE_REACTIONS,
  parseReplyMessage,
  buildReplyPayload,
} from "../lib/chat-interactions";

describe("chat-interactions", () => {
  it("provides standard 6 reaction emojis", () => {
    expect(MESSAGE_REACTIONS).toEqual(["❤️", "👍", "😂", "😮", "😢", "😡"]);
  });

  it("builds and parses reply envelopes cleanly", () => {
    const quoted = {
      id: "msg_123",
      senderName: "Minh Ánh",
      text: "Hôm nay bạn rảnh không?",
    };
    const replyText = "Mình rảnh vào buổi chiều nhé!";

    const payload = buildReplyPayload(quoted, replyText);
    expect(payload).toContain("[reply:msg_123:Minh Ánh:Hôm nay bạn rảnh không?]");
    expect(payload).toContain("Mình rảnh vào buổi chiều nhé!");

    const parsed = parseReplyMessage(payload);
    expect(parsed.reply).not.toBeNull();
    expect(parsed.reply?.id).toBe("msg_123");
    expect(parsed.reply?.senderName).toBe("Minh Ánh");
    expect(parsed.reply?.text).toBe("Hôm nay bạn rảnh không?");
    expect(parsed.text).toBe(replyText);
  });

  it("handles normal text without reply envelope", () => {
    const parsed = parseReplyMessage("Xin chào bạn!");
    expect(parsed.reply).toBeNull();
    expect(parsed.text).toBe("Xin chào bạn!");
  });
});
