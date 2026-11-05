import { describe, it, expect } from "vitest";
import {
  STORY_BACKGROUNDS,
  STORY_PRIVACY_OPTIONS,
  getStoryGradient,
} from "@/lib/story-constants";
import type { Story, Track } from "@/types";

describe("Phase 6: Stories & Music (Media)", () => {
  describe("Story constants and gradients", () => {
    it("defines the 4 required background themes with Vietnamese labels", () => {
      expect(STORY_BACKGROUNDS).toHaveLength(4);

      const ids = STORY_BACKGROUNDS.map((b) => b.id);
      expect(ids).toContain("indigo");
      expect(ids).toContain("sunset");
      expect(ids).toContain("mint");
      expect(ids).toContain("berry");

      const indigo = STORY_BACKGROUNDS.find((b) => b.id === "indigo");
      expect(indigo?.label).toBe("Chàm");
      expect(indigo?.from).toBe("#5D6BFF");
      expect(indigo?.to).toBe("#9B8CFF");

      const sunset = STORY_BACKGROUNDS.find((b) => b.id === "sunset");
      expect(sunset?.label).toBe("Hoàng hôn");
    });

    it("generates correct CSS linear-gradient style", () => {
      const gradient = getStoryGradient("sunset");
      expect(gradient.background).toContain("linear-gradient");
      expect(gradient.background).toContain("#FF7043");
      expect(gradient.background).toContain("#FFC107");

      // Fallback test
      const fallback = getStoryGradient(null);
      expect(fallback.background).toContain("#5D6BFF");
    });

    it("defines the 3 privacy levels in Vietnamese", () => {
      expect(STORY_PRIVACY_OPTIONS).toHaveLength(3);
      expect(STORY_PRIVACY_OPTIONS.find((p) => p.value === "friends")?.label).toBe(
        "Bạn bè"
      );
      expect(STORY_PRIVACY_OPTIONS.find((p) => p.value === "public")?.label).toBe(
        "Công khai"
      );
      expect(STORY_PRIVACY_OPTIONS.find((p) => p.value === "only_me")?.label).toBe(
        "Chỉ mình tôi"
      );
    });
  });

  describe("Schema compatibility", () => {
    it("satisfies Track structure with Apple Music preview", () => {
      const track: Track = {
        id: "apple_track_123",
        title: "Nơi này có anh",
        artist: "Sơn Tùng M-TP",
        artworkUrl: "https://example.com/artwork.jpg",
        previewUrl: "https://audio-ssl.itunes.apple.com/preview.m4a",
        appleMusicUrl: "https://music.apple.com/vn/song/123",
        spotifyUrl: null,
      };

      expect(track.id).toBe("apple_track_123");
      expect(track.title).toBe("Nơi này có anh");
      expect(track.previewUrl).toContain("audio-ssl.itunes.apple.com");
    });

    it("satisfies Story structure with author, text, and music attachment", () => {
      const story: Story = {
        id: "story_999",
        author: {
          id: "u_abc",
          name: "Vũ Minh",
          username: "vuminh",
          avatarUrl: "https://example.com/avatar.jpg",
        },
        text: "Một buổi chiều hoàng hôn tuyệt đẹp!",
        imageUrl: "https://example.com/sunset.jpg",
        background: "sunset",
        createdAt: "2026-11-03T16:00:00Z",
        expiresAt: "2026-11-04T16:00:00Z",
        isViewed: false,
        privacy: "friends",
        track: {
          id: "apple_track_456",
          title: "Bầu trời mới",
          artist: "Da LAB",
          artworkUrl: null,
          previewUrl: "https://audio-ssl.itunes.apple.com/preview2.m4a",
          appleMusicUrl: null,
          spotifyUrl: null,
        },
      };

      expect(story.id).toBe("story_999");
      expect(story.author.name).toBe("Vũ Minh");
      expect(story.background).toBe("sunset");
      expect(story.track?.title).toBe("Bầu trời mới");
      expect(story.isViewed).toBe(false);
    });
  });
});
