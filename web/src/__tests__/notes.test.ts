import { describe, it, expect } from "vitest";
import type { Note, Track } from "@/types";

describe("Notes Feature (Facebook/Instagram Messenger Style)", () => {
  it("satisfies Note schema with text, privacy, and attached Apple Music track", () => {
    const track: Track = {
      id: "track_001",
      title: "Chạy ngay đi",
      artist: "Sơn Tùng M-TP",
      artworkUrl: "https://example.com/art.jpg",
      previewUrl: "https://audio-ssl.itunes.apple.com/preview.m4a",
      appleMusicUrl: "https://music.apple.com/vn/song/001",
      spotifyUrl: null,
    };

    const note: Note = {
      user: {
        id: "u_1",
        name: "Hoàng Yến",
        username: "hoangyen",
        avatarUrl: "https://example.com/yen.jpg",
      },
      text: "Đang nghe nhạc thư giãn cuối tuần 🎵",
      track,
      privacy: "friends",
      createdAt: "2026-11-03T10:00:00Z",
      expiresAt: "2026-11-04T10:00:00Z",
    };

    expect(note.user.name).toBe("Hoàng Yến");
    expect(note.text).toBe("Đang nghe nhạc thư giãn cuối tuần 🎵");
    expect(note.text.length).toBeLessThanOrEqual(60);
    expect(note.track?.title).toBe("Chạy ngay đi");
    expect(note.privacy).toBe("friends");
  });

  it("supports text-only notes without track", () => {
    const textNote: Note = {
      user: {
        id: "u_2",
        name: "Quốc Anh",
        username: "quocanh",
        avatarUrl: null,
      },
      text: "Cố lên sắp hoàn thành dự án rồi!",
      track: null,
      privacy: "public",
      createdAt: "2026-11-03T11:00:00Z",
      expiresAt: "2026-11-04T11:00:00Z",
    };

    expect(textNote.track).toBeNull();
    expect(textNote.text.length).toBeLessThanOrEqual(60);
    expect(textNote.privacy).toBe("public");
  });

  it("calculates 24-hour expiration correctly", () => {
    const createdTime = new Date("2026-11-03T08:00:00Z").getTime();
    const expiresTime = new Date("2026-11-04T08:00:00Z").getTime();
    const diffHours = (expiresTime - createdTime) / (1000 * 60 * 60);

    expect(diffHours).toBe(24);
  });
});
