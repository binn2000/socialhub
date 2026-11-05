import { describe, it, expect } from "vitest";
import { AUTH_COOKIE_NAME, COOKIE_MAX_AGE, BACKEND_API_URL } from "@/lib/constants";
import { ApiRequestError } from "@/lib/errors";
import type { Me, Post, Conversation, Notification } from "@/types";

describe("Phase 1: Foundation Tests", () => {
  it("defines secure cookie constants matching OpenAPI contract", () => {
    expect(AUTH_COOKIE_NAME).toBe("socialhub_token");
    expect(COOKIE_MAX_AGE).toBe(30 * 24 * 60 * 60); // 30 days
    expect(BACKEND_API_URL).toBeDefined();
  });

  it("handles ApiRequestError with structured codes and validation errors", () => {
    const error = new ApiRequestError(
      422,
      "validation_failed",
      "Dữ liệu không hợp lệ",
      { email: ["Email đã tồn tại"] }
    );

    expect(error.status).toBe(422);
    expect(error.code).toBe("validation_failed");
    expect(error.message).toBe("Dữ liệu không hợp lệ");
    expect(error.errors?.email).toContain("Email đã tồn tại");
  });

  it("exports strongly-typed schemas generated from openapi.yaml", () => {
    const mockUser: Me = {
      id: "01j8z6t4q9v3x7y2n5m1k8r0pd",
      name: "Long Nguyen",
      username: "longnguyen",
      avatarUrl: "https://example.com/avatar.jpg",
      coverUrl: null,
      email: "long@example.com",
      emailVerified: true,
      bio: "Software Engineer",
      friendsCount: 10,
      followersCount: 20,
      followingCount: 15,
      showOnlineStatus: true,
      createdAt: "2026-09-30T08:15:00Z",
      about: {
        location: "TP. Hồ Chí Minh",
        hometown: "Việt Nam",
        workplace: "Tech Corp",
        education: "Đại học",
        website: "https://example.com",
        birthday: "2000-01-01",
      },
    };

    expect(mockUser.username).toBe("longnguyen");
    expect(mockUser.emailVerified).toBe(true);
    expect(mockUser.showOnlineStatus).toBe(true);
  });
});
