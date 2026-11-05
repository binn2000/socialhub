"use client";

import React, { useState, useRef, useEffect } from "react";
import {
  X,
  Music2,
  Trash2,
  Send,
  Loader2,
  Play,
  Pause,
  ExternalLink,
  Edit3,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { timeAgo } from "@/lib/time-ago";
import type { Note } from "@/types";

interface ViewNoteModalProps {
  note: Note;
  isOpen: boolean;
  onClose: () => void;
  onEditNote?: () => void;
  onDeleteNote?: () => void;
  onOpenConversation?: (conversationId: string) => void;
}

export function ViewNoteModal({
  note,
  isOpen,
  onClose,
  onEditNote,
  onDeleteNote,
  onOpenConversation,
}: ViewNoteModalProps) {
  const { user: currentUser } = useAuth();
  const { toast } = useToast();
  const isMine = currentUser?.id === note.user.id;

  const [replyText, setReplyText] = useState("");
  const [sendingReply, setSendingReply] = useState(false);
  const [sentToast, setSentToast] = useState(false);
  const [floatingReaction, setFloatingReaction] = useState<string | null>(null);

  const NOTE_QUICK_REACTIONS = ["❤️", "🔥", "😂", "😍", "🙌", "💯", "👀", "👏"];

  // Audio preview
  const [isPlayingPreview, setIsPlayingPreview] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

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
      setIsPlayingPreview(false);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const toggleTrackAudio = () => {
    if (!note.track?.previewUrl) return;

    if (isPlayingPreview) {
      audioRef.current?.pause();
      setIsPlayingPreview(false);
    } else {
      if (!audioRef.current) {
        audioRef.current = new Audio(note.track.previewUrl);
        audioRef.current.onended = () => setIsPlayingPreview(false);
      }
      audioRef.current.play().catch(() => setIsPlayingPreview(false));
      setIsPlayingPreview(true);
    }
  };

  const handleSendReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyText.trim() || sendingReply) return;

    setSendingReply(true);
    try {
      // 1. Get or create conversation with author
      const convRes = await clientFetch<{ data: { id: string } }>(
        "/api/proxy/conversations",
        {
          method: "POST",
          body: JSON.stringify({ userId: note.user.id }),
        }
      );

      // 2. Send message
      const idempotencyKey = crypto.randomUUID();
      await clientFetch(`/api/proxy/conversations/${convRes.data.id}/messages`, {
        method: "POST",
        headers: {
          "Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify({
          text: `Đã phản hồi ghi chú của bạn: ${replyText.trim()}`,
        }),
      });

      setSentToast(true);
      toast.success("Đã gửi phản hồi ghi chú!");
      setTimeout(() => {
        setSentToast(false);
        onClose();
        if (onOpenConversation) {
          onOpenConversation(convRes.data.id);
        }
      }, 1000);
    } catch {
      toast.error("Không thể gửi phản hồi.");
    } finally {
      setSendingReply(false);
    }
  };

  const handleSendEmojiReaction = async (emoji: string) => {
    if (sendingReply) return;
    setFloatingReaction(emoji);
    setTimeout(() => setFloatingReaction(null), 1200);

    setSendingReply(true);
    try {
      const convRes = await clientFetch<{ data: { id: string } }>(
        "/api/proxy/conversations",
        {
          method: "POST",
          body: JSON.stringify({ userId: note.user.id }),
        }
      );

      const idempotencyKey = crypto.randomUUID();
      await clientFetch(`/api/proxy/conversations/${convRes.data.id}/messages`, {
        method: "POST",
        headers: {
          "Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify({
          text: `Đã bày tỏ cảm xúc ${emoji} với ghi chú của bạn`,
        }),
      });

      setSentToast(true);
      toast.success(`Đã gửi cảm xúc ${emoji}!`);
      setTimeout(() => {
        setSentToast(false);
        onClose();
        if (onOpenConversation) {
          onOpenConversation(convRes.data.id);
        }
      }, 1000);
    } catch {
      toast.error("Không thể gửi cảm xúc. Vui lòng thử lại.");
    } finally {
      setSendingReply(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-surface-light dark:bg-surface-dark w-full max-w-sm rounded-3xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden flex flex-col relative">
        {/* Floating reaction animation */}
        {floatingReaction && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-30">
            <span className="text-7xl animate-bounce drop-shadow-2xl">
              {floatingReaction}
            </span>
          </div>
        )}

        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <span className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
            {timeAgo(note.createdAt)}
          </span>
          <button
            onClick={onClose}
            className="p-1.5 text-appText-secondary hover:text-appText-primary dark:text-appText-dark-secondary rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
          >
            <X size={18} />
          </button>
        </div>

        {/* Note Body */}
        <div className="p-6 flex flex-col items-center">
          {/* Avatar with Floating Thought Bubble */}
          <div className="relative flex flex-col items-center mb-6">
            {/* Thought Bubble */}
            <div className="relative mb-3 max-w-[240px] px-5 py-3 bg-brand/10 dark:bg-brand/20 rounded-2xl shadow-sm border border-brand/20 text-center animate-in zoom-in-95">
              {note.text ? (
                <p className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary break-words leading-relaxed">
                  {note.text}
                </p>
              ) : note.track ? (
                <div className="flex items-center justify-center gap-1.5 text-xs text-brand font-semibold">
                  <Music2 size={14} />
                  <span className="truncate max-w-[160px]">{note.track.title}</span>
                </div>
              ) : null}

              {/* Attached song subtitle inside bubble */}
              {note.text && note.track && (
                <div className="mt-1 flex items-center justify-center gap-1 text-[11px] text-brand font-medium">
                  <Music2 size={11} />
                  <span className="truncate max-w-[180px]">
                    {note.track.title} · {note.track.artist}
                  </span>
                </div>
              )}

              {/* Thought Bubble Dots (tail) */}
              <div className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 w-2.5 h-2.5 bg-brand/10 dark:bg-brand/20 rounded-full border-b border-r border-brand/20" />
              <div className="absolute -bottom-3 left-1/2 -translate-x-1/2 w-1.5 h-1.5 bg-brand/10 dark:bg-brand/20 rounded-full" />
            </div>

            {/* Avatar */}
            <div className="relative">
              <UserAvatar
                name={note.user.name}
                src={note.user.avatarUrl}
                size="lg"
                className="ring-4 ring-brand/30"
              />
            </div>
            <h4 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary mt-2">
              {isMine ? "Ghi chú của bạn" : note.user.name}
            </h4>
            <span className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
              @{note.user.username}
            </span>
          </div>

          {/* Attached song full player card */}
          {note.track && (
            <div className="w-full flex items-center justify-between p-3 mb-5 rounded-2xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light dark:border-appBorder-dark">
              <div className="flex items-center gap-3 overflow-hidden">
                <div className="relative w-10 h-10 rounded-xl overflow-hidden bg-brand/10 flex items-center justify-center text-brand shrink-0">
                  {note.track.artworkUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={note.track.artworkUrl}
                      alt=""
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <Music2 size={18} />
                  )}
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-appText-primary dark:text-appText-dark-primary truncate">
                    {note.track.title}
                  </p>
                  <p className="text-[10px] text-appText-secondary truncate">
                    {note.track.artist}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-1.5 shrink-0 ml-2">
                <button
                  type="button"
                  onClick={toggleTrackAudio}
                  className="p-2 rounded-full bg-brand text-white shadow-xs hover:bg-brand-hover active:scale-95 transition"
                  title={isPlayingPreview ? "Tạm dừng" : "Nghe thử 30s"}
                >
                  {isPlayingPreview ? <Pause size={14} /> : <Play size={14} className="ml-0.5" />}
                </button>
                {note.track.appleMusicUrl && (
                  <a
                    href={note.track.appleMusicUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 text-appText-secondary hover:text-brand transition"
                    title="Mở trên Apple Music"
                  >
                    <ExternalLink size={14} />
                  </a>
                )}
              </div>
            </div>
          )}

          {/* Actions for My Note */}
          {isMine && (
            <div className="w-full flex flex-col gap-2">
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onEditNote?.();
                }}
                className="w-full py-2.5 px-4 rounded-2xl bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm shadow-brand/25 active:scale-95 transition flex items-center justify-center gap-2"
              >
                <Edit3 size={15} />
                <span>Để lại ghi chú mới</span>
              </button>

              <button
                type="button"
                onClick={() => {
                  onClose();
                  onDeleteNote?.();
                }}
                className="w-full py-2 px-4 rounded-2xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-rose-500/10 text-rose-500 text-xs font-medium transition flex items-center justify-center gap-1.5"
              >
                <Trash2 size={14} />
                <span>Gỡ ghi chú này</span>
              </button>
            </div>
          )}

          {/* Reply Form & Quick Reactions for Friend's Note */}
          {!isMine && (
            <div className="w-full space-y-3">
              {sentToast ? (
                <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 dark:text-emerald-400 text-xs font-semibold rounded-xl text-center">
                  Đã gửi phản hồi thành công!
                </div>
              ) : (
                <>
                  {/* Quick Emojis Reaction Bar */}
                  <div>
                    <p className="text-[11px] font-semibold text-appText-secondary dark:text-appText-dark-secondary mb-2 text-center">
                      Thả cảm xúc nhanh
                    </p>
                    <div className="flex items-center justify-between gap-1 p-1.5 rounded-2xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light/70 dark:border-appBorder-dark/70">
                      {NOTE_QUICK_REACTIONS.map((emoji) => (
                        <button
                          key={emoji}
                          type="button"
                          disabled={sendingReply}
                          onClick={() => handleSendEmojiReaction(emoji)}
                          className="w-8 h-8 sm:w-9 sm:h-9 text-lg sm:text-xl flex items-center justify-center rounded-xl hover:bg-white dark:hover:bg-surface-dark hover:scale-125 active:scale-95 transition-transform disabled:opacity-50"
                          title={`Thả cảm xúc ${emoji}`}
                        >
                          {emoji}
                        </button>
                      ))}
                    </div>
                  </div>

                  <form onSubmit={handleSendReply} className="flex items-center gap-2 pt-1">
                    <input
                      type="text"
                      value={replyText}
                      onChange={(e) => setReplyText(e.target.value)}
                      placeholder={`Nhắn tin cho ${note.user.name}...`}
                      className="flex-1 px-4 py-2.5 rounded-full bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand text-xs text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none transition"
                    />
                    <button
                      type="submit"
                      disabled={!replyText.trim() || sendingReply}
                      className="w-9 h-9 rounded-full bg-brand text-white flex items-center justify-center shrink-0 disabled:opacity-40 hover:bg-brand-hover active:scale-95 transition"
                    >
                      {sendingReply ? (
                        <Loader2 size={15} className="animate-spin" />
                      ) : (
                        <Send size={15} />
                      )}
                    </button>
                  </form>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
