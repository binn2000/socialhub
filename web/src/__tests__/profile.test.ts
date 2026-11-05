import { describe, it, expect } from "vitest";
import type {
  UserProfile,
  FriendRequest,
  UserListItem,
  Photo,
  FriendshipStatus,
} from "@/types";

describe("Phase 4: Profile and Friends", () => {
  describe("Schema type compatibility", () => {
    it("satisfies UserProfile structure", () => {
      const mockProfile: UserProfile = {
        id: "user_100",
        name: "Nguyễn Minh Anh",
        username: "minhanh",
        avatarUrl: "https://example.com/avatar.jpg",
        coverUrl: "https://example.com/cover.jpg",
        bio: "Nhiếp ảnh gia tự do & nhà phát triển",
        hasStories: true,
        note: null,
        followersCount: 142,
        followingCount: 88,
        friendsCount: 56,
        mutualFriendsCount: 12,
        isFollowing: true,
        followsYou: false,
        isOnline: true,
        lastSeenAt: "2026-11-03T10:00:00Z",
        isBlocked: false,
        about: {
          location: "Hà Nội",
          hometown: "Nghệ An",
          workplace: "Studio Ảnh",
          education: "Đại học Sân khấu Điện ảnh",
          website: "https://minhanh.example",
          birthday: "1998-08-20",
        },
        createdAt: "2026-01-15T08:00:00Z",
        friendship: {
          status: "friends",
          requestId: null,
        },
      };

      expect(mockProfile.name).toBe("Nguyễn Minh Anh");
      expect(mockProfile.friendship.status).toBe("friends");
      expect(mockProfile.followersCount).toBe(142);
      expect(mockProfile.about.location).toBe("Hà Nội");
    });

    it("satisfies FriendRequest structure", () => {
      const mockRequest: FriendRequest = {
        id: "req_1",
        sender: {
          id: "user_200",
          name: "Lê Văn Tùng",
          username: "tung_le",
          avatarUrl: null,
        },
        receiver: {
          id: "user_me",
          name: "Tôi",
          username: "me",
          avatarUrl: null,
        },
        createdAt: "2026-11-03T09:00:00Z",
      };

      expect(mockRequest.id).toBe("req_1");
      expect(mockRequest.sender.name).toBe("Lê Văn Tùng");
    });

    it("satisfies UserListItem structure", () => {
      const mockListItem: UserListItem = {
        id: "user_300",
        name: "Hoàng Mai Chi",
        username: "maichi",
        avatarUrl: null,
        isFollowing: false,
        isOnline: false,
        lastSeenAt: "2026-11-03T08:00:00Z",
        mutualFriendsCount: 5,
        friendship: {
          status: "none",
          requestId: null,
        },
      };

      expect(mockListItem.mutualFriendsCount).toBe(5);
      expect(mockListItem.friendship.status).toBe("none");
    });

    it("satisfies Photo structure for Photos tab", () => {
      const mockPhoto: Photo = {
        postId: "post_999",
        imageUrl: "https://example.com/gallery_1.jpg",
        createdAt: "2026-11-03T08:00:00Z",
      };

      expect(mockPhoto.postId).toBe("post_999");
      expect(mockPhoto.imageUrl).toBe("https://example.com/gallery_1.jpg");
    });
  });

  describe("Friendship statuses", () => {
    it("handles all friendship states", () => {
      const statuses: FriendshipStatus[] = [
        "none",
        "pending_outgoing",
        "pending_incoming",
        "friends",
        "self",
      ];

      expect(statuses.length).toBe(5);
      expect(statuses).toContain("pending_outgoing");
      expect(statuses).toContain("pending_incoming");
      expect(statuses).toContain("friends");
    });
  });
});
