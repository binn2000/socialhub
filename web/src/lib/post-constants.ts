import { Globe, Users, Lock, Smile, Sparkles, Heart } from "lucide-react";
import type { Privacy, Feeling } from "@/types";

export interface PrivacyOption {
  value: Privacy;
  label: string;
  description: string;
}

export const PRIVACY_OPTIONS: PrivacyOption[] = [
  {
    value: "public",
    label: "Công khai",
    description: "Mọi người trên SocialHub đều có thể nhìn thấy",
  },
  {
    value: "friends",
    label: "Bạn bè",
    description: "Chỉ bạn bè của bạn mới nhìn thấy",
  },
  {
    value: "only_me",
    label: "Chỉ mình tôi",
    description: "Chỉ bạn mới có thể nhìn thấy bài viết này",
  },
];

export interface FeelingOption {
  value: Feeling;
  label: string;
  emoji: string;
}

export type PostReactionType = "like" | "love" | "haha" | "wow" | "sad" | "angry";

export interface PostReactionOption {
  type: PostReactionType;
  label: string;
  emoji: string;
  color: string;
}

export const POST_REACTIONS: PostReactionOption[] = [
  { type: "like", label: "Thích", emoji: "👍", color: "text-[#0866FF]" },
  { type: "love", label: "Yêu thích", emoji: "❤️", color: "text-[#E41E3F]" },
  { type: "haha", label: "Haha", emoji: "😆", color: "text-[#F7B125]" },
  { type: "wow", label: "Wow", emoji: "😮", color: "text-[#F7B125]" },
  { type: "sad", label: "Buồn", emoji: "😢", color: "text-[#F7B125]" },
  { type: "angry", label: "Phẫn nộ", emoji: "😡", color: "text-[#E9710F]" },
];

export const FEELING_OPTIONS: FeelingOption[] = [
  { value: "cheerful", label: "Cảm thấy vui", emoji: "😊" },
  { value: "excited", label: "Hứng thú", emoji: "🤩" },
  { value: "happy", label: "Hạnh phúc", emoji: "🥰" },
];

export function getPrivacyLabel(privacy: Privacy): string {
  switch (privacy) {
    case "friends":
      return "Bạn bè";
    case "only_me":
      return "Chỉ mình tôi";
    case "public":
    default:
      return "Công khai";
  }
}

export function getFeelingLabel(feeling: Feeling | null | undefined): string | null {
  if (!feeling) return null;
  const match = FEELING_OPTIONS.find((f) => f.value === feeling);
  return match ? match.label : null;
}

export const REPORT_REASONS = [
  { value: "spam", label: "Spam hoặc quảng cáo" },
  { value: "harassment", label: "Quấy rối hoặc bắt nạt" },
  { value: "hate", label: "Ngôn từ thù ghét" },
  { value: "violence", label: "Bạo lực" },
  { value: "nudity", label: "Nội dung nhạy cảm" },
  { value: "false_info", label: "Thông tin sai sự thật" },
  { value: "other", label: "Lý do khác" },
] as const;

export type ReportReasonValue = (typeof REPORT_REASONS)[number]["value"];
