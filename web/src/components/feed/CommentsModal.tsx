"use client";

import React, { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { X, Send, Trash2, Flag, MessageCircle } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import { ReportModal } from "./ReportModal";
import type { Post, Comment } from "@/types";

interface CommentsModalProps {
  post: Post | null;
  isOpen: boolean;
  onClose: () => void;
  onCommentCountChanged?: (postId: string, newCount: number) => void;
}

export function CommentsModal({
  post,
  isOpen,
  onClose,
  onCommentCountChanged,
}: CommentsModalProps) {
  const { user: currentUser } = useAuth();
  const { toast } = useToast();

  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [content, setContent] = useState("");
  const [sending, setSending] = useState(false);
  const [reportingComment, setReportingComment] = useState<Comment | null>(null);

  const commentsEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const loadComments = async (postId: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await clientFetch<{ data: Comment[] }>(
        `/api/proxy/posts/${postId}/comments`
      );
      setComments(res.data || []);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể tải danh sách bình luận");
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && post) {
      loadComments(post.id);
      setTimeout(() => inputRef.current?.focus(), 100);
    } else {
      setComments([]);
      setContent("");
      setError(null);
    }
  }, [isOpen, post?.id]);

  if (!isOpen || !post) return null;

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = content.trim();
    if (!text || sending) return;

    setSending(true);
    setError(null);

    // Generate idempotency key
    const idempotencyKey = crypto.randomUUID();

    try {
      const res = await clientFetch<{
        data: Comment;
        meta?: { commentsCount: number };
      }>(`/api/proxy/posts/${post.id}/comments`, {
        method: "POST",
        headers: {
          "Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify({ content: text }),
      });

      const newComments = [res.data, ...comments];
      setComments(newComments);
      setContent("");

      const updatedCount = res.meta?.commentsCount ?? newComments.length;
      onCommentCountChanged?.(post.id, updatedCount);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gửi bình luận. Vui lòng thử lại.");
      }
    } finally {
      setSending(false);
    }
  };

  const handleDelete = async (commentId: string) => {
    try {
      await clientFetch(`/api/proxy/comments/${commentId}`, {
        method: "DELETE",
      });

      const newComments = comments.filter((c) => c.id !== commentId);
      setComments(newComments);

      const updatedCount = Math.max(0, (post.comments || 1) - 1);
      onCommentCountChanged?.(post.id, updatedCount);
      toast.success("Đã xóa bình luận");
    } catch (err) {
      if (err instanceof ApiRequestError) {
        toast.error(err.message);
      } else {
        toast.error("Không thể xóa bình luận. Vui lòng thử lại.");
      }
    }
  };

  const canDelete = (comment: Comment) => {
    if (!currentUser) return false;
    return (
      comment.author.id === currentUser.id ||
      post.author.id === currentUser.id
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
      <div
        className="w-full max-w-lg bg-white dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark flex flex-col max-h-[85vh] overflow-hidden animate-scale-in"
        role="dialog"
        aria-modal="true"
      >
        {/* Header */}
        <div className="p-4 sm:px-6 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <div className="flex items-center gap-2">
            <MessageCircle className="w-5 h-5 text-brand dark:text-brand-light" />
            <h2 className="text-base font-bold text-appText-primary dark:text-white">
              Bình luận ({post.comments})
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {error && (
          <div className="m-4 p-3 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-xs text-red-600 dark:text-red-400">
            {error}
          </div>
        )}

        {/* Comment list */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4">
          {loading ? (
            <div className="py-12 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tải bình luận...</span>
            </div>
          ) : comments.length === 0 ? (
            <div className="py-12 text-center text-appText-secondary">
              <MessageCircle className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-medium text-appText-secondary dark:text-appText-dark-primary">
                Chưa có bình luận nào
              </p>
              <p className="text-xs text-appText-secondary mt-0.5">
                Hãy là người đầu tiên để lại suy nghĩ của bạn!
              </p>
            </div>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="flex gap-3 group">
                <Link href={`/profile/${comment.author.id}`} className="flex-shrink-0">
                  <UserAvatar
                    name={comment.author.name}
                    imageUrl={comment.author.avatarUrl}
                    size="sm"
                  />
                </Link>

                <div className="flex-1 min-w-0">
                  <div className="bg-surface-muted dark:bg-surface-dark-muted/60 rounded-2xl p-3 inline-block max-w-full">
                    <Link
                      href={`/profile/${comment.author.id}`}
                      className="text-xs font-bold text-appText-primary dark:text-white hover:underline block truncate"
                    >
                      {comment.author.name}
                    </Link>
                    <p className="text-sm text-appText-primary dark:text-appText-dark-primary whitespace-pre-wrap break-words mt-0.5">
                      {comment.content}
                    </p>
                  </div>

                  <div className="flex items-center gap-3 mt-1 ml-2 text-[11px] text-appText-secondary">
                    <span>{timeAgo(comment.createdAt)}</span>

                    {canDelete(comment) ? (
                      <button
                        onClick={() => handleDelete(comment.id)}
                        className="text-appText-secondary hover:text-red-600 dark:hover:text-red-400 transition"
                        title="Xóa bình luận"
                      >
                        Xóa
                      </button>
                    ) : (
                      <button
                        onClick={() => setReportingComment(comment)}
                        className="text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
                        title="Báo cáo bình luận"
                      >
                        Báo cáo
                      </button>
                    )}
                  </div>
                </div>
              </div>
            ))
          )}
          <div ref={commentsEndRef} />
        </div>

        {/* Input bar */}
        <form
          onSubmit={handleSend}
          className="p-3 sm:px-4 border-t border-appBorder-light dark:border-appBorder-dark flex items-center gap-2 bg-surface-muted/50 dark:bg-surface-dark"
        >
          <UserAvatar
            name={currentUser?.name}
            imageUrl={currentUser?.avatarUrl}
            size="sm"
          />

          <input
            ref={inputRef}
            type="text"
            required
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Viết bình luận..."
            className="flex-1 px-4 py-2.5 rounded-full border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent placeholder-appText-secondary"
          />

          <button
            type="submit"
            disabled={!content.trim() || sending}
            className="p-2.5 rounded-full bg-brand hover:bg-brand-hover text-white disabled:opacity-40 disabled:cursor-not-allowed transition flex-shrink-0"
            title="Gửi bình luận"
          >
            {sending ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <Send className="w-4 h-4" />
            )}
          </button>
        </form>
      </div>

      {/* Report Comment Modal */}
      {reportingComment && (
        <ReportModal
          isOpen={Boolean(reportingComment)}
          onClose={() => setReportingComment(null)}
          targetType="comment"
          targetId={reportingComment.id}
          targetTitle="bình luận"
        />
      )}
    </div>
  );
}
