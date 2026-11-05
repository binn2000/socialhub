import { describe, it, expect } from "vitest";
import { timeAgo } from "@/lib/time-ago";
import {
  PRIVACY_OPTIONS,
  FEELING_OPTIONS,
  REPORT_REASONS,
  getPrivacyLabel,
  getFeelingLabel,
} from "@/lib/post-constants";
import type { Post, Comment, PostVideo } from "@/types";

describe("Phase 3: Feed and Posts", () => {
  describe("timeAgo formatter", () => {
    it("formats recent timestamps to Vietnamese relative text", () => {
      const now = new Date("2026-11-03T12:00:00Z");

      // Just now (< 1 min)
      const justNow = new Date("2026-11-03T11:59:45Z").toISOString();
      expect(timeAgo(justNow, now)).toBe("Vừa xong");

      // Minutes ago
      const tenMinsAgo = new Date("2026-11-03T11:50:00Z").toISOString();
      expect(timeAgo(tenMinsAgo, now)).toBe("10 phút trước");

      // Hours ago
      const threeHoursAgo = new Date("2026-11-03T09:00:00Z").toISOString();
      expect(timeAgo(threeHoursAgo, now)).toBe("3 giờ trước");

      // Yesterday
      const yesterday = new Date("2026-11-02T10:00:00Z").toISOString();
      expect(timeAgo(yesterday, now)).toBe("Hôm qua");

      // Days ago (< 7 days)
      const fourDaysAgo = new Date("2026-10-30T12:00:00Z").toISOString();
      expect(timeAgo(fourDaysAgo, now)).toBe("4 ngày trước");

      // Absolute date (>= 7 days)
      const twoWeeksAgo = new Date("2026-10-15T12:00:00Z").toISOString();
      expect(timeAgo(twoWeeksAgo, now)).toContain("15/10/2026");
    });
  });

  describe("Post constants and helpers", () => {
    it("has all 3 privacy options matching mobile app", () => {
      expect(PRIVACY_OPTIONS.length).toBe(3);
      expect(getPrivacyLabel("public")).toBe("Công khai");
      expect(getPrivacyLabel("friends")).toBe("Bạn bè");
      expect(getPrivacyLabel("only_me")).toBe("Chỉ mình tôi");
    });

    it("has all feelings matching OpenAPI and app", () => {
      expect(FEELING_OPTIONS.length).toBe(3);
      expect(getFeelingLabel("cheerful")).toBe("Cảm thấy vui");
      expect(getFeelingLabel("excited")).toBe("Hứng thú");
      expect(getFeelingLabel("happy")).toBe("Hạnh phúc");
      expect(getFeelingLabel(null)).toBeNull();
    });

    it("has 7 report reasons", () => {
      expect(REPORT_REASONS.length).toBe(7);
      const values = REPORT_REASONS.map((r) => r.value);
      expect(values).toContain("spam");
      expect(values).toContain("harassment");
      expect(values).toContain("hate");
      expect(values).toContain("violence");
      expect(values).toContain("nudity");
      expect(values).toContain("false_info");
      expect(values).toContain("other");
    });
  });

  describe("Schema type compatibility", () => {
    it("satisfies Post schema structure with multiple images", () => {
      const mockPost: Post = {
        id: "post_123",
        author: {
          id: "user_1",
          name: "Lê Anh Hùng",
          username: "hung_le",
          avatarUrl: null,
        },
        content: "Hôm nay thời tiết thật đẹp!",
        imageUrl: "https://example.com/photo1.jpg",
        imageUrls: [
          "https://example.com/photo1.jpg",
          "https://example.com/photo2.jpg",
        ],
        video: null,
        feeling: "cheerful",
        privacy: "public",
        createdAt: "2026-11-03T08:00:00Z",
        likes: 42,
        comments: 5,
        shares: 2,
        isLiked: true,
        myReaction: null,
        reactionCounts: {},
        isSaved: false,
        isHidden: false,
      };

      expect(mockPost.imageUrls.length).toBe(2);
      expect(mockPost.likes).toBe(42);
      expect(mockPost.privacy).toBe("public");
    });

    it("satisfies Post schema structure with video", () => {
      const mockVideo: PostVideo = {
        status: "ready",
        url: "https://example.com/video.mp4",
        thumbnailUrl: "https://example.com/thumb.jpg",
        durationSeconds: 45,
        width: 1280,
        height: 720,
      };

      const mockPost: Post = {
        id: "post_456",
        author: {
          id: "user_2",
          name: "Nguyễn Văn A",
          username: "nguyenvana",
          avatarUrl: null,
        },
        content: "Video kỷ niệm chuyến đi",
        imageUrl: null,
        imageUrls: [],
        video: mockVideo,
        feeling: null,
        privacy: "friends",
        createdAt: "2026-11-03T07:00:00Z",
        likes: 12,
        comments: 1,
        shares: 0,
        isLiked: false,
        myReaction: null,
        reactionCounts: {},
        isSaved: true,
        isHidden: false,
      };

      expect(mockPost.video?.status).toBe("ready");
      expect(mockPost.video?.durationSeconds).toBe(45);
    });

    it("satisfies Comment schema structure", () => {
      const mockComment: Comment = {
        id: "comment_789",
        postId: "post_123",
        author: {
          id: "user_3",
          name: "Trần Thị B",
          username: "tranthib",
          avatarUrl: null,
        },
        content: "Bài viết tuyệt vời quá!",
        createdAt: "2026-11-03T08:30:00Z",
      };

      expect(mockComment.content).toBe("Bài viết tuyệt vời quá!");
      expect(mockComment.postId).toBe("post_123");
    });
  });
});
