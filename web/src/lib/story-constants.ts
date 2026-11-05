import type { StoryBackground, Privacy } from "@/types";

export interface BackgroundOption {
  id: StoryBackground;
  label: string;
  from: string;
  to: string;
  gradientClass: string;
}

export const STORY_BACKGROUNDS: BackgroundOption[] = [
  {
    id: "indigo",
    label: "Chàm",
    from: "#5D6BFF",
    to: "#9B8CFF",
    gradientClass: "from-[#5D6BFF] to-[#9B8CFF]",
  },
  {
    id: "sunset",
    label: "Hoàng hôn",
    from: "#FF7043",
    to: "#FFC107",
    gradientClass: "from-[#FF7043] to-[#FFC107]",
  },
  {
    id: "mint",
    label: "Bạc hà",
    from: "#00B894",
    to: "#26C6DA",
    gradientClass: "from-[#00B894] to-[#26C6DA]",
  },
  {
    id: "berry",
    label: "Mâm xôi",
    from: "#E84393",
    to: "#6C5CE7",
    gradientClass: "from-[#E84393] to-[#6C5CE7]",
  },
];

export function getStoryGradient(bg: StoryBackground | string | null | undefined): {
  background: string;
} {
  const found = STORY_BACKGROUNDS.find((b) => b.id === bg) || STORY_BACKGROUNDS[0];
  return {
    background: `linear-gradient(135deg, ${found.from} 0%, ${found.to} 100%)`,
  };
}

export interface PrivacyOption {
  value: Privacy;
  label: string;
}

export const STORY_PRIVACY_OPTIONS: PrivacyOption[] = [
  { value: "friends", label: "Bạn bè" },
  { value: "public", label: "Công khai" },
  { value: "only_me", label: "Chỉ mình tôi" },
];
