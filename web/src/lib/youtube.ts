/** One result of `GET /videos/search`. */
export interface YoutubeVideo {
  id: string;
  title: string;
  channelTitle: string;
  thumbnailUrl?: string | null;
  publishedAt?: string | null;
  durationSeconds?: number | null;
}

/** A YouTube video id is exactly 11 URL-safe characters. */
export function isYoutubeId(id: string): boolean {
  return /^[A-Za-z0-9_-]{11}$/.test(id);
}

/** The embedded player (privacy-enhanced domain). Returns null for anything that is not a real id. */
export function youtubeEmbedUrl(id: string, autoplay = true): string | null {
  if (!isYoutubeId(id)) return null;
  return `https://www.youtube-nocookie.com/embed/${id}?rel=0&modestbranding=1${autoplay ? "&autoplay=1" : ""}`;
}

/** Standard YouTube watch URL for sharing or opening in a new tab. */
export function youtubeWatchUrl(id: string): string {
  return `https://www.youtube.com/watch?v=${id}`;
}

export interface YoutubeCategory {
  id: string;
  label: string;
  query: string;
}

export const YOUTUBE_CATEGORIES: YoutubeCategory[] = [
  { id: "all", label: "🔥 Nổi bật", query: "" },
  { id: "music", label: "🎵 Âm nhạc", query: "nhạc việt mới nhất" },
  { id: "gaming", label: "🎮 Gaming", query: "gaming việt nam" },
  { id: "movies", label: "🎬 Phim & Trailer", query: "review phim trailer" },
  { id: "sports", label: "⚽ Thể thao", query: "bóng đá thể thao" },
  { id: "tech", label: "💻 Công nghệ", query: "đánh giá công nghệ" },
  { id: "food", label: "🍜 Ẩm thực", query: "ẩm thực đường phố" },
  { id: "comedy", label: "😂 Giải trí", query: "hài kịch giải trí" },
  { id: "study", label: "📚 Học tập", query: "kiến thức thú vị" },
];

/** 3723 -> "1:02:03", 75 -> "1:15". */
export function formatDuration(totalSeconds?: number | null): string {
  if (totalSeconds === null || totalSeconds === undefined || totalSeconds < 0) return "";
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = Math.floor(totalSeconds % 60);
  const two = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${two(m)}:${two(s)}` : `${m}:${two(s)}`;
}
