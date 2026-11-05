"use client";

import React, { useCallback, useEffect, useRef, useState } from "react";
import { Search, X, Loader2, AlertCircle, PlayCircle } from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import { formatDuration, youtubeEmbedUrl, type YoutubeVideo } from "@/lib/youtube";

interface VideoPage {
  data: YoutubeVideo[];
  meta: { nextCursor: string | null; hasMore: boolean };
}

/** The "Video" tab: search YouTube through our server and watch with YouTube's embedded player. */
export function YoutubeVideos() {
  const [query, setQuery] = useState("");
  const [videos, setVideos] = useState<YoutubeVideo[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [playing, setPlaying] = useState<YoutubeVideo | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Answers can arrive out of order while typing; only the newest request may update the list.
  const requestId = useRef(0);

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

  // Esc closes the player.
  useEffect(() => {
    if (!playing) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setPlaying(null);
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [playing]);

  const onChange = (text: string) => {
    setQuery(text);
    if (timer.current) clearTimeout(timer.current);
    // 600 ms: a YouTube search costs 100 of the 10,000 free daily units.
    timer.current = setTimeout(() => void load(text), 600);
  };

  const embed = playing ? youtubeEmbedUrl(playing.id) : null;

  return (
    <div>
      <div className="relative mb-5">
        <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-appText-secondary" />
        <input
          type="text"
          value={query}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Tìm video trên YouTube..."
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

      {!query.trim() && !loading && !error && (
        <p className="text-xs font-semibold text-appText-secondary mb-3">Video đang thịnh hành</p>
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
            onClick={() => void load(query)}
            className="px-4 py-2 rounded-full bg-brand text-white text-xs font-semibold hover:opacity-90"
          >
            Thử lại
          </button>
        </div>
      ) : videos.length === 0 ? (
        <div className="py-16 text-center text-xs text-appText-secondary">
          Không tìm thấy video nào cho &ldquo;{query}&rdquo;.
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {videos.map((v) => (
              <button
                key={v.id}
                type="button"
                onClick={() => setPlaying(v)}
                className="group text-left bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden hover:shadow-card-hover transition cursor-pointer"
              >
                <div className="relative aspect-video bg-black/10">
                  {v.thumbnailUrl && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={v.thumbnailUrl} alt="" className="w-full h-full object-cover" loading="lazy" />
                  )}
                  <span className="absolute inset-0 flex items-center justify-center bg-black/0 group-hover:bg-black/25 transition">
                    <PlayCircle className="w-12 h-12 text-white opacity-0 group-hover:opacity-100 drop-shadow-lg transition" />
                  </span>
                  {formatDuration(v.durationSeconds) && (
                    <span className="absolute bottom-2 right-2 px-1.5 py-0.5 rounded bg-black/80 text-white text-[11px] font-semibold">
                      {formatDuration(v.durationSeconds)}
                    </span>
                  )}
                </div>
                <div className="p-3">
                  <h3 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary line-clamp-2">
                    {v.title}
                  </h3>
                  <p className="text-xs text-appText-secondary mt-1 truncate">{v.channelTitle}</p>
                </div>
              </button>
            ))}
          </div>
          {nextCursor && (
            <div className="pt-5 text-center">
              <button
                type="button"
                onClick={() => void load(query, nextCursor)}
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

      {playing && embed && (
        <div
          className="fixed inset-0 z-[60] bg-black/80 flex items-center justify-center p-4"
          onClick={() => setPlaying(null)}
          role="dialog"
          aria-modal="true"
          aria-label={playing.title}
        >
          <div className="w-full max-w-4xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between gap-3 mb-2">
              <div className="min-w-0">
                <h2 className="text-white text-sm font-bold line-clamp-2">{playing.title}</h2>
                <p className="text-white/70 text-xs truncate">{playing.channelTitle}</p>
              </div>
              <button
                type="button"
                onClick={() => setPlaying(null)}
                className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white shrink-0"
                title="Đóng"
              >
                <X size={18} />
              </button>
            </div>
            <div className="relative aspect-video rounded-xl overflow-hidden bg-black">
              <iframe
                src={embed}
                title={playing.title}
                className="absolute inset-0 w-full h-full"
                allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                allowFullScreen
                referrerPolicy="strict-origin-when-cross-origin"
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
