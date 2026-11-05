"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Search,
  X,
  Loader2,
  AlertCircle,
  PlayCircle,
  Share2,
  Link2,
  Check,
  PictureInPicture2,
  Maximize2,
  SkipForward,
  SkipBack,
  ExternalLink,
  Flame,
  Send,
  ListVideo,
  Sparkles,
} from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import { timeAgo } from "@/lib/time-ago";
import {
  formatDuration,
  youtubeEmbedUrl,
  youtubeWatchUrl,
  YOUTUBE_CATEGORIES,
  type YoutubeVideo,
} from "@/lib/youtube";
import { UserAvatar } from "@/components/ui/UserAvatar";
import type { Conversation } from "@/types";

interface VideoPage {
  data: YoutubeVideo[];
  meta: { nextCursor: string | null; hasMore: boolean };
}

function channelGradient(name: string): string {
  const gradients = [
    "from-rose-500 to-orange-500",
    "from-violet-600 to-indigo-500",
    "from-emerald-500 to-teal-600",
    "from-sky-500 to-blue-600",
    "from-amber-500 to-pink-500",
    "from-fuchsia-500 to-purple-600",
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) | 0;
  }
  return gradients[Math.abs(hash) % gradients.length];
}

function ChannelBadge({ name, size = "sm" }: { name: string; size?: "sm" | "md" }) {
  const initial = (name.trim()[0] || "Y").toUpperCase();
  const dim = size === "md" ? "w-9 h-9 text-sm" : "w-7 h-7 text-xs";
  return (
    <div
      className={`${dim} rounded-full bg-gradient-to-br ${channelGradient(
        name
      )} text-white font-bold flex items-center justify-center shrink-0 shadow-sm`}
      aria-hidden="true"
    >
      {initial}
    </div>
  );
}

