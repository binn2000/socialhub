"use client";

import React, { useState } from "react";
import Link from "next/link";
import {
  ThumbsUp,
  MessageCircle,
  Share2,
  Bookmark,
  MoreHorizontal,
  Globe,
  Users,
  Lock,
  Trash2,
  EyeOff,
  Flag,
  UserX,
  Play,
  AlertCircle,
  Clock,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { getPrivacyLabel, getFeelingLabel, POST_REACTIONS, type PostReactionType } from "@/lib/post-constants";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { ChangePrivacyModal } from "./ChangePrivacyModal";
import { ReportModal } from "./ReportModal";
import { ImageViewerModal } from "./ImageViewerModal";
import { PostImageGrid } from "./PostImageGrid";
import { CommentsModal } from "./CommentsModal";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import type { Post, Privacy } from "@/types";

interface PostCardProps {
  post: Post;
  onPostDeleted?: (postId: string) => void;
  onPostHidden?: (postId: string) => void;
  onPostSaved?: (postId: string, isSaved: boolean) => void;
}

/** Width / height of a video, limited so a tall clip is not cropped but also not endlessly high. */
function videoAspectRatio(video: { width?: number | null; height?: number | null }): number {
  if (!video.width || !video.height) return 16 / 9;
  return Math.min(1.8, Math.max(0.625, video.width / video.height));
}

export function PostCard({
  post: initialPost,
  onPostDeleted,
  onPostHidden,
  onPostSaved,
}: PostCardProps) {
  const { user: currentUser } = useAuth();
  const { toast } = useToast();
  const [post, setPost] = useState<Post>(initialPost);
  const [confirmDialog, setConfirmDialog] = useState<{
    isOpen: boolean;
    title: string;
    message: string | React.ReactNode;
    confirmText?: string;
    variant?: "danger" | "warning";
    icon?: "danger" | "trash";
    onConfirm: () => Promise<void> | void;
  }>({
    isOpen: false,
    title: "",
    message: "",
    onConfirm: () => {},
  });

  // Interaction states
  const [isLiked, setIsLiked] = useState<boolean>(initialPost.isLiked);
  const [currentReaction, setCurrentReaction] = useState<PostReactionType | null>(
    initialPost.isLiked ? (initialPost.myReaction ?? "like") : null
  );
  const [reactionCounts, setReactionCounts] = useState<Partial<Record<PostReactionType, number>>>(
    initialPost.reactionCounts ?? {}
  );

  /** Moves one person's count from one reaction to another (null: none). */
  const moveReactionCount = (from: PostReactionType | null, to: PostReactionType | null) => {
    setReactionCounts((prev) => {
      const next = { ...prev };
      if (from) {
        const left = (next[from] ?? 1) - 1;
        if (left <= 0) delete next[from];
        else next[from] = left;
      }
      if (to) next[to] = (next[to] ?? 0) + 1;
      return next;
    });
  };
  // Who reacted how, for the tooltip of the button: "❤️ 2  😆 1".
  const reactionSummary = POST_REACTIONS.filter((r) => (reactionCounts[r.type] ?? 0) > 0)
    .sort((a, b) => (reactionCounts[b.type] ?? 0) - (reactionCounts[a.type] ?? 0))
    .map((r) => `${r.emoji} ${reactionCounts[r.type]}`)
    .join("  ");
  const [showReactionsBar, setShowReactionsBar] = useState(false);
  const [likesCount, setLikesCount] = useState<number>(initialPost.likes);
  const [isSaved, setIsSaved] = useState<boolean>(initialPost.isSaved);
  const [sharesCount, setSharesCount] = useState<number>(initialPost.shares);
  const [commentsCount, setCommentsCount] = useState<number>(initialPost.comments);
  const [likeAnimating, setLikeAnimating] = useState(false);

  const hoverTimerRef = React.useRef<NodeJS.Timeout | null>(null);
  const closeTimerRef = React.useRef<NodeJS.Timeout | null>(null);

  // Touch screens have no hover: a long press opens the bar, a tap elsewhere closes it.
  const touchTimerRef = React.useRef<NodeJS.Timeout | null>(null);
  const longPressedRef = React.useRef(false);
  const likeAreaRef = React.useRef<HTMLDivElement | null>(null);

  React.useEffect(() => {
    return () => {
      if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current);
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
      if (touchTimerRef.current) clearTimeout(touchTimerRef.current);
    };
  }, []);

  React.useEffect(() => {
    if (!showReactionsBar) return;
    const closeOutside = (event: PointerEvent) => {
      if (likeAreaRef.current && !likeAreaRef.current.contains(event.target as Node)) {
        setShowReactionsBar(false);
      }
    };
    document.addEventListener("pointerdown", closeOutside);
    return () => document.removeEventListener("pointerdown", closeOutside);
  }, [showReactionsBar]);

  const startLongPress = () => {
    longPressedRef.current = false;
    if (touchTimerRef.current) clearTimeout(touchTimerRef.current);
    touchTimerRef.current = setTimeout(() => {
      longPressedRef.current = true;
      setShowReactionsBar(true);
    }, 450);
  };

  const cancelLongPress = () => {
    if (touchTimerRef.current) {
      clearTimeout(touchTimerRef.current);
      touchTimerRef.current = null;
    }
  };

  const activeReaction = isLiked
    ? POST_REACTIONS.find((r) => r.type === currentReaction) ?? POST_REACTIONS[0]
    : null;

  const handleMouseEnterLike = () => {
    if (closeTimerRef.current) {
      clearTimeout(closeTimerRef.current);
      closeTimerRef.current = null;
    }
    hoverTimerRef.current = setTimeout(() => {
      setShowReactionsBar(true);
    }, 300);
  };

  const handleMouseLeaveLike = () => {
    if (hoverTimerRef.current) {
      clearTimeout(hoverTimerRef.current);
      hoverTimerRef.current = null;
    }
    closeTimerRef.current = setTimeout(() => {
      setShowReactionsBar(false);
    }, 300);
  };

  const handleSelectReaction = async (reactionType: PostReactionType) => {
    setShowReactionsBar(false);
    if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current);
    if (closeTimerRef.current) clearTimeout(closeTimerRef.current);

    if (isLiked && currentReaction === reactionType) {
      // Toggle off / unlike
      setIsLiked(false);
      setCurrentReaction(null);
      moveReactionCount(reactionType, null);
      setLikesCount((prev) => Math.max(0, prev - 1));
      try {
        await clientFetch(`/api/proxy/posts/${post.id}/like`, { method: "DELETE" });
      } catch {
        setIsLiked(true);
        setCurrentReaction(reactionType);
        moveReactionCount(null, reactionType);
        setLikesCount(likesCount);
      }
      return;
    }

    // A new reaction, or another one instead of the one there: the server keeps it.
    const wasLiked = isLiked;
    const before = wasLiked ? currentReaction ?? "like" : null;
    setIsLiked(true);
    setCurrentReaction(reactionType);
    moveReactionCount(before, reactionType);
    setLikeAnimating(true);
    if (!wasLiked) {
      setLikesCount((prev) => prev + 1);
    }

    try {
      await clientFetch(`/api/proxy/posts/${post.id}/like`, {
        method: "PUT",
        body: JSON.stringify({ reaction: reactionType }),
      });
    } catch {
      setIsLiked(wasLiked);
      setCurrentReaction(before);
      moveReactionCount(reactionType, before);
      if (!wasLiked) setLikesCount(likesCount);
      toast.error("Không thể gửi cảm xúc lúc này");
    }
  };

  // Content expanded state
  const [isExpanded, setIsExpanded] = useState(false);

  // Modals & Menu
  const [menuOpen, setMenuOpen] = useState(false);
  const [privacyModalOpen, setPrivacyModalOpen] = useState(false);
  const [reportModalOpen, setReportModalOpen] = useState(false);
  const [commentsModalOpen, setCommentsModalOpen] = useState(false);
  const [imageViewerOpen, setImageViewerOpen] = useState(false);
  const [imageViewerIndex, setImageViewerIndex] = useState(0);

  // Video play state
  const [isVideoPlaying, setIsVideoPlaying] = useState(false);

  const isMine = currentUser?.id === post.author.id;

  const images = post.imageUrls && post.imageUrls.length > 0
    ? post.imageUrls
    : post.imageUrl
    ? [post.imageUrl]
    : [];

  const handleToggleLike = async () => {
    // The press that opened the reactions bar must not also like the post.
    if (longPressedRef.current) {
      longPressedRef.current = false;
      return;
    }
    setShowReactionsBar(false);
    if (isLiked) {
      const prevReaction = currentReaction ?? "like";
      setIsLiked(false);
      setCurrentReaction(null);
      moveReactionCount(prevReaction, null);
      setLikesCount((prev) => Math.max(0, prev - 1));

      try {
        await clientFetch(`/api/proxy/posts/${post.id}/like`, {
          method: "DELETE",
        });
      } catch {
        setIsLiked(true);
        setCurrentReaction(prevReaction);
        moveReactionCount(null, prevReaction);
        setLikesCount(likesCount);
      }
    } else {
      setIsLiked(true);
      setCurrentReaction("like");
      moveReactionCount(null, "like");
      setLikesCount((prev) => prev + 1);
      setLikeAnimating(true);

      try {
        await clientFetch(`/api/proxy/posts/${post.id}/like`, {
          method: "PUT",
        });
      } catch {
        setIsLiked(false);
        setCurrentReaction(null);
        moveReactionCount("like", null);
        setLikesCount(likesCount);
      }
    }
  };

  const handleToggleSave = async () => {
    const nextSaved = !isSaved;
    setIsSaved(nextSaved);
    setMenuOpen(false);

    try {
      await clientFetch(`/api/proxy/posts/${post.id}/save`, {
        method: nextSaved ? "PUT" : "DELETE",
      });
      onPostSaved?.(post.id, nextSaved);
      const msg = nextSaved
        ? `Đã lưu bài viết của ${post.author.name}`
        : `Đã bỏ lưu bài viết của ${post.author.name}`;
      toast.success(msg);
    } catch {
      setIsSaved(!nextSaved);
      toast.error("Không thể lưu bài viết lúc này");
    }
  };

  const handleHidePost = async () => {
    setMenuOpen(false);
    try {
      await clientFetch(`/api/proxy/posts/${post.id}/hide`, { method: "PUT" });
      onPostHidden?.(post.id);
      const msg = `Đã ẩn bài viết của ${post.author.name} khỏi bảng tin`;
      const undoAction = async () => {
        try {
          await clientFetch(`/api/proxy/posts/${post.id}/hide`, { method: "DELETE" });
          window.location.reload();
        } catch {
          toast.error("Không thể hoàn tác thao tác");
        }
      };
      toast.info(msg, { undoAction });
    } catch {
      toast.error("Không thể ẩn bài viết lúc này");
    }
  };

  const handleDeletePost = () => {
    setMenuOpen(false);
    setConfirmDialog({
      isOpen: true,
      title: "Xóa bài viết này?",
      message: "Bài viết này sẽ bị xóa vĩnh viễn khỏi tài khoản của bạn và không thể khôi phục lại.",
      confirmText: "Xóa bài viết",
      variant: "danger",
      icon: "trash",
      onConfirm: async () => {
        try {
          await clientFetch(`/api/proxy/posts/${post.id}`, { method: "DELETE" });
          onPostDeleted?.(post.id);
          toast.success("Đã xóa bài viết");
        } catch {
          toast.error("Không thể xóa bài viết. Vui lòng thử lại.");
        }
      },
    });
  };

  const handleShare = async () => {
    setMenuOpen(false);
    const postUrl = `${window.location.origin}/posts/${post.id}`;
    try {
      await navigator.clipboard.writeText(postUrl);
      setSharesCount((prev) => prev + 1);
      const msg = `Đã sao chép liên kết bài viết của ${post.author.name}`;
      toast.success(msg);

      await clientFetch(`/api/proxy/posts/${post.id}/shares`, {
        method: "POST",
        body: JSON.stringify({ action: "link" }),
      });
    } catch {
      toast.error("Đã xảy ra lỗi khi sao chép liên kết");
    }
  };

  const handleBlockAuthor = () => {
    setMenuOpen(false);
    setConfirmDialog({
      isOpen: true,
      title: `Chặn ${post.author.name}?`,
      message: `Bạn sẽ không nhìn thấy bài viết của ${post.author.name} nữa và họ cũng không thể tương tác với bạn.`,
      confirmText: "Chặn người dùng",
      variant: "danger",
      icon: "danger",
      onConfirm: async () => {
        try {
          await clientFetch(`/api/proxy/users/${post.author.id}/block`, { method: "PUT" });
          onPostHidden?.(post.id);
          const msg = `Đã chặn ${post.author.name}`;
          toast.info(msg);
        } catch {
          toast.error("Không thể chặn người dùng này");
        }
      },
    });
  };

  const openImageViewer = (index: number) => {
    setImageViewerIndex(index);
    setImageViewerOpen(true);
  };

  const feelingLabel = getFeelingLabel(post.feeling);
  const privacyIcon =
    post.privacy === "friends" ? (
      <Users className="w-3.5 h-3.5" />
    ) : post.privacy === "only_me" ? (
      <Lock className="w-3.5 h-3.5" />
    ) : (
      <Globe className="w-3.5 h-3.5" />
    );

  const shouldTruncate = post.content.length > 350;
  const displayedContent =
    shouldTruncate && !isExpanded
      ? post.content.slice(0, 350) + "..."
      : post.content;

  return (
    <>
      <article className="bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-card hover:shadow-card-hover transition-all duration-200 overflow-hidden">
        {/* Post Header */}
        <div className="p-4 sm:p-5 flex items-start justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <Link href={`/profile/${post.author.id}`} className="flex-shrink-0">
              <UserAvatar
                name={post.author.name}
                imageUrl={post.author.avatarUrl}
                size="md"
              />
            </Link>

            <div className="min-w-0">
              <div className="flex items-center gap-1.5 flex-wrap">
                <Link
                  href={`/profile/${post.author.id}`}
                  className="text-sm font-bold text-appText-primary dark:text-white hover:underline truncate"
                >
                  {post.author.name}
                </Link>

                {feelingLabel && (
                  <span className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
                    đang <strong className="font-medium text-appText-primary dark:text-appText-dark-primary">{feelingLabel.toLowerCase()}</strong>
                  </span>
                )}
              </div>

              <div className="flex items-center gap-1.5 text-xs text-appText-secondary mt-0.5">
                <span>{timeAgo(post.createdAt)}</span>
                <span>·</span>
                <span title={getPrivacyLabel(post.privacy)} className="inline-flex items-center">
                  {privacyIcon}
                </span>
              </div>
            </div>
          </div>

          {/* More menu dropdown */}
          <div className="relative">
            <button
              onClick={() => setMenuOpen(!menuOpen)}
              className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
              title="Tùy chọn bài viết"
            >
              <MoreHorizontal className="w-5 h-5" />
            </button>

            {menuOpen && (
              <>
                <div
                  className="fixed inset-0 z-30"
                  onClick={() => setMenuOpen(false)}
                />
                <div className="absolute right-0 top-full mt-1 w-52 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-xl shadow-lg z-40 py-1.5 animate-scale-in text-sm text-appText-primary dark:text-appText-dark-primary">
                  {isMine && (
                    <button
                      onClick={() => {
                        setMenuOpen(false);
                        setPrivacyModalOpen(true);
                      }}
                      className="w-full px-4 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2.5 transition"
                    >
                      <Lock className="w-4 h-4 text-appText-secondary" />
                      <span>Đổi quyền riêng tư</span>
                    </button>
                  )}

                  <button
                    onClick={handleToggleSave}
                    className="w-full px-4 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2.5 transition"
                  >
                    <Bookmark
                      className={`w-4 h-4 ${
                        isSaved ? "text-brand fill-indigo-600" : "text-appText-secondary"
                      }`}
                    />
                    <span>{isSaved ? "Bỏ lưu bài viết" : "Lưu bài viết"}</span>
                  </button>

                  <button
                    onClick={handleHidePost}
                    className="w-full px-4 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2.5 transition"
                  >
                    <EyeOff className="w-4 h-4 text-appText-secondary" />
                    <span>Ẩn bài viết</span>
                  </button>

                  {!isMine && (
                    <>
                      <button
                        onClick={() => {
                          setMenuOpen(false);
                          setReportModalOpen(true);
                        }}
                        className="w-full px-4 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2.5 transition"
                      >
                        <Flag className="w-4 h-4 text-appText-secondary" />
                        <span>Báo cáo bài viết</span>
                      </button>

                      <button
                        onClick={handleBlockAuthor}
                        className="w-full px-4 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2.5 text-red-600 dark:text-red-400 transition"
                      >
                        <UserX className="w-4 h-4" />
                        <span>Chặn {post.author.name}</span>
                      </button>
                    </>
                  )}

                  {isMine && (
                    <button
                      onClick={handleDeletePost}
                      className="w-full px-4 py-2 text-left hover:bg-red-50 dark:hover:bg-red-950/40 text-red-600 dark:text-red-400 flex items-center gap-2.5 transition border-t border-appBorder-light dark:border-appBorder-dark"
                    >
                      <Trash2 className="w-4 h-4" />
                      <span>Xóa bài viết</span>
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        </div>

        {/* Post Text Content */}
        {post.content && (
          <div className="px-4 sm:px-5 pb-3">
            <p className="text-sm sm:text-base text-appText-primary dark:text-appText-dark-primary whitespace-pre-wrap break-words leading-relaxed">
              {displayedContent}
            </p>
            {shouldTruncate && (
              <button
                onClick={() => setIsExpanded(!isExpanded)}
                className="mt-1 text-xs font-semibold text-brand dark:text-brand-light hover:underline"
              >
                {isExpanded ? "Thu gọn" : "Xem thêm"}
              </button>
            )}
          </div>
        )}

        {/* Media: Multi-Image Display */}
        {images.length > 0 && (
          <div className="relative mt-2 bg-surface-muted dark:bg-appBg-dark">
            {images.length === 1 && (
              <button
                type="button"
                onClick={() => openImageViewer(0)}
                className="w-full flex justify-center cursor-pointer"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={images[0]}
                  alt="Ảnh bài viết"
                  className="w-auto h-auto max-w-full max-h-[550px] object-contain hover:opacity-95 transition"
                />
              </button>
            )}

            {images.length >= 2 && (
              <PostImageGrid images={images} onOpen={openImageViewer} />
            )}
          </div>
        )}

        {/* Media: Video Display */}
        {post.video && (
          <div
            className="relative mt-2 bg-black overflow-hidden flex items-center justify-center"
            style={{ aspectRatio: videoAspectRatio(post.video) }}
          >
            {post.video.status === "failed" ? (
              <div className="text-center p-6 text-white/70">
                <AlertCircle className="w-8 h-8 mx-auto mb-2 opacity-80" />
                <p className="text-sm">Không xử lý được video</p>
              </div>
            ) : post.video.status === "processing" ? (
              <div className="text-center p-6 text-white/70">
                <div className="w-6 h-6 border-2 border-white/60 border-t-white rounded-full animate-spin mx-auto mb-2" />
                <p className="text-sm">Đang xử lý video...</p>
              </div>
            ) : post.video.url ? (
              isVideoPlaying ? (
                <video
                  src={post.video.url}
                  controls
                  autoPlay
                  className="w-full h-full object-contain"
                />
              ) : (
                <div
                  onClick={() => setIsVideoPlaying(true)}
                  className="relative w-full h-full cursor-pointer group"
                >
                  {post.video.thumbnailUrl && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={post.video.thumbnailUrl}
                      alt="Thumbnail video"
                      className="w-full h-full object-contain opacity-90 group-hover:opacity-100 transition"
                    />
                  )}
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="w-14 h-14 rounded-full bg-black/60 group-hover:bg-black/80 text-white flex items-center justify-center backdrop-blur-sm group-hover:scale-110 transition shadow-lg">
                      <Play className="w-6 h-6 fill-white ml-0.5" />
                    </div>
                  </div>
                  {post.video.durationSeconds && (
                    <span className="absolute bottom-3 right-3 px-2 py-0.5 rounded bg-black/70 text-white text-xs font-medium backdrop-blur-sm flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      {Math.floor(post.video.durationSeconds / 60)}:
                      {(post.video.durationSeconds % 60).toString().padStart(2, "0")}
                    </span>
                  )}
                </div>
              )
            ) : null}
          </div>
        )}

        {/* Action Bar */}
        <div className="px-4 py-3 border-t border-appBorder-light dark:border-appBorder-dark/80 flex items-center justify-between mt-1">
          <div className="flex items-center gap-1 sm:gap-2">
            {/* Like button with reaction popup */}
            <div
              ref={likeAreaRef}
              className="relative inline-flex items-center"
              onMouseEnter={handleMouseEnterLike}
              onMouseLeave={handleMouseLeaveLike}
            >
              {/* Reactions Bar Popup */}
              {showReactionsBar && (
                <div
                  className="absolute bottom-full left-0 mb-2 z-30 flex items-center gap-1 px-2 py-1.5 bg-white/95 dark:bg-surface-dark/95 backdrop-blur-md rounded-full shadow-2xl border border-appBorder-light dark:border-appBorder-dark/80 animate-dropdown-in"
                  role="toolbar"
                  aria-label="Chọn cảm xúc"
                >
                  {POST_REACTIONS.map((r) => (
                    <button
                      key={r.type}
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleSelectReaction(r.type);
                      }}
                      className="group/rx relative p-1.5 text-2xl leading-none transition-transform hover:scale-125 active:scale-110 cursor-pointer"
                      title={r.label}
                    >
                      <span className="block transition-transform duration-150">
                        {r.emoji}
                      </span>
                      {/* Tooltip */}
                      <span className="absolute -top-7 left-1/2 -translate-x-1/2 px-1.5 py-0.5 text-[10px] font-semibold text-white bg-black/80 rounded-full opacity-0 group-hover/rx:opacity-100 transition-opacity pointer-events-none whitespace-nowrap shadow">
                        {r.label}
                      </span>
                    </button>
                  ))}
                </div>
              )}

              <button
                type="button"
                onClick={handleToggleLike}
                title={reactionSummary || "Thích"}
                onTouchStart={startLongPress}
                onTouchEnd={cancelLongPress}
                onTouchMove={cancelLongPress}
                onTouchCancel={cancelLongPress}
                onContextMenu={(event) => event.preventDefault()}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs sm:text-sm font-semibold transition active:scale-95 select-none ${
                  isLiked
                    ? activeReaction
                      ? `${activeReaction.color} bg-surface-muted dark:bg-surface-dark-muted/60`
                      : "text-like bg-like/10 dark:bg-like/20"
                    : "text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60"
                }`}
              >
                {/* One icon that follows the reaction: the emoji of the chosen one, or a thumb for a plain like. */}
                {isLiked && activeReaction && activeReaction.type !== "like" ? (
                  <span
                    className={`text-base leading-none transition-transform ${
                      likeAnimating ? "animate-like-pop" : ""
                    }`}
                    onAnimationEnd={() => setLikeAnimating(false)}
                  >
                    {activeReaction.emoji}
                  </span>
                ) : (
                  <ThumbsUp
                    className={`w-4 h-4 transition-transform ${
                      isLiked
                        ? "fill-current scale-110"
                        : "text-appText-secondary"
                    } ${likeAnimating ? "animate-like-pop" : ""}`}
                    onAnimationEnd={() => setLikeAnimating(false)}
                  />
                )}
                <span>{likesCount}</span>
                {isLiked && activeReaction && (
                  <span className="hidden sm:inline text-xs font-semibold ml-0.5">
                    {activeReaction.label}
                  </span>
                )}
              </button>
            </div>

            {/* Comment button */}
            <button
              type="button"
              onClick={() => setCommentsModalOpen(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs sm:text-sm font-semibold text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 transition active:scale-95"
            >
              <MessageCircle className="w-4 h-4 text-appText-secondary" />
              <span>{commentsCount}</span>
            </button>

            {/* Share button */}
            <button
              type="button"
              onClick={handleShare}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs sm:text-sm font-semibold text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 transition active:scale-95"
              title="Chia sẻ liên kết bài viết"
            >
              <Share2 className="w-4 h-4 text-appText-secondary" />
              <span>{sharesCount}</span>
            </button>
          </div>

          {/* Bookmark / Save button */}
          <button
            type="button"
            onClick={handleToggleSave}
            className={`p-2 rounded-full transition active:scale-95 ${
              isSaved
                ? "text-brand dark:text-brand-light bg-brand-soft dark:bg-brand/15"
                : "text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60"
            }`}
            title={isSaved ? "Bỏ lưu bài viết" : "Lưu bài viết"}
          >
            <Bookmark className={`w-4 h-4 ${isSaved ? "fill-brand" : ""}`} />
          </button>
        </div>
      </article>

      {/* Change Privacy Modal */}
      {privacyModalOpen && (
        <ChangePrivacyModal
          post={post}
          isOpen={privacyModalOpen}
          onClose={() => setPrivacyModalOpen(false)}
          onPrivacyChanged={(id, newPrivacy) => {
            setPost((prev) => ({ ...prev, privacy: newPrivacy }));
            const msg = `Đã đổi quyền riêng tư thành "${getPrivacyLabel(newPrivacy)}"`;
            toast.success(msg);
          }}
        />
      )}

      {/* Report Modal */}
      {reportModalOpen && (
        <ReportModal
          isOpen={reportModalOpen}
          onClose={() => setReportModalOpen(false)}
          targetType="post"
          targetId={post.id}
          targetTitle="bài viết"
        />
      )}

      {/* Lightbox Image Viewer */}
      {imageViewerOpen && (
        <ImageViewerModal
          images={images}
          initialIndex={imageViewerIndex}
          isOpen={imageViewerOpen}
          onClose={() => setImageViewerOpen(false)}
        />
      )}

      {/* Comments Drawer / Modal */}
      {commentsModalOpen && (
        <CommentsModal
          post={{ ...post, comments: commentsCount }}
          isOpen={commentsModalOpen}
          onClose={() => setCommentsModalOpen(false)}
          onCommentCountChanged={(id, newCount) => {
            setCommentsCount(newCount);
            setPost((prev) => ({ ...prev, comments: newCount }));
          }}
        />
      )}

      {/* Confirmation Modal */}
      <ConfirmModal
        isOpen={confirmDialog.isOpen}
        onClose={() => setConfirmDialog((prev) => ({ ...prev, isOpen: false }))}
        onConfirm={confirmDialog.onConfirm}
        title={confirmDialog.title}
        message={confirmDialog.message}
        confirmText={confirmDialog.confirmText}
        variant={confirmDialog.variant}
        icon={confirmDialog.icon}
      />
    </>
  );
}
