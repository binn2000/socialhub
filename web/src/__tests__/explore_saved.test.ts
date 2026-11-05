import { describe, it, expect } from "vitest";
import type { Post } from "@/types";

describe("Phase 7: Explore, Saved Posts & Polishing", () => {
  describe("Explore filters and sorting logic", () => {
    const mockPosts: Post[] = [
      {
        id: "post_1",
        author: {
          id: "u1",
          name: "Tuấn Anh",
          username: "tuananh",
          avatarUrl: null,
        },
        content: "Trời hôm nay nhiều mây và đẹp",
        privacy: "public",
        feeling: "cheerful",
        imageUrl: null,
        imageUrls: [],
        video: null,
        likes: 15,
        comments: 2,
        shares: 1,
        isLiked: false,
        myReaction: null,
        reactionCounts: {},
        isSaved: false,
        isHidden: false,
        createdAt: "2026-11-03T10:00:00Z",
      },
      {
        id: "post_2",
        author: {
          id: "u2",
          name: "Thu Trang",
          username: "thutrang",
          avatarUrl: null,
        },
        content: "Khám phá vẻ đẹp biển đảo Phú Quốc",
        privacy: "public",
        feeling: null,
        imageUrl: "https://example.com/beach.jpg",
        imageUrls: ["https://example.com/beach.jpg"],
        video: null,
        likes: 142,
        comments: 28,
        shares: 12,
        isLiked: true,
        myReaction: null,
        reactionCounts: {},
        isSaved: true,
        isHidden: false,
        createdAt: "2026-11-03T09:00:00Z",
      },
      {
        id: "post_3",
        author: {
          id: "u3",
          name: "Văn Đức",
          username: "vanduc",
          avatarUrl: null,
        },
        content: "Video highlight trận bóng đá",
        privacy: "public",
        feeling: "excited",
        imageUrl: null,
        imageUrls: [],
        video: {
          url: "https://example.com/video.mp4",
          thumbnailUrl: "https://example.com/thumb.jpg",
          durationSeconds: 45,
          width: 1280,
          height: 720,
          status: "ready",
        },
        likes: 89,
        comments: 14,
        shares: 6,
        isLiked: false,
        myReaction: null,
        reactionCounts: {},
        isSaved: false,
        isHidden: false,
        createdAt: "2026-11-03T11:00:00Z",
      },
    ];

    it("filters posts by search query matching content or author name", () => {
      const q = "Phú Quốc";
      const matches = mockPosts.filter(
        (p) =>
          p.content.toLowerCase().includes(q.toLowerCase()) ||
          p.author.name.toLowerCase().includes(q.toLowerCase())
      );
      expect(matches).toHaveLength(1);
      expect(matches[0].id).toBe("post_2");
    });

    it("sorts posts by likes count descending for 'trending' filter", () => {
      const sorted = [...mockPosts].sort((a, b) => b.likes - a.likes);
      expect(sorted[0].id).toBe("post_2"); // 142 likes
      expect(sorted[1].id).toBe("post_3"); // 89 likes
      expect(sorted[2].id).toBe("post_1"); // 15 likes
    });

    it("filters posts for 'short_video' filter where video status is ready", () => {
      const videoPosts = mockPosts.filter((p) => p.video?.status === "ready");
      expect(videoPosts).toHaveLength(1);
      expect(videoPosts[0].id).toBe("post_3");
    });
  });

  describe("Saved posts management", () => {
    it("handles post removal from list when isSaved becomes false", () => {
      const savedList: Post[] = [
        {
          id: "p1",
          author: { id: "u1", name: "User 1", username: "u1", avatarUrl: null },
          content: "Bài 1",
          privacy: "public",
          feeling: null,
          imageUrl: null,
        imageUrls: [],
          video: null,
          likes: 5,
          comments: 1,
          shares: 0,
          isLiked: false,
          myReaction: null,
          reactionCounts: {},
          isSaved: true,
          isHidden: false,
          createdAt: "2026-11-03T08:00:00Z",
        },
        {
          id: "p2",
          author: { id: "u2", name: "User 2", username: "u2", avatarUrl: null },
          content: "Bài 2",
          privacy: "public",
          feeling: null,
          imageUrl: null,
        imageUrls: [],
          video: null,
          likes: 10,
          comments: 3,
          shares: 2,
          isLiked: false,
          myReaction: null,
          reactionCounts: {},
          isSaved: true,
          isHidden: false,
          createdAt: "2026-11-03T09:00:00Z",
        },
      ];

      // Simulate unsaving p1
      const updatedPost = { ...savedList[0], isSaved: false };
      const nextList = savedList.filter((p) => p.id !== updatedPost.id);

      expect(nextList).toHaveLength(1);
      expect(nextList[0].id).toBe("p2");
    });
  });
});
