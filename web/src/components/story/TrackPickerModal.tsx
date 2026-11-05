"use client";

import React, { useState, useEffect, useRef } from "react";
import {
  X,
  Search,
  Music2,
  Play,
  Pause,
  ExternalLink,
  Check,
  Loader2,
  AlertCircle,
} from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import type { Track } from "@/types";

interface TrackPickerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectTrack: (track: Track) => void;
  selectedTrackId?: string | null;
}

export function TrackPickerModal({
  isOpen,
  onClose,
  onSelectTrack,
  selectedTrackId,
}: TrackPickerModalProps) {
  const [query, setQuery] = useState("");
  const [tracks, setTracks] = useState<Track[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Audio preview playback state
  const [playingTrackId, setPlayingTrackId] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Clean up audio on unmount or close
  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    if (!isOpen && audioRef.current) {
      audioRef.current.pause();
      setPlayingTrackId(null);
    }
  }, [isOpen]);

  const togglePreview = (track: Track, e: React.MouseEvent) => {
    e.stopPropagation();

    if (playingTrackId === track.id) {
      // Pause
      if (audioRef.current) {
        audioRef.current.pause();
      }
      setPlayingTrackId(null);
      return;
    }

    // Play new
    if (audioRef.current) {
      audioRef.current.pause();
    }

    const audio = new Audio(track.previewUrl);
    audioRef.current = audio;
    audio.play().catch(() => {
      setPlayingTrackId(null);
    });
    setPlayingTrackId(track.id);

    audio.onended = () => {
      setPlayingTrackId(null);
    };
  };

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setQuery(val);

    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    if (val.trim().length < 2) {
      setTracks([]);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    debounceTimerRef.current = setTimeout(async () => {
      try {
        const res = await clientFetch<{ data: Track[] }>(
          `/api/proxy/music/search?q=${encodeURIComponent(val.trim())}`
        );
        setTracks(res.data || []);
      } catch {
        setError("Không thể tải danh sách bài hát lúc này.");
        setTracks([]);
      } finally {
        setLoading(false);
      }
    }, 400);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-surface-light dark:bg-surface-dark w-full max-w-lg rounded-2xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark flex flex-col max-h-[85vh] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand">
              <Music2 size={18} />
            </div>
            <h3 className="text-base font-bold text-appText-primary dark:text-appText-dark-primary">
              Chọn nhạc cho tin
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-appText-secondary hover:text-appText-primary dark:text-appText-dark-secondary dark:hover:text-appText-dark-primary rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Search bar */}
        <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <div className="relative">
            <Search
              size={18}
              className="absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary dark:text-appText-dark-secondary"
            />
            <input
              type="text"
              autoFocus
              value={query}
              onChange={handleSearchChange}
              placeholder="Tìm kiếm bài hát, nghệ sĩ..."
              className="w-full pl-10 pr-4 py-2.5 rounded-full bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand focus:bg-surface-light dark:focus:bg-surface-dark text-sm text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none transition"
            />
            {loading && (
              <Loader2
                size={18}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-brand animate-spin"
              />
            )}
          </div>
        </div>

        {/* Results list */}
        <div className="flex-1 overflow-y-auto p-3 space-y-1 divide-y divide-appBorder-light/50 dark:divide-appBorder-dark/50">
          {error && (
            <div className="p-4 text-center text-xs text-rose-500 flex items-center justify-center gap-2">
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}

          {query.trim().length < 2 && !loading && (
            <div className="py-12 text-center text-appText-secondary dark:text-appText-dark-secondary">
              <Music2 size={40} className="mx-auto mb-2 opacity-40" />
              <p className="text-sm font-medium">Nhập ít nhất 2 ký tự để tìm kiếm bài hát</p>
              <p className="text-xs opacity-75 mt-1">Nguồn từ danh mục Apple Music Việt Nam</p>
            </div>
          )}

          {query.trim().length >= 2 && !loading && tracks.length === 0 && !error && (
            <div className="py-12 text-center text-appText-secondary dark:text-appText-dark-secondary">
              <p className="text-sm font-medium">Không tìm thấy bài hát nào</p>
              <p className="text-xs opacity-75 mt-1">Thử tìm với từ khóa hoặc tên ca sĩ khác</p>
            </div>
          )}

          {tracks.map((track) => {
            const isPlaying = playingTrackId === track.id;
            const isSelected = selectedTrackId === track.id;

            return (
              <div
                key={track.id}
                onClick={() => {
                  onSelectTrack(track);
                  onClose();
                }}
                className={`flex items-center gap-3 p-2.5 rounded-xl cursor-pointer transition-colors ${
                  isSelected
                    ? "bg-brand/10 dark:bg-brand/20 border border-brand/30"
                    : "hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                }`}
              >
                {/* Artwork + Play/Pause button */}
                <div className="relative w-12 h-12 rounded-lg overflow-hidden bg-appBorder-light dark:bg-appBorder-dark shrink-0 group">
                  {track.artworkUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={track.artworkUrl}
                      alt={track.title}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-appText-secondary">
                      <Music2 size={20} />
                    </div>
                  )}

                  {/* Play overlay button */}
                  <button
                    onClick={(e) => togglePreview(track, e)}
                    title={isPlaying ? "Tạm dừng nghe thử" : "Nghe thử 30s"}
                    className="absolute inset-0 bg-black/40 flex items-center justify-center text-white opacity-90 group-hover:opacity-100 transition-opacity"
                  >
                    {isPlaying ? (
                      <Pause size={18} className="fill-white" />
                    ) : (
                      <Play size={18} className="fill-white ml-0.5" />
                    )}
                  </button>
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0">
                  <h4 className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary truncate">
                    {track.title}
                  </h4>
                  <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary truncate mt-0.5">
                    {track.artist}
                  </p>
                  {track.appleMusicUrl && (
                    <a
                      href={track.appleMusicUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={(e) => e.stopPropagation()}
                      className="inline-flex items-center gap-1 text-[10px] text-brand hover:underline mt-1"
                    >
                      <span>Mở Apple Music</span>
                      <ExternalLink size={10} />
                    </a>
                  )}
                </div>

                {/* Selected Indicator */}
                {isSelected && (
                  <div className="w-6 h-6 rounded-full bg-brand text-white flex items-center justify-center shrink-0">
                    <Check size={14} />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Footer info note */}
        <div className="px-5 py-3 bg-surface-muted/50 dark:bg-surface-dark-muted/50 border-t border-appBorder-light dark:border-appBorder-dark flex items-center justify-between text-xs text-appText-secondary dark:text-appText-dark-secondary">
          <span>Đoạn nghe thử 30 giây được cung cấp bởi Apple Music</span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-full border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary text-xs font-medium hover:bg-surface-light dark:hover:bg-surface-dark transition"
          >
            Đóng
          </button>
        </div>
      </div>
    </div>
  );
}
