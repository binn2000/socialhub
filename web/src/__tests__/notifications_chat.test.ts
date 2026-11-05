import { describe, it, expect } from "vitest";
import { getNotificationMeta } from "@/lib/notification-helpers";
import { timeAgo } from "@/lib/time-ago";
import {
  isStickerMessage,
  parseStickerMessage,
  formatMessagePreview,
  EMOJI_CATEGORIES,
  STICKER_PACKS,
} from "@/lib/chat-emojis-stickers";
import type { Notification, Conversation, Message } from "@/types";

describe("Phase 5: Notifications & Chat (Messenger)", () => {
  describe("Notification helpers", () => {
    it("shows the reaction in a like notification", () => {
      const love = getNotificationMeta("like", "love");
      expect(love.description).toBe("đã bày tỏ cảm xúc ❤️ về bài viết của bạn");
      expect(love.emoji).toBe("❤️");
      expect(getNotificationMeta("like", "haha").emoji).toBe("😆");
      // A plain like keeps its text and has no emoji.
      expect(getNotificationMeta("like", "like").description).toBe("đã thích bài viết của bạn");
      expect(getNotificationMeta("like", null).emoji).toBeUndefined();
      expect(getNotificationMeta("comment", "love").emoji).toBeUndefined();
    });

    it("returns correct meta for 'like' notification", () => {
      const meta = getNotificationMeta("like");
      expect(meta.description).toBe("đã thích bài viết của bạn");
      expect(meta.category).toBe("interactions");
      expect(meta.iconColor).toContain("0866FF"); // the thumb of a plain Thích
    });

    it("returns correct meta for 'comment' notification", () => {
      const meta = getNotificationMeta("comment");
      expect(meta.description).toBe("đã bình luận trong bài viết của bạn");
      expect(meta.category).toBe("interactions");
      expect(meta.iconColor).toContain("indigo");
    });

    it("returns correct meta for 'share' notification", () => {
      const meta = getNotificationMeta("share");
      expect(meta.description).toBe("đã chia sẻ bài viết của bạn");
      expect(meta.category).toBe("interactions");
    });

    it("returns correct meta for friend and follow notifications", () => {
      const followMeta = getNotificationMeta("follow");
      expect(followMeta.description).toBe("đã bắt đầu theo dõi bạn");
      expect(followMeta.category).toBe("friends");

      const acceptMeta = getNotificationMeta("friend_accepted");
      expect(acceptMeta.description).toBe("đã chấp nhận lời mời kết bạn của bạn");
      expect(acceptMeta.category).toBe("friends");

      const requestMeta = getNotificationMeta("friend_request");
      expect(requestMeta.description).toBe("đã gửi lời mời kết bạn");
      expect(requestMeta.category).toBe("friends");
    });
  });

  describe("Conversation and Message schemas", () => {
    it("satisfies Conversation structure with participant and lastMessage", () => {
      const conv: Conversation = {
        id: "conv_123",
        participant: {
          id: "user_456",
          name: "Phạm Thảo",
          username: "phamthao",
          avatarUrl: "https://example.com/avatar.jpg",
          isOnline: true,
          lastSeenAt: "2026-11-03T11:00:00Z",
        },
        lastMessage: {
          id: "msg_789",
          conversationId: "conv_123",
          senderId: "user_456",
          text: "Hẹn gặp bạn chiều nay nhé!",
          attachments: [],
          createdAt: "2026-11-03T11:05:00Z",
        },
        unreadCount: 2,
        updatedAt: "2026-11-03T11:05:00Z",
      };

      expect(conv.id).toBe("conv_123");
      expect(conv.participant.name).toBe("Phạm Thảo");
      expect(conv.participant.isOnline).toBe(true);
      expect(conv.unreadCount).toBe(2);
      expect(conv.lastMessage?.text).toBe("Hẹn gặp bạn chiều nay nhé!");
    });

    it("satisfies Message structure with multiple file/image attachments", () => {
      const msg: Message = {
        id: "msg_999",
        conversationId: "conv_123",
        senderId: "user_my_id",
        text: "Gửi bạn tài liệu và ảnh thiết kế",
        attachments: [
          {
            id: 1,
            type: "image",
            url: "https://example.com/photo.jpg",
            name: "design.jpg",
            sizeBytes: 2048576,
            width: 1200,
            height: 800,
            mimeType: "image/jpeg",
          },
          {
            id: 2,
            type: "file",
            url: "https://example.com/spec.pdf",
            name: "spec.pdf",
            sizeBytes: 5242880,
            width: null,
            height: null,
            mimeType: "application/pdf",
          },
        ],
        createdAt: "2026-11-03T11:10:00Z",
      };

      expect(msg.attachments).toHaveLength(2);
      expect(msg.attachments[0].type).toBe("image");
      expect(msg.attachments[1].type).toBe("file");
      expect(msg.attachments[1].sizeBytes).toBe(5242880);
    });
  });

  describe("Time ago formatting for chat/notifications", () => {
    it("formats timestamps relative to current time correctly in Vietnamese", () => {
      const now = new Date();
      const fiveMinsAgo = new Date(now.getTime() - 5 * 60 * 1000).toISOString();
      expect(timeAgo(fiveMinsAgo)).toBe("5 phút trước");

      const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString();
      expect(timeAgo(twoHoursAgo)).toBe("2 giờ trước");
    });
  });

  describe("Chat Emojis and Stickers", () => {
    it("has populated emoji categories and sticker packs", () => {
      expect(EMOJI_CATEGORIES.length).toBeGreaterThanOrEqual(5);
      expect(STICKER_PACKS.length).toBeGreaterThanOrEqual(4);
      expect(STICKER_PACKS[0].stickers.length).toBeGreaterThanOrEqual(8);
    });

    it("detects and parses sticker messages correctly", () => {
      const stickerPayload = "[sticker:3d_haha:https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/512.webp]";
      expect(isStickerMessage(stickerPayload)).toBe(true);
      expect(isStickerMessage("Tin nhắn thông thường")).toBe(false);
      expect(isStickerMessage(null)).toBe(false);

      const parsed = parseStickerMessage(stickerPayload);
      expect(parsed).not.toBeNull();
      expect(parsed?.id).toBe("3d_haha");
      expect(parsed?.url).toContain("1f602/512.webp");
    });

    it("takes the picture from the catalogue, never from the message", () => {
      const parsed = parseStickerMessage("[sticker:3d_haha:https://evil.example/x.png]");
      expect(parsed?.url).toContain("1f602/512.webp");
      const unknown = parseStickerMessage("[sticker:nope:https://evil.example/x.png]");
      expect(unknown?.url).toBeNull();
    });

    it("has unique sticker ids with Noto emoji addresses", () => {
      const all = STICKER_PACKS.flatMap((pack) => pack.stickers);
      expect(new Set(all.map((s) => s.id)).size).toBe(all.length);
      for (const s of all) {
        expect(s.url.startsWith("https://fonts.gstatic.com/s/e/notoemoji/")).toBe(true);
      }
    });

    it("formats preview for conversation snippets correctly", () => {
      const stickerPayload = "[sticker:3d_love:https://example.com/sticker.webp]";
      expect(formatMessagePreview(stickerPayload)).toBe("[Nhãn dán]");
      expect(formatMessagePreview("Chào bạn!")).toBe("Chào bạn!");
      expect(formatMessagePreview(null)).toBe("");
    });
  });
});