/** The "Video" tab: search YouTube through our server and watch with YouTube's embedded player. */
export function YoutubeVideos() {
  const [query, setQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState<string>("all");
  const [videos, setVideos] = useState<YoutubeVideo[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Player states
  const [playing, setPlaying] = useState<YoutubeVideo | null>(null);
  // The "Up Next" list is a copy taken when a video is opened: searching or changing topic while the
  // mini-player keeps playing replaces `videos`, and the current video would vanish from its own queue.
  const [queue, setQueue] = useState<YoutubeVideo[]>([]);
  const [isMiniPlayer, setIsMiniPlayer] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Share to chat modal state
  const [sharingVideo, setSharingVideo] = useState<YoutubeVideo | null>(null);

  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Answers can arrive out of order while typing; only the newest request may update the list.
  const requestId = useRef(0);

  // Horizontal category drag-to-scroll refs
  const chipsRef = useRef<HTMLDivElement | null>(null);
  const isDraggingChips = useRef(false);
  const dragStartX = useRef(0);
  const dragScrollLeft = useRef(0);
  const hasDraggedChips = useRef(false);

  const effectiveSearchQuery = useMemo(() => {
    if (query.trim()) return query.trim();
    const cat = YOUTUBE_CATEGORIES.find((c) => c.id === activeCategory);
    return cat ? cat.query : "";
  }, [query, activeCategory]);

  const load = useCallback(async (text: string, cursor?: string | null) => {
    const id = ++requestId.current;
    if (cursor) setLoadingMore(true);
    else setLoading(true);
    setError(null);
    try {
      const res = await clientFetch<VideoPage>("videos/search", {
        params: { q: text.trim() || undefined, cursor: cursor || undefined },
      });
      if (id !== requestId.current) return;
      setVideos((prev) => (cursor ? [...prev, ...res.data] : res.data));
      setNextCursor(res.meta.nextCursor);
    } catch (e) {
      if (id !== requestId.current) return;
      setError(
        e instanceof ApiRequestError && e.code === "video_unavailable"
          ? "Hiện chưa tìm được video (YouTube chưa sẵn sàng hoặc đã hết hạn mức hôm nay). Thử lại sau nhé."
          : "Không tải được video, vui lòng thử lại."
      );
    } finally {
      if (id === requestId.current) {
        setLoading(false);
        setLoadingMore(false);
      }
    }
  }, []);

  useEffect(() => {
    void load("");
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [load]);

  // Esc closes the full modal player (or share modal first).
  useEffect(() => {
    if (!playing && !sharingVideo) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (sharingVideo) {
          setSharingVideo(null);
        } else if (!isMiniPlayer) {
          setPlaying(null);
        }
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [playing, isMiniPlayer, sharingVideo]);

  const onChange = (text: string) => {
    setQuery(text);
    if (text.trim()) {
      setActiveCategory("all");
    }
    if (timer.current) clearTimeout(timer.current);
    // 600 ms: a YouTube search costs 100 of the 10,000 free daily units.
    timer.current = setTimeout(() => void load(text), 600);
  };

  const handleSelectCategory = (catId: string, catQuery: string) => {
    if (hasDraggedChips.current) return;
    setActiveCategory(catId);
    setQuery("");
    if (timer.current) clearTimeout(timer.current);
    void load(catQuery);
  };

  const handleOpenVideo = (video: YoutubeVideo) => {
    setQueue(videos);
    setPlaying(video);
    setIsMiniPlayer(false);
  };

  const handleCopyLink = async (video: YoutubeVideo, e?: React.MouseEvent) => {
    e?.stopPropagation();
    const url = youtubeWatchUrl(video.id);
    try {
      await navigator.clipboard.writeText(url);
      setCopiedId(video.id);
      setTimeout(() => {
        setCopiedId((prev) => (prev === video.id ? null : prev));
      }, 2000);
    } catch {
      // Fallback ignored
    }
  };

  const currentIndex = useMemo(
    () => (playing ? queue.findIndex((v) => v.id === playing.id) : -1),
    [playing, queue]
  );

  const hasPrev = currentIndex > 0;
  const hasNext = currentIndex >= 0 && currentIndex < queue.length - 1;

  const playPrev = () => {
    if (hasPrev) setPlaying(queue[currentIndex - 1]);
  };

  const playNext = () => {
    if (hasNext) setPlaying(queue[currentIndex + 1]);
  };

  const embed = playing ? youtubeEmbedUrl(playing.id) : null;
  const isDefaultTrending = !query.trim() && activeCategory === "all";
  const heroVideo = isDefaultTrending && videos.length > 0 ? videos[0] : null;
  const gridVideos = heroVideo ? videos.slice(1) : videos;

  return (
    <div>
      {/* Search Input */}
      <div className="relative mb-3.5">
        <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-appText-secondary" />
        <input
          type="text"
          value={query}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Tìm video, bài hát, kênh trên YouTube..."
          className="w-full pl-11 pr-10 py-3 rounded-2xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark focus:border-brand focus:ring-2 focus:ring-brand/20 text-sm text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none transition shadow-sm"
        />
        {query && (
          <button
            type="button"
            onClick={() => onChange("")}
            className="absolute right-3.5 top-1/2 -translate-y-1/2 p-1 text-appText-secondary hover:text-appText-primary rounded-full transition"
            title="Xóa tìm kiếm"
          >
            <X size={16} />
          </button>
        )}
      </div>

      {/* Category Filter Chips (Horizontal scrollable + mouse drag) */}
      <div
        ref={chipsRef}
        onWheel={(e) => {
          if (chipsRef.current && e.deltaY !== 0) {
            chipsRef.current.scrollLeft += e.deltaY;
          }
        }}
        onMouseDown={(e) => {
          if (!chipsRef.current) return;
          isDraggingChips.current = true;
          hasDraggedChips.current = false;
          dragStartX.current = e.pageX - chipsRef.current.offsetLeft;
          dragScrollLeft.current = chipsRef.current.scrollLeft;
        }}
        onMouseMove={(e) => {
          if (!isDraggingChips.current || !chipsRef.current) return;
          const x = e.pageX - chipsRef.current.offsetLeft;
          const walk = x - dragStartX.current;
          if (Math.abs(walk) > 5) {
            hasDraggedChips.current = true;
          }
          chipsRef.current.scrollLeft = dragScrollLeft.current - walk;
        }}
        onMouseUp={() => {
          isDraggingChips.current = false;
        }}
        onMouseLeave={() => {
          isDraggingChips.current = false;
        }}
        className="flex items-center gap-2 overflow-x-auto no-scrollbar pb-2 mb-4 select-none cursor-grab active:cursor-grabbing"
      >
        {YOUTUBE_CATEGORIES.map((cat) => {
          const isSelected = !query.trim() && activeCategory === cat.id;
          return (
            <button
              key={cat.id}
              type="button"
              onClick={() => handleSelectCategory(cat.id, cat.query)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all shrink-0 ${
                isSelected
                  ? "bg-brand text-white shadow-sm scale-[1.02]"
                  : "bg-surface-light dark:bg-surface-dark text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary border border-appBorder-light dark:border-appBorder-dark hover:border-brand/40"
              }`}
            >
              {cat.label}
            </button>
          );
        })}
      </div>

      {!query.trim() && !loading && !error && (
        <div className="flex items-center justify-between mb-3">
          <p className="text-xs font-semibold text-appText-secondary flex items-center gap-1.5">
            <Flame size={14} className="text-orange-500" />
            <span>
              {activeCategory === "all"
                ? "Video đang thịnh hành"
                : `Chủ đề: ${YOUTUBE_CATEGORIES.find((c) => c.id === activeCategory)?.label ?? ""}`}
            </span>
          </p>
          {playing && isMiniPlayer && (
            <button
              type="button"
              onClick={() => setIsMiniPlayer(false)}
              className="text-xs font-semibold text-brand hover:underline flex items-center gap-1"
            >
              <Maximize2 size={12} />
              <span>Mở rộng trình phát</span>
            </button>
          )}
        </div>
      )}

      {loading ? (
        <div className="py-16 flex flex-col items-center">
          <Loader2 className="w-8 h-8 text-brand animate-spin mb-3" />
          <p className="text-xs text-appText-secondary">Đang tải video...</p>
        </div>
      ) : error ? (
        <div className="py-12 text-center bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark p-6">
          <AlertCircle size={36} className="mx-auto mb-3 text-red-500 opacity-80" />
          <p className="text-xs text-appText-secondary max-w-sm mx-auto mb-3">{error}</p>
          <button
            type="button"
            onClick={() => void load(effectiveSearchQuery)}
            className="px-4 py-2 rounded-full bg-brand text-white text-xs font-semibold hover:opacity-90"
          >
            Thử lại
          </button>
        </div>
      ) : videos.length === 0 ? (
        <div className="py-16 text-center text-xs text-appText-secondary">
          Không tìm thấy video nào cho &ldquo;{query || effectiveSearchQuery}&rdquo;.
        </div>
      ) : (
        <>
          {/* Featured #1 Trending Hero Banner */}
          {heroVideo && (
            <div
              onClick={() => handleOpenVideo(heroVideo)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  handleOpenVideo(heroVideo);
                }
              }}
              className="group relative mb-5 rounded-2xl overflow-hidden bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark shadow-sm hover:shadow-card-hover transition cursor-pointer"
            >
              <div className="grid grid-cols-1 md:grid-cols-12">
                <div className="relative aspect-video md:col-span-7 bg-black/20 overflow-hidden">
                  {heroVideo.thumbnailUrl && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={heroVideo.thumbnailUrl}
                      alt=""
                      className="w-full h-full object-cover group-hover:scale-105 transition duration-500"
                    />
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/15 to-transparent flex items-center justify-center">
                    <div className="w-14 h-14 rounded-full bg-brand/90 text-white flex items-center justify-center shadow-lg group-hover:scale-110 transition">
                      <PlayCircle className="w-8 h-8" />
                    </div>
                  </div>
                  <div className="absolute top-3 left-3 inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-gradient-to-r from-orange-500 to-rose-500 text-white text-[11px] font-bold shadow">
                    <Sparkles size={12} />
                    <span>#1 Thịnh hành</span>
                  </div>
                  {formatDuration(heroVideo.durationSeconds) && (
                    <span className="absolute bottom-3 right-3 px-2 py-0.5 rounded-md bg-black/80 text-white text-xs font-semibold">
                      {formatDuration(heroVideo.durationSeconds)}
                    </span>
                  )}
                </div>

                <div className="p-4 sm:p-5 md:col-span-5 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center gap-2.5 mb-2.5">
                      <ChannelBadge name={heroVideo.channelTitle} size="md" />
                      <div className="min-w-0">
                        <p className="text-xs font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                          {heroVideo.channelTitle}
                        </p>
                        {heroVideo.publishedAt && (
                          <p className="text-[11px] text-appText-secondary">
                            {timeAgo(heroVideo.publishedAt)}
                          </p>
                        )}
                      </div>
                    </div>
                    <h3 className="text-base sm:text-lg font-bold text-appText-primary dark:text-appText-dark-primary line-clamp-3 group-hover:text-brand transition">
                      {heroVideo.title}
                    </h3>
                  </div>

                  <div className="flex items-center gap-2 mt-4 pt-3 border-t border-appBorder-light dark:border-appBorder-dark">
                    <span className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-brand text-white text-xs font-semibold">
                      <PlayCircle size={15} />
                      <span>Xem ngay</span>
                    </span>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSharingVideo(heroVideo);
                      }}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition"
                      title="Gửi video này cho bạn bè"
                    >
                      <Share2 size={14} />
                      <span>Gửi bạn bè</span>
                    </button>
                    <button
                      type="button"
                      onClick={(e) => void handleCopyLink(heroVideo, e)}
                      className="p-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-appText-secondary transition ml-auto"
                      title="Sao chép liên kết video"
                    >
                      {copiedId === heroVideo.id ? (
                        <Check size={15} className="text-emerald-500" />
                      ) : (
                        <Link2 size={15} />
                      )}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Video Cards Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {gridVideos.map((v) => {
              const isCurrentPlaying = playing?.id === v.id;
              return (
                <div
                  key={v.id}
                  onClick={() => handleOpenVideo(v)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      handleOpenVideo(v);
                    }
                  }}
                  className={`group text-left bg-surface-light dark:bg-surface-dark rounded-2xl border overflow-hidden hover:shadow-card-hover transition cursor-pointer flex flex-col ${
                    isCurrentPlaying
                      ? "border-brand ring-2 ring-brand/20"
                      : "border-appBorder-light dark:border-appBorder-dark"
                  }`}
                >
                  <div className="relative aspect-video bg-black/10 overflow-hidden">
                    {v.thumbnailUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={v.thumbnailUrl}
                        alt=""
                        className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                        loading="lazy"
                      />
                    )}
                    <span className="absolute inset-0 flex items-center justify-center bg-black/0 group-hover:bg-black/30 transition">
                      <PlayCircle className="w-12 h-12 text-white opacity-0 group-hover:opacity-100 drop-shadow-lg scale-90 group-hover:scale-100 transition" />
                    </span>
                    {isCurrentPlaying && (
                      <span className="absolute top-2 left-2 px-2 py-0.5 rounded-full bg-brand text-white text-[10px] font-bold shadow">
                        Đang phát
                      </span>
                    )}
                    {formatDuration(v.durationSeconds) && (
                      <span className="absolute bottom-2 right-2 px-1.5 py-0.5 rounded bg-black/80 text-white text-[11px] font-semibold">
                        {formatDuration(v.durationSeconds)}
                      </span>
                    )}
                  </div>

                  <div className="p-3.5 flex items-start gap-3 flex-1">
                    <ChannelBadge name={v.channelTitle} />
                    <div className="min-w-0 flex-1">
                      <h3 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary line-clamp-2 group-hover:text-brand transition">
                        {v.title}
                      </h3>
                      <p className="text-xs text-appText-secondary mt-1 truncate">
                        {v.channelTitle}
                        {v.publishedAt ? ` · ${timeAgo(v.publishedAt)}` : ""}
                      </p>
                    </div>
                    <div className="flex items-center gap-1 shrink-0 opacity-80 group-hover:opacity-100">
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setSharingVideo(v);
                        }}
                        className="p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-brand transition"
                        title="Gửi cho bạn bè"
                      >
                        <Share2 size={14} />
                      </button>
                      <button
                        type="button"
                        onClick={(e) => void handleCopyLink(v, e)}
                        className="p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-brand transition"
                        title="Sao chép liên kết"
                      >
                        {copiedId === v.id ? (
                          <Check size={14} className="text-emerald-500" />
                        ) : (
                          <Link2 size={14} />
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {nextCursor && (
            <div className="pt-5 text-center">
              <button
                type="button"
                onClick={() => void load(effectiveSearchQuery, nextCursor)}
                disabled={loadingMore}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition active:scale-95 disabled:opacity-50"
              >
                {loadingMore && <Loader2 size={14} className="animate-spin" />}
                <span>Tải thêm video</span>
              </button>
            </div>
          )}
        </>
      )}

      {/* 1. Cinema Mode & Up Next Modal Player */}
      {playing && embed && !isMiniPlayer && (
        <div
          className="fixed inset-0 z-[60] bg-black/85 backdrop-blur-sm flex items-center justify-center p-2 sm:p-4 md:p-6"
          onClick={() => setPlaying(null)}
          role="dialog"
          aria-modal="true"
          aria-label={playing.title}
        >
          <div
            className="w-full max-w-6xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-2xl overflow-hidden flex flex-col lg:flex-row max-h-[92vh]"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Left Column: Main Video Player + Info & Actions */}
            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
              <div className="relative aspect-video bg-black w-full shrink-0">
                <iframe
                  src={embed}
                  title={playing.title}
                  className="absolute inset-0 w-full h-full"
                  allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                  allowFullScreen
                  referrerPolicy="strict-origin-when-cross-origin"
                />
              </div>

              <div className="p-4 sm:p-5">
                <div className="flex items-start justify-between gap-3">
                  <h2 className="text-base sm:text-lg font-bold text-appText-primary dark:text-appText-dark-primary line-clamp-2">
                    {playing.title}
                  </h2>
                  <button
                    type="button"
                    onClick={() => setPlaying(null)}
                    className="lg:hidden p-2 rounded-full bg-surface-muted dark:bg-surface-dark-muted text-appText-secondary hover:text-appText-primary shrink-0"
                    title="Đóng"
                  >
                    <X size={18} />
                  </button>
                </div>

                <div className="mt-3 flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-appBorder-light dark:border-appBorder-dark">
                  {/* Channel info */}
                  <div className="flex items-center gap-2.5 min-w-0">
                    <ChannelBadge name={playing.channelTitle} size="md" />
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                        {playing.channelTitle}
                      </p>
                      <p className="text-xs text-appText-secondary">
                        {playing.publishedAt ? timeAgo(playing.publishedAt) : "YouTube Video"}
                      </p>
                    </div>
                  </div>

                  {/* Action Toolbar */}
                  <div className="flex flex-wrap items-center gap-1.5">
                    <button
                      type="button"
                      onClick={playPrev}
                      disabled={!hasPrev}
                      className="p-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-appText-primary dark:text-appText-dark-primary disabled:opacity-40 transition"
                      title="Video trước"
                    >
                      <SkipBack size={16} />
                    </button>
                    <button
                      type="button"
                      onClick={playNext}
                      disabled={!hasNext}
                      className="p-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-appText-primary dark:text-appText-dark-primary disabled:opacity-40 transition"
                      title="Video tiếp theo"
                    >
                      <SkipForward size={16} />
                    </button>

                    <button
                      type="button"
                      onClick={() => setSharingVideo(playing)}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-brand text-white text-xs font-semibold hover:opacity-90 transition"
                    >
                      <Send size={14} />
                      <span>Gửi cho bạn bè</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => void handleCopyLink(playing)}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition"
                    >
                      {copiedId === playing.id ? (
                        <>
                          <Check size={14} className="text-emerald-500" />
                          <span>Đã chép link</span>
                        </>
                      ) : (
                        <>
                          <Link2 size={14} />
                          <span>Sao chép link</span>
                        </>
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={() => setIsMiniPlayer(true)}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition"
                      title="Thu nhỏ xuống góc màn hình để vừa xem vừa lướt"
                    >
                      <PictureInPicture2 size={15} />
                      <span className="hidden sm:inline">Thu nhỏ</span>
                    </button>

                    <a
                      href={youtubeWatchUrl(playing.id)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="p-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand text-appText-secondary transition"
                      title="Mở trên YouTube"
                    >
                      <ExternalLink size={16} />
                    </a>
                  </div>
                </div>
              </div>
            </div>

            {/* Right Column: Up Next Queue */}
            <div className="w-full lg:w-80 xl:w-96 border-t lg:border-t-0 lg:border-l border-appBorder-light dark:border-appBorder-dark flex flex-col bg-surface-muted/40 dark:bg-surface-dark-muted/20 max-h-[38vh] lg:max-h-none">
              <div className="px-4 py-3 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between shrink-0">
                <div className="flex items-center gap-2">
                  <ListVideo size={17} className="text-brand" />
                  <span className="text-xs font-bold text-appText-primary dark:text-appText-dark-primary">
                    Danh sách phát tiếp theo
                  </span>
                  <span className="text-[11px] px-2 py-0.5 rounded-full bg-brand/10 text-brand font-semibold">
                    {queue.length}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => setPlaying(null)}
                  className="hidden lg:inline-flex p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-appText-primary transition"
                  title="Đóng trình phát"
                >
                  <X size={18} />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-2.5 space-y-1.5">
                {queue.map((item, idx) => {
                  const active = item.id === playing.id;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => setPlaying(item)}
                      className={`w-full text-left p-2 rounded-xl flex items-start gap-2.5 transition ${
                        active
                          ? "bg-brand/10 border border-brand/30"
                          : "hover:bg-surface-light dark:hover:bg-surface-dark border border-transparent"
                      }`}
                    >
                      <span className="text-[11px] font-bold text-appText-secondary w-4 text-center self-center shrink-0">
                        {active ? "▶" : idx + 1}
                      </span>
                      <div className="relative w-28 aspect-video rounded-lg overflow-hidden bg-black/20 shrink-0">
                        {item.thumbnailUrl && (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={item.thumbnailUrl}
                            alt=""
                            className="w-full h-full object-cover"
                            loading="lazy"
                          />
                        )}
                        {formatDuration(item.durationSeconds) && (
                          <span className="absolute bottom-1 right-1 px-1 py-0.2 rounded bg-black/80 text-white text-[9px] font-semibold">
                            {formatDuration(item.durationSeconds)}
                          </span>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <p
                          className={`text-xs font-bold line-clamp-2 ${
                            active
                              ? "text-brand"
                              : "text-appText-primary dark:text-appText-dark-primary"
                          }`}
                        >
                          {item.title}
                        </p>
                        <p className="text-[11px] text-appText-secondary truncate mt-0.5">
                          {item.channelTitle}
                        </p>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 2. Floating Mini-Player (Picture-in-Picture style in bottom-right corner) */}
      {playing && embed && isMiniPlayer && (
        <div
          className="fixed bottom-5 right-5 z-50 w-80 sm:w-96 rounded-2xl overflow-hidden bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark shadow-2xl"
          role="region"
          aria-label={`Trình phát thu nhỏ: ${playing.title}`}
        >
          <div className="px-3 py-2 bg-surface-muted dark:bg-surface-dark-muted flex items-center justify-between gap-2 border-b border-appBorder-light dark:border-appBorder-dark">
            <div className="flex items-center gap-1.5 min-w-0">
              <span className="w-2 h-2 rounded-full bg-brand animate-pulse shrink-0" />
              <span className="text-[11px] font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                Đang phát thu nhỏ
              </span>
            </div>
            <div className="flex items-center gap-1 shrink-0">
              {hasNext && (
                <button
                  type="button"
                  onClick={playNext}
                  className="p-1.5 rounded-lg hover:bg-black/10 dark:hover:bg-white/10 text-appText-secondary hover:text-appText-primary transition"
                  title="Video tiếp theo"
                >
                  <SkipForward size={14} />
                </button>
              )}
              <button
                type="button"
                onClick={() => setIsMiniPlayer(false)}
                className="p-1.5 rounded-lg hover:bg-black/10 dark:hover:bg-white/10 text-appText-secondary hover:text-brand transition"
                title="Phóng to trình phát"
              >
                <Maximize2 size={14} />
              </button>
              <button
                type="button"
                onClick={() => {
                  setPlaying(null);
                  setIsMiniPlayer(false);
                }}
                className="p-1.5 rounded-lg hover:bg-black/10 dark:hover:bg-white/10 text-appText-secondary hover:text-red-500 transition"
                title="Đóng"
              >
                <X size={14} />
              </button>
            </div>
          </div>

          <div className="relative aspect-video bg-black">
            <iframe
              src={embed}
              title={playing.title}
              className="absolute inset-0 w-full h-full"
              allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
              allowFullScreen
              referrerPolicy="strict-origin-when-cross-origin"
            />
          </div>

          <div className="p-3 flex items-center justify-between gap-2">
            <div
              onClick={() => setIsMiniPlayer(false)}
              className="min-w-0 flex-1 cursor-pointer"
            >
              <p className="text-xs font-bold text-appText-primary dark:text-appText-dark-primary truncate hover:text-brand transition">
                {playing.title}
              </p>
              <p className="text-[11px] text-appText-secondary truncate">
                {playing.channelTitle}
              </p>
            </div>
            <button
              type="button"
              onClick={() => setSharingVideo(playing)}
              className="p-2 rounded-xl bg-brand/10 text-brand hover:bg-brand hover:text-white transition shrink-0"
              title="Gửi cho bạn bè"
            >
              <Send size={14} />
            </button>
          </div>
        </div>
      )}

      {/* 4. Share Video to Chat Modal */}
      {sharingVideo && (
        <ShareVideoToChatModal
          video={sharingVideo}
          onClose={() => setSharingVideo(null)}
        />
      )}
    </div>
  );
}

function ShareVideoToChatModal({
  video,
  onClose,
}: {
  video: YoutubeVideo;
  onClose: () => void;
}) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [note, setNote] = useState("");
  const [sendingId, setSendingId] = useState<string | null>(null);
  const [sentIds, setSentIds] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    clientFetch<{ data: Conversation[] }>("conversations")
      .then((res) => {
        if (active) setConversations(res.data);
      })
      .catch(() => {
        if (active) setError("Không tải được danh sách trò chuyện.");
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return conversations;
    return conversations.filter(
      (c) =>
        c.participant.name.toLowerCase().includes(q) ||
        c.participant.username.toLowerCase().includes(q)
    );
  }, [conversations, search]);

  const handleSend = async (conv: Conversation) => {
    if (sendingId || sentIds.has(conv.id)) return;
    setSendingId(conv.id);
    setError(null);
    const watchUrl = youtubeWatchUrl(video.id);
    const customNote = note.trim();
    const messageText = customNote
      ? `${customNote}\n🎬 ${video.title} (${video.channelTitle})\n${watchUrl}`
      : `🎬 ${video.title} (${video.channelTitle})\n${watchUrl}`;

    try {
      await clientFetch(`conversations/${conv.id}/messages`, {
        method: "POST",
        headers: { "Idempotency-Key": crypto.randomUUID() },
        body: JSON.stringify({ text: messageText }),
      });
      setSentIds((prev) => new Set(prev).add(conv.id));
    } catch {
      setError("Gửi tin nhắn thất bại, vui lòng thử lại.");
    } finally {
      setSendingId(null);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[70] bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Gửi video cho bạn bè"
    >
      <div
        className="w-full max-w-md bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="px-4 py-3.5 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <h3 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary flex items-center gap-2">
            <Send size={16} className="text-brand" />
            <span>Gửi video cho bạn bè</span>
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary"
          >
            <X size={16} />
          </button>
        </div>

        {/* Video Preview */}
        <div className="p-3.5 bg-surface-muted/50 dark:bg-surface-dark-muted/40 border-b border-appBorder-light dark:border-appBorder-dark flex items-center gap-3">
          {video.thumbnailUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={video.thumbnailUrl}
              alt=""
              className="w-20 aspect-video rounded-lg object-cover bg-black/20 shrink-0"
            />
          )}
          <div className="min-w-0 flex-1">
            <p className="text-xs font-bold text-appText-primary dark:text-appText-dark-primary line-clamp-2">
              {video.title}
            </p>
            <p className="text-[11px] text-appText-secondary truncate mt-0.5">
              {video.channelTitle}
            </p>
          </div>
        </div>

        {/* Optional Note & Search */}
        <div className="p-3.5 space-y-2.5 border-b border-appBorder-light dark:border-appBorder-dark">
          <input
            type="text"
            value={note}
            maxLength={500}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Thêm lời nhắn kèm theo (tùy chọn)..."
            className="w-full px-3 py-2 rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light dark:border-appBorder-dark text-xs text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none focus:border-brand"
          />
          <div className="relative">
            <Search
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-appText-secondary"
            />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm người nhận..."
              className="w-full pl-8 pr-3 py-2 rounded-xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark text-xs text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none focus:border-brand"
            />
          </div>
        </div>

        {error && (
          <p className="px-4 py-2 text-xs text-red-500 bg-red-500/10">{error}</p>
        )}

        {/* Conversation List */}
        <div className="flex-1 overflow-y-auto p-2.5 space-y-1 min-h-[180px]">
          {loading ? (
            <div className="py-10 flex justify-center">
              <Loader2 className="w-6 h-6 text-brand animate-spin" />
            </div>
          ) : filtered.length === 0 ? (
            <p className="py-10 text-center text-xs text-appText-secondary">
              Không tìm thấy cuộc trò chuyện nào.
            </p>
          ) : (
            filtered.map((conv) => {
              const isSent = sentIds.has(conv.id);
              const isSending = sendingId === conv.id;
              return (
                <div
                  key={conv.id}
                  className="flex items-center justify-between gap-3 p-2 rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <UserAvatar
                      imageUrl={conv.participant.avatarUrl}
                      name={conv.participant.name}
                      size="sm"
                      isOnline={conv.participant.isOnline}
                    />
                    <div className="min-w-0">
                      <p className="text-xs font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                        {conv.participant.name}
                      </p>
                      <p className="text-[11px] text-appText-secondary truncate">
                        @{conv.participant.username}
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    disabled={isSent || isSending}
                    onClick={() => void handleSend(conv)}
                    className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition shrink-0 ${
                      isSent
                        ? "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400"
                        : "bg-brand text-white hover:opacity-90 disabled:opacity-50"
                    }`}
                  >
                    {isSending ? (
                      <Loader2 size={13} className="animate-spin" />
                    ) : isSent ? (
                      "Đã gửi"
                    ) : (
                      "Gửi"
                    )}
                  </button>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
