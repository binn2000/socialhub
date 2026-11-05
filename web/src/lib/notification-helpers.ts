import {
  MessageCircle,
  Share2,
  UserCheck,
  ThumbsUp,
  UserPlus,
} from "lucide-react";
import type { NotificationType } from "@/types";
import { POST_REACTIONS, type PostReactionType } from "@/lib/post-constants";

export interface NotificationMeta {
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  iconColor: string;
  category: "interactions" | "friends";
  /** The emoji of a reaction notification; shown instead of the icon. */
  emoji?: string;
}

export function getNotificationMeta(
  type: NotificationType,
  reaction?: PostReactionType | null
): NotificationMeta {
  switch (type) {
    case "like": {
      const chosen = POST_REACTIONS.find((r) => r.type === reaction);
      // A plain Thích (or an unknown reaction) keeps the thumb; the others show their own emoji.
      if (chosen && chosen.type !== "like") {
        return {
          description: `đã bày tỏ cảm xúc ${chosen.emoji} về bài viết của bạn`,
          icon: ThumbsUp,
          emoji: chosen.emoji,
          iconColor: "bg-surface-muted dark:bg-surface-dark-muted",
          category: "interactions",
        };
      }
      return {
        description: "đã thích bài viết của bạn",
        icon: ThumbsUp,
        iconColor: "text-[#0866FF] bg-blue-50 dark:bg-blue-950/50",
        category: "interactions",
      };
    }
    case "comment":
      return {
        description: "đã bình luận trong bài viết của bạn",
        icon: MessageCircle,
        iconColor: "text-indigo-500 bg-indigo-50 dark:bg-indigo-950/50",
        category: "interactions",
      };
    case "share":
      return {
        description: "đã chia sẻ bài viết của bạn",
        icon: Share2,
        iconColor: "text-purple-500 bg-purple-50 dark:bg-purple-950/50",
        category: "interactions",
      };
    case "friend_accepted":
      return {
        description: "đã chấp nhận lời mời kết bạn của bạn",
        icon: UserCheck,
        iconColor: "text-emerald-500 bg-emerald-50 dark:bg-emerald-950/50",
        category: "friends",
      };
    case "follow":
      return {
        description: "đã bắt đầu theo dõi bạn",
        icon: UserPlus,
        iconColor: "text-emerald-500 bg-emerald-50 dark:bg-emerald-950/50",
        category: "friends",
      };
    case "friend_request":
    default:
      return {
        description: "đã gửi lời mời kết bạn",
        icon: UserPlus,
        iconColor: "text-emerald-500 bg-emerald-50 dark:bg-emerald-950/50",
        category: "friends",
      };
  }
}
