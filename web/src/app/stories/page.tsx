"use client";

import React, { useState, useEffect, useRef, useCallback, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import {
  X,
  ChevronLeft,
  ChevronRight,
  Volume2,
  VolumeX,
  Trash2,
  Lock,
  Globe,
  Users,
  Send,
  Loader2,
  Sparkles,
  Music2,
  AlertCircle,
  ExternalLink,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { timeAgo } from "@/lib/time-ago";
import { getStoryGradient, STORY_PRIVACY_OPTIONS } from "@/lib/story-constants";
import type { Story, Privacy } from "@/types";

const STORY_DURATION_MS = 5000;
const QUICK_REACTIONS = ["❤️", "🔥", "😂", "😮", "😢", "👏", "😍", "🎉"];
const MORE_REACTIONS = ["🥰", "🙌", "💯", "✨", "🤩", "🥺", "😡", "👍", "😻", "🌟"];

function StoriesViewerContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialStoryId = searchParams.get("id");
  const targetUserId = searchParams.get("user");
  const { user: currentUser } = useAuth();
  const { toast } = useToast();

  const [stories, setStories] = useState<Story[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [progress, setProgress] = useState(0); // 0 to 100 for current segment
  const [isMuted, setIsMuted] = useState(false);

  // Bottom action bar states
  const [replyText, setReplyText] = useState("");
  const [sendingReply, setSendingReply] = useState(false);
  const [sentToast, setSentToast] = useState<string | null>(null);
  const [floatingReaction, setFloatingReaction] = useState<string | null>(null);
  const [showMoreEmojis, setShowMoreEmojis] = useState(false);

  // Privacy change menu
  const [showPrivacyMenu, setShowPrivacyMenu] = useState(false);
  const [changingPrivacy, setChangingPrivacy] = useState(false);

  // Audio preview reference
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const startTimeRef = useRef<number>(Date.now());
  const elapsedBeforePauseRef = useRef<number>(0);
  const viewedIdsRef = useRef<Set<string>>(new Set());

  // 1. Fetch stories
  useEffect(() => {
    let isMounted = true;

    const loadStories = async () => {
      setLoading(true);
      try {
        let endpoint = "/api/proxy/stories";
        if (targetUserId) {
          endpoint = `/api/proxy/users/${targetUserId}/stories`;
        }

        const res = await clientFetch<{ data: Story[] }>(endpoint);
        const list = res.data || [];

        if (isMounted) {
          setStories(list);

          if (list.length > 0) {
            if (initialStoryId) {
              const foundIdx = list.findIndex((s) => s.id === initialStoryId);
              if (foundIdx !== -1) {
                setCurrentIndex(foundIdx);
              }
            }
          }
        }
      } catch {
        if (isMounted) setStories([]);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    loadStories();

    return () => {
      isMounted = false;
    };
  }, [initialStoryId, targetUserId]);

  const currentStory: Story | undefined = stories[currentIndex];

  // 2. Mark story as viewed
  const markCurrentViewed = useCallback(async (storyId: string) => {
    if (viewedIdsRef.current.has(storyId)) return;
    viewedIdsRef.current.add(storyId);

    try {
      await clientFetch(`/api/proxy/stories/${storyId}/view`, {
        method: "POST",
      });
      setStories((prev) =>
        prev.map((s) => (s.id === storyId ? { ...s, isViewed: true } : s))
      );
    } catch {
      // Ignore
    }
  }, []);

  // 3. Audio preview management
  useEffect(() => {
    if (!currentStory?.track?.previewUrl) {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
      return;
    }

    if (audioRef.current) {
      audioRef.current.pause();
    }

    const audio = new Audio(currentStory.track.previewUrl);
    audio.loop = true;
    audio.muted = isMuted;
    audioRef.current = audio;

    if (!isPaused) {
      audio.play().catch(() => {});
    }

    return () => {
      audio.pause();
    };
  }, [currentStory, isMuted]);

  // Handle pause/resume audio
  useEffect(() => {
    if (!audioRef.current) return;
    if (isPaused) {
      audioRef.current.pause();
    } else {
      audioRef.current.play().catch(() => {});
    }
  }, [isPaused]);

  // Handle mute toggle
  const toggleMute = () => {
    setIsMuted((prev) => {
      const next = !prev;
      if (audioRef.current) {
        audioRef.current.muted = next;
      }
      return next;
    });
  };

  // 4. Progress bar and automatic advance
  const handleNextStory = useCallback(() => {
    if (currentIndex < stories.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      startTimeRef.current = Date.now();
    } else {
      router.push("/");
    }
  }, [currentIndex, stories.length, router]);

  const handlePrevStory = useCallback(() => {
    if (currentIndex > 0) {
      setCurrentIndex((prev) => prev - 1);
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      startTimeRef.current = Date.now();
    } else {
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      startTimeRef.current = Date.now();
    }
  }, [currentIndex]);

  useEffect(() => {
    if (stories.length === 0 || !currentStory) return;

    markCurrentViewed(currentStory.id);
    setProgress(0);
    elapsedBeforePauseRef.current = 0;
    startTimeRef.current = Date.now();
  }, [currentIndex, currentStory, markCurrentViewed, stories.length]);

  useEffect(() => {
    if (loading || stories.length === 0 || isPaused) return;

    const interval = 50; // update every 50ms
    startTimeRef.current = Date.now() - elapsedBeforePauseRef.current;

    timerRef.current = setInterval(() => {
      const elapsed = Date.now() - startTimeRef.current;
      const pct = Math.min((elapsed / STORY_DURATION_MS) * 100, 100);
      setProgress(pct);

      if (elapsed >= STORY_DURATION_MS) {
        if (timerRef.current) clearInterval(timerRef.current);
        handleNextStory();
      }
    }, interval);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [currentIndex, isPaused, loading, stories.length, handleNextStory]);

  const pauseTimer = () => {
    if (isPaused) return;
    setIsPaused(true);
    elapsedBeforePauseRef.current = Date.now() - startTimeRef.current;
  };

  const resumeTimer = () => {
    if (!isPaused) return;
    setIsPaused(false);
    startTimeRef.current = Date.now() - elapsedBeforePauseRef.current;
  };

  // 5. Keyboard Navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }
      if (e.key === "ArrowRight") {
        handleNextStory();
      } else if (e.key === "ArrowLeft") {
        handlePrevStory();
      } else if (e.key === " ") {
        e.preventDefault();
        setIsPaused((p) => !p);
      } else if (e.key === "Escape") {
        router.push("/");
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleNextStory, handlePrevStory, router]);

  // 6. Delete Story
  const handleDeleteStory = async () => {
    if (!currentStory) return;
    pauseTimer();

    if (!confirm("Bạn có chắc chắn muốn xóa tin này không?")) {
      resumeTimer();
      return;
    }

    try {
      await clientFetch(`/api/proxy/stories/${currentStory.id}`, {
        method: "DELETE",
      });

      const nextStories = stories.filter((s) => s.id !== currentStory.id);
      toast.success("Đã xóa tin");
      if (nextStories.length === 0) {
        router.push("/");
      } else {
        setStories(nextStories);
        if (currentIndex >= nextStories.length) {
          setCurrentIndex(nextStories.length - 1);
        }
        resumeTimer();
      }
    } catch {
      toast.error("Không thể xóa tin lúc này.");
      resumeTimer();
    }
  };

  // 7. Update Privacy
  const handleChangePrivacy = async (privacy: Privacy) => {
    if (!currentStory || changingPrivacy) return;
    setChangingPrivacy(true);
    try {
      await clientFetch(`/api/proxy/stories/${currentStory.id}`, {
        method: "PATCH",
        body: JSON.stringify({ privacy }),
      });
      setStories((prev) =>
        prev.map((s) => (s.id === currentStory.id ? { ...s, privacy } : s))
      );
      setShowPrivacyMenu(false);
      toast.success("Đã đổi quyền riêng tư của tin");
    } catch {
      toast.error("Không thể đổi quyền riêng tư của tin.");
    } finally {
      setChangingPrivacy(false);
      resumeTimer();
    }
  };

  // 8. Reply message or quick reaction
  const handleSendReply = async (textToSend?: string) => {
    const msg = (textToSend || replyText).trim();
    if (!msg || !currentStory || sendingReply) return;

    setSendingReply(true);
    pauseTimer();

    try {
      // 1. Get or create conversation with author
      const convRes = await clientFetch<{ data: { id: string } }>(
        "/api/proxy/conversations",
        {
          method: "POST",
          body: JSON.stringify({ userId: currentStory.author.id }),
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
          text: `Đã phản hồi tin của bạn: ${msg}`,
        }),
      });

      setReplyText("");
      toast.success("Đã gửi phản hồi tin!");
    } catch {
      toast.error("Không thể gửi phản hồi.");
    } finally {
      setSendingReply(false);
      resumeTimer();
    }
  };

  const handleQuickReaction = (emoji: string) => {
    setFloatingReaction(emoji);
    setTimeout(() => setFloatingReaction(null), 1200);
    handleSendReply(emoji);
  };

  if (loading) {
    return (
      <div className="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center text-white">
        <Loader2 className="w-10 h-10 text-brand animate-spin mb-4" />
        <p className="text-sm font-medium text-white/70">Đang tải tin...</p>
      </div>
    );
  }

  if (stories.length === 0 || !currentStory) {
    return (
      <div className="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center p-6 text-white text-center">
        <div className="w-16 h-16 rounded-full bg-white/10 flex items-center justify-center mb-4">
          <Sparkles size={32} className="text-white/60" />
        </div>
        <h2 className="text-xl font-bold mb-2">Chưa có tin nào</h2>
        <p className="text-sm text-white/60 max-w-sm mb-6">
          Không có tin nào đang hiển thị hoặc tin đã hết hạn sau 24 giờ.
        </p>
        <Link
          href="/"
          className="px-6 py-2.5 rounded-full bg-white/15 hover:bg-white/25 text-white text-sm font-medium transition"
        >
          Quay lại Bảng tin
        </Link>
      </div>
    );
  }

  const isOwner = currentUser?.id === currentStory.author.id;

  return (
    <div className="fixed inset-0 z-50 bg-black/95 text-white flex items-center justify-center overflow-hidden select-none">
      {/* Background blur from current story */}
      <div
        className="absolute inset-0 opacity-20 filter blur-3xl pointer-events-none"
        style={getStoryGradient(currentStory.background)}
      />

      {/* Main Story Container (Aspect 9:16) */}
      <div
        className="relative w-full max-w-md h-full md:max-h-[92vh] md:rounded-3xl overflow-hidden shadow-2xl flex flex-col justify-between border border-white/10"
        onMouseDown={pauseTimer}
        onMouseUp={resumeTimer}
        onTouchStart={pauseTimer}
        onTouchEnd={resumeTimer}
      >
        {/* Story Background Layer */}
        {currentStory.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={currentStory.imageUrl}
            alt=""
            className="absolute inset-0 w-full h-full object-cover"
          />
        ) : (
          <div
            className="absolute inset-0 transition-all duration-300"
            style={getStoryGradient(currentStory.background)}
          />
        )}

        {/* Gradient shadows for readability */}
        <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black/75 pointer-events-none" />

        {/* Floating reaction animation */}
        {floatingReaction && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-30">
            <span className="text-8xl animate-bounce drop-shadow-2xl">
              {floatingReaction}
            </span>
          </div>
        )}

        {/* Top Header Layer: Progress Bars + User Info + Controls */}
        <div className="relative z-20 p-4 pt-3 flex flex-col gap-3">
          {/* Segmented Progress Bars */}
          <div className="flex items-center gap-1.5 w-full">
            {stories.map((s, idx) => {
              let segmentWidth = "0%";
              if (idx < currentIndex) {
                segmentWidth = "100%";
              } else if (idx === currentIndex) {
                segmentWidth = `${progress}%`;
              }

              return (
                <div
                  key={s.id}
                  className="flex-1 h-1.5 bg-white/30 rounded-full overflow-hidden"
                >
                  <div
                    className="h-full bg-white transition-all duration-75 ease-linear rounded-full"
                    style={{ width: segmentWidth }}
                  />
                </div>
              );
            })}
          </div>

          {/* Author info & Actions */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Link
                href={`/profile/${currentStory.author.id}`}
                onClick={(e) => e.stopPropagation()}
                className="hover:opacity-90 transition"
              >
                <UserAvatar
                  name={currentStory.author.name}
                  src={currentStory.author.avatarUrl}
                  size="sm"
                  className="ring-2 ring-white/60"
                />
              </Link>
              <div>
                <div className="flex items-center gap-2">
                  <Link
                    href={`/profile/${currentStory.author.id}`}
                    onClick={(e) => e.stopPropagation()}
                    className="text-sm font-bold text-white hover:underline drop-shadow"
                  >
                    {currentStory.author.name}
                  </Link>
                  <span className="text-xs text-white/75 drop-shadow">
                    {timeAgo(currentStory.createdAt)}
                  </span>
                </div>
                {/* Privacy Badge */}
                <div className="flex items-center gap-1 text-[11px] text-white/70">
                  {currentStory.privacy === "public" && <Globe size={11} />}
                  {currentStory.privacy === "friends" && <Users size={11} />}
                  {currentStory.privacy === "only_me" && <Lock size={11} />}
                  <span>
                    {
                      STORY_PRIVACY_OPTIONS.find(
                        (p) => p.value === currentStory.privacy
                      )?.label
                    }
                  </span>
                </div>
              </div>
            </div>

            {/* Top Right Buttons */}
            <div
              className="flex items-center gap-1"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Music mute/unmute */}
              {currentStory.track && (
                <button
                  onClick={toggleMute}
                  title={isMuted ? "Bật âm thanh" : "Tắt âm thanh"}
                  className="p-2 text-white/80 hover:text-white rounded-full hover:bg-white/15 transition"
                >
                  {isMuted ? <VolumeX size={18} /> : <Volume2 size={18} />}
                </button>
              )}

              {/* Owner actions: Delete & Privacy */}
              {isOwner && (
                <>
                  <div className="relative">
                    <button
                      onClick={() => {
                        pauseTimer();
                        setShowPrivacyMenu((v) => !v);
                      }}
                      title="Đổi quyền riêng tư"
                      className="p-2 text-white/80 hover:text-white rounded-full hover:bg-white/15 transition"
                    >
                      <Lock size={18} />
                    </button>

                    {showPrivacyMenu && (
                      <div className="absolute right-0 top-10 w-44 bg-surface-dark border border-white/15 rounded-xl shadow-xl py-1 z-40 text-xs">
                        <div className="px-3 py-1.5 font-semibold text-white/60 border-b border-white/10">
                          Ai xem được tin này:
                        </div>
                        {STORY_PRIVACY_OPTIONS.map((opt) => (
                          <button
                            key={opt.value}
                            onClick={() => handleChangePrivacy(opt.value)}
                            className={`w-full px-3 py-2 text-left flex items-center justify-between hover:bg-white/10 transition ${
                              currentStory.privacy === opt.value
                                ? "text-brand font-bold"
                                : "text-white"
                            }`}
                          >
                            <span>{opt.label}</span>
                            {currentStory.privacy === opt.value && (
                              <span>✓</span>
                            )}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>

                  <button
                    onClick={handleDeleteStory}
                    title="Xóa tin"
                    className="p-2 text-white/80 hover:text-rose-400 rounded-full hover:bg-white/15 transition"
                  >
                    <Trash2 size={18} />
                  </button>
                </>
              )}

              {/* Close Button */}
              <button
                onClick={() => router.push("/")}
                title="Đóng (Esc)"
                className="p-2 text-white/80 hover:text-white rounded-full hover:bg-white/15 transition"
              >
                <X size={20} />
              </button>
            </div>
          </div>
        </div>

        {/* Center Content: Story Text & Attached Song */}
        <div className="relative z-10 p-6 my-auto flex flex-col items-center justify-center text-center">
          {currentStory.text && (
            <div className="max-w-xs bg-black/35 backdrop-blur-md rounded-2xl px-5 py-4 shadow-xl border border-white/10">
              <p className="text-white text-xl md:text-2xl font-bold leading-relaxed drop-shadow-md">
                {currentStory.text}
              </p>
            </div>
          )}

          {/* Attached Song Badge */}
          {currentStory.track && (
            <div
              onClick={(e) => {
                e.stopPropagation();
                toggleMute();
              }}
              className="mt-4 inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded-full bg-black/40 backdrop-blur-md border border-white/20 text-white text-xs shadow-lg cursor-pointer hover:bg-black/60 transition"
            >
              <Music2
                size={14}
                className={isMuted ? "text-white/60" : "text-brand animate-pulse"}
              />
              <span className="font-semibold truncate max-w-[220px]">
                {currentStory.track.title} · {currentStory.track.artist}
              </span>
              {currentStory.track.appleMusicUrl && (
                <a
                  href={currentStory.track.appleMusicUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="text-white/70 hover:text-white ml-1"
                  title="Mở trên Apple Music"
                >
                  <ExternalLink size={12} />
                </a>
              )}
            </div>
          )}
        </div>

        {/* Tap target areas for Next / Prev navigation on phone & desktop */}
        <div className="absolute inset-0 flex z-10 pointer-events-auto">
          {/* Left 40% area: Previous */}
          <div
            className="w-2/5 h-3/4 self-center cursor-pointer"
            onClick={(e) => {
              e.stopPropagation();
              handlePrevStory();
            }}
            title="Tin trước"
          />
          {/* Middle 20% area: Neutral tap */}
          <div className="w-1/5 h-3/4 self-center" />
          {/* Right 40% area: Next */}
          <div
            className="w-2/5 h-3/4 self-center cursor-pointer"
            onClick={(e) => {
              e.stopPropagation();
              handleNextStory();
            }}
            title="Tin kế tiếp"
          />
        </div>

        {/* Bottom Layer: Quick Reactions & Reply Input (when viewing others' stories) */}
        <div
          className="relative z-20 p-4 pt-2 flex flex-col gap-2.5"
          onClick={(e) => e.stopPropagation()}
        >
          {sentToast && (
            <div className="p-2 bg-emerald-500/90 text-white text-xs font-semibold rounded-xl text-center shadow-lg backdrop-blur-md animate-in fade-in">
              {sentToast}
            </div>
          )}

          {!isOwner && (
            <>
              {/* Quick Emojis Reaction Bar */}
              <div className="flex items-center justify-between px-2 gap-1 relative">
                {QUICK_REACTIONS.map((emoji) => (
                  <button
                    key={emoji}
                    onClick={() => handleQuickReaction(emoji)}
                    className="text-2xl hover:scale-125 active:scale-95 transition-transform"
                    title={`Thả cảm xúc ${emoji}`}
                  >
                    {emoji}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={() => setShowMoreEmojis(!showMoreEmojis)}
                  className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition ${
                    showMoreEmojis
                      ? "bg-brand text-white"
                      : "bg-white/20 hover:bg-white/30 text-white"
                  }`}
                  title="Thêm biểu tượng cảm xúc"
                >
                  {showMoreEmojis ? "✕" : "➕"}
                </button>

                {/* More Emojis Popover */}
                {showMoreEmojis && (
                  <div className="absolute bottom-11 right-0 bg-black/90 backdrop-blur-md border border-white/20 rounded-2xl p-2.5 shadow-2xl flex flex-wrap gap-2 max-w-[220px] z-30 animate-in fade-in zoom-in-95">
                    {MORE_REACTIONS.map((emoji) => (
                      <button
                        key={emoji}
                        onClick={() => {
                          setShowMoreEmojis(false);
                          handleQuickReaction(emoji);
                        }}
                        className="text-2xl hover:scale-125 active:scale-95 transition-transform p-1"
                        title={`Thả cảm xúc ${emoji}`}
                      >
                        {emoji}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Reply Input */}
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  handleSendReply();
                }}
                className="flex items-center gap-2"
              >
                <input
                  type="text"
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  onFocus={pauseTimer}
                  onBlur={resumeTimer}
                  placeholder={`Gửi tin nhắn cho ${currentStory.author.name}...`}
                  className="flex-1 bg-black/40 backdrop-blur-md border border-white/20 rounded-full px-4 py-2.5 text-xs text-white placeholder-white/60 outline-none focus:border-brand transition"
                />
                <button
                  type="submit"
                  disabled={!replyText.trim() || sendingReply}
                  className="w-9 h-9 rounded-full bg-brand text-white flex items-center justify-center shrink-0 disabled:opacity-40 hover:bg-brand-hover active:scale-95 transition"
                >
                  {sendingReply ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Send size={15} />
                  )}
                </button>
              </form>
            </>
          )}

          {isOwner && (
            <div className="text-center py-1">
              <span className="text-xs text-white/70">
                Tin của bạn · Hết hạn sau 24 giờ
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Floating navigation buttons on desktop outside of story frame */}
      {currentIndex > 0 && (
        <button
          onClick={handlePrevStory}
          className="hidden md:flex absolute left-8 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 items-center justify-center text-white transition active:scale-95"
          title="Tin trước (Phím mũi tên trái)"
        >
          <ChevronLeft size={28} />
        </button>
      )}

      {currentIndex < stories.length - 1 && (
        <button
          onClick={handleNextStory}
          className="hidden md:flex absolute right-8 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 items-center justify-center text-white transition active:scale-95"
          title="Tin sau (Phím mũi tên phải)"
        >
          <ChevronRight size={28} />
        </button>
      )}
    </div>
  );
}

export default function StoriesPage() {
  return (
    <Suspense
      fallback={
        <div className="fixed inset-0 z-50 bg-black flex flex-col items-center justify-center text-white">
          <Loader2 className="w-10 h-10 text-brand animate-spin mb-4" />
          <p className="text-sm font-medium text-white/70">Đang mở tin...</p>
        </div>
      }
    >
      <StoriesViewerContent />
    </Suspense>
  );
}
