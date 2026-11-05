import {
  Heart,
  MessageCircle,
  Share2,
  UserCheck,
  UserPlus,
} from "lucide-react";
import type { NotificationType } from "@/types";

export interface NotificationMeta {
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  iconColor: string;
  category: "interactions" | "friends";
}

export function getNotificationMeta(type: NotificationType): NotificationMeta {
  switch (type) {
    case "like":
      return {
        description: "đã thích bài viết của bạn",
        icon: Heart,
        iconColor: "text-rose-500 bg-rose-50 dark:bg-rose-950/50",
        category: "interactions",
      };
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
