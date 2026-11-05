"use client";

import React, { useState, useRef } from "react";
import {
  X,
  Music2,
  Trash2,
  Lock,
  Globe,
  Users,
  Loader2,
  AlertCircle,
  Play,
  Pause,
  Smile,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { TrackPickerModal } from "@/components/story/TrackPickerModal";
import type { Note, Privacy, Track } from "@/types";

interface CreateNoteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onNoteSaved: (note: Note | null) => void;
  initialNote?: Note | null;
}

const PRIVACY_OPTIONS: { value: Privacy; label: string; icon: LucideIcon }[] = [
  { value: "friends", label: "Bạn bè", icon: Users },
  { value: "public", label: "Công khai", icon: Globe },
  { value: "only_me", label: "Chỉ mình tôi", icon: Lock },
];

export function CreateNoteModal({
  isOpen,
  onClose,
  onNoteSaved,
  initialNote,
}: CreateNoteModalProps) {
  const { user } = useAuth();
  const { toast } = useToast();

  const [text, setText] = useState(initialNote?.text || "");
  const [selectedPrivacy, setSelectedPrivacy] = useState<Privacy>(
    initialNote?.privacy || "friends"
  );
  const [selectedTrack, setSelectedTrack] = useState<Track | null>(
    initialNote?.track || null
  );

  const [trackModalOpen, setTrackModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Audio preview for attached song
  const [isPlayingPreview, setIsPlayingPreview] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  if (!isOpen) return null;

  const toggleTrackAudio = () => {
    if (!selectedTrack?.previewUrl) return;

    if (isPlayingPreview) {
      audioRef.current?.pause();
      setIsPlayingPreview(false);
    } else {
      if (!audioRef.current) {
        audioRef.current = new Audio(selectedTrack.previewUrl);
        audioRef.current.onended = () => setIsPlayingPreview(false);
      }
      audioRef.current.play().catch(() => setIsPlayingPreview(false));
      setIsPlayingPreview(true);
    }
  };

  const handleSave = async () => {
    if (!text.trim() && !selectedTrack) {
      setError("Vui lòng nhập nội dung suy nghĩ hoặc chọn bài hát.");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    if (audioRef.current) {
      audioRef.current.pause();
      setIsPlayingPreview(false);
    }

    try {
      const res = await clientFetch<{ data: Note }>("/api/proxy/me/note", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: text.trim(),
          trackId: selectedTrack?.id,
          privacy: selectedPrivacy,
        }),
      });

      onNoteSaved(res.data);
      onClose();
      toast.success("Đã chia sẻ ghi chú mới!");
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Không thể lưu ghi chú lúc này."
      );
      toast.error(err instanceof Error ? err.message : "Không thể lưu ghi chú lúc này.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Bạn có chắc muốn gỡ ghi chú này không?")) return;

    setIsDeleting(true);
    try {
      await clientFetch("/api/proxy/me/note", { method: "DELETE" });
      onNoteSaved(null);
      onClose();
      toast.success("Đã gỡ ghi chú");
    } catch {
      toast.error("Không thể xóa ghi chú.");
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-surface-light dark:bg-surface-dark w-full max-w-sm rounded-3xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <button
            onClick={onClose}
            className="p-1.5 text-appText-secondary hover:text-appText-primary dark:text-appText-dark-secondary rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
          >
            <X size={18} />
          </button>
          <h3 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary">
            {initialNote ? "Chỉnh sửa ghi chú" : "Ghi chú mới"}
          </h3>
          <button
            onClick={handleSave}
            disabled={isSubmitting || (!text.trim() && !selectedTrack)}
            className="px-4 py-1.5 rounded-full bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm shadow-brand/25 active:scale-95 disabled:opacity-40 transition flex items-center gap-1.5"
          >
            {isSubmitting && <Loader2 size={13} className="animate-spin" />}
            <span>Chia sẻ</span>
          </button>
        </div>

        {/* Content & Avatar Preview */}
        <div className="p-6 flex flex-col items-center">
          {error && (
            <div className="w-full mb-4 p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-500 text-xs flex items-center gap-2">
              <AlertCircle size={15} className="shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Avatar with Floating Thought Bubble */}
          <div className="relative flex flex-col items-center mb-6">
            {/* Thought Bubble */}
            <div className="relative mb-2 max-w-[220px] px-4 py-2.5 bg-surface-muted dark:bg-surface-dark-muted rounded-2xl shadow-md border border-appBorder-light dark:border-appBorder-dark text-center animate-in zoom-in-95">
              {text.trim() ? (
                <p className="text-xs font-semibold text-appText-primary dark:text-appText-dark-primary break-words leading-snug">
                  {text}
                </p>
              ) : selectedTrack ? (
                <div className="flex items-center justify-center gap-1.5 text-xs text-brand font-semibold">
                  <Music2 size={13} />
                  <span className="truncate max-w-[150px]">{selectedTrack.title}</span>
                </div>
              ) : (
                <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary italic">
                  Chia sẻ suy nghĩ...
                </p>
              )}

              {/* Music badge indicator in bubble if both text and track */}
              {text.trim() && selectedTrack && (
                <div className="mt-1 flex items-center justify-center gap-1 text-[10px] text-brand font-medium">
                  <Music2 size={10} />
                  <span className="truncate max-w-[160px]">
                    {selectedTrack.title} · {selectedTrack.artist}
                  </span>
                </div>
              )}

              {/* Thought Bubble Dots (tail) */}
              <div className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-surface-muted dark:bg-surface-dark-muted rounded-full border-b border-r border-appBorder-light dark:border-appBorder-dark" />
              <div className="absolute -bottom-3 left-1/2 -translate-x-1/2 w-1.5 h-1.5 bg-surface-muted dark:bg-surface-dark-muted rounded-full" />
            </div>

            {/* Avatar */}
            <div className="relative">
              <UserAvatar
                name={user?.name}
                src={user?.avatarUrl}
                size="lg"
                className="ring-4 ring-brand/20"
              />
            </div>
            <span className="text-xs font-semibold text-appText-primary dark:text-appText-dark-primary mt-2">
              {user?.name || "Bạn"}
            </span>
          </div>

          {/* Text Input Box */}
          <div className="w-full relative mb-4">
            <textarea
              autoFocus
              value={text}
              // Count characters like the server (an emoji is one), not UTF-16 units as maxLength does.
              onChange={(e) => setText(Array.from(e.target.value).slice(0, 60).join(""))}
              rows={2}
              placeholder="Chia sẻ suy nghĩ của bạn..."
              className="w-full px-4 py-3 rounded-2xl bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand focus:bg-surface-light dark:focus:bg-surface-dark text-xs sm:text-sm text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none transition resize-none text-center"
            />
            <span className="absolute right-3 bottom-2 text-[10px] text-appText-secondary">
              {Array.from(text).length}/60
            </span>
          </div>

          {/* Attached Music Track */}
          {selectedTrack ? (
            <div className="w-full flex items-center justify-between p-2.5 mb-4 rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light dark:border-appBorder-dark">
              <div className="flex items-center gap-2.5 overflow-hidden">
                <div className="w-8 h-8 rounded-lg bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand shrink-0">
                  <Music2 size={16} />
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-appText-primary dark:text-appText-dark-primary truncate">
                    {selectedTrack.title}
                  </p>
                  <p className="text-[10px] text-appText-secondary truncate">
                    {selectedTrack.artist}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <button
                  type="button"
                  onClick={toggleTrackAudio}
                  className="p-1.5 text-appText-secondary hover:text-appText-primary rounded-lg transition"
                  title={isPlayingPreview ? "Tạm dừng" : "Nghe thử"}
                >
                  {isPlayingPreview ? <Pause size={14} /> : <Play size={14} />}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (audioRef.current) audioRef.current.pause();
                    setIsPlayingPreview(false);
                    setSelectedTrack(null);
                  }}
                  className="p-1.5 text-appText-secondary hover:text-rose-500 rounded-lg transition"
                  title="Gỡ bài hát"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => setTrackModalOpen(true)}
              className="w-full mb-4 flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 hover:text-brand border border-appBorder-light dark:border-appBorder-dark text-xs font-medium text-appText-secondary dark:text-appText-dark-secondary transition"
            >
              <Music2 size={15} />
              <span>Thêm nhạc nền</span>
            </button>
          )}

          {/* Privacy Selector */}
          <div className="w-full">
            <span className="text-[11px] font-semibold text-appText-secondary uppercase tracking-wider block mb-2 text-center">
              Ai có thể xem ghi chú này
            </span>
            <div className="grid grid-cols-3 gap-2">
              {PRIVACY_OPTIONS.map((opt) => {
                const Icon = opt.icon;
                const isSelected = selectedPrivacy === opt.value;
                return (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setSelectedPrivacy(opt.value)}
                    className={`py-1.5 px-2 rounded-xl text-xs font-medium flex items-center justify-center gap-1.5 border transition ${
                      isSelected
                        ? "bg-brand text-white border-brand shadow-xs"
                        : "bg-surface-muted dark:bg-surface-dark-muted border-transparent text-appText-secondary hover:text-appText-primary"
                    }`}
                  >
                    <Icon size={12} />
                    <span>{opt.label}</span>
                  </button>
                );
              })}
            </div>
            <p className="text-[10px] text-appText-secondary text-center mt-2.5">
              Ghi chú sẽ biến mất sau 24 giờ. Bạn có thể thay đổi bất cứ lúc nào.
            </p>
          </div>

          {/* Delete note button if editing existing note */}
          {initialNote && (
            <button
              type="button"
              onClick={handleDelete}
              disabled={isDeleting}
              className="mt-4 text-xs font-semibold text-rose-500 hover:text-rose-600 flex items-center gap-1.5 transition"
            >
              <Trash2 size={14} />
              <span>Gỡ ghi chú hiện tại</span>
            </button>
          )}
        </div>
      </div>

      {/* Track Picker Modal */}
      {trackModalOpen && (
        <TrackPickerModal
          isOpen={trackModalOpen}
          onClose={() => setTrackModalOpen(false)}
          onSelectTrack={(track) => setSelectedTrack(track)}
          selectedTrackId={selectedTrack?.id}
        />
      )}
    </div>
  );
}
