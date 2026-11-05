"use client";

import React, { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Bookmark, Sparkles, Loader2, AlertCircle, Compass } from "lucide-react";
import { PostCard } from "@/components/feed/PostCard";
import { clientFetch } from "@/lib/client-api";
import type { Post, CursorMeta } from "@/types";

export default function SavedPostsPage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadSavedPosts = useCallback(async (cursor?: string | null) => {
    if (cursor) {
      setLoadingMore(true);
    } else {
      setLoading(true);
    }
    setError(null);

    try {
      const q = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{
        data: Post[];
        meta?: CursorMeta;
      }>(`/api/proxy/me/saved-posts${q}`);

      if (cursor) {
        setPosts((prev) => [...prev, ...(res.data || [])]);
      } else {
        setPosts(res.data || []);
      }
      setNextCursor(res.meta?.nextCursor || null);
    } catch {
      setError("Không thể tải danh sách bài viết đã lưu lúc này.");
      if (!cursor) setPosts([]);
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, []);

  useEffect(() => {
    loadSavedPosts();
  }, [loadSavedPosts]);

  const handlePostDeleted = (deletedId: string) => {
    setPosts((prev) => prev.filter((p) => p.id !== deletedId));
  };

  const handlePostSaved = (postId: string, isSaved: boolean) => {
    if (!isSaved) {
      setPosts((prev) => prev.filter((p) => p.id !== postId));
    }
  };

  return (
    <div className="max-w-2xl mx-auto pb-16">
      {/* Header bar */}
      <div className="mb-6">
        <div className="flex items-center gap-2.5 mb-1.5">
          <div className="w-9 h-9 rounded-xl bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand">
            <Bookmark size={20} className="fill-brand" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-appText-primary dark:text-appText-dark-primary">
              Bài viết đã lưu
            </h1>
          </div>
        </div>
        <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
          Chỉ bạn mới có thể nhìn thấy các bài viết bạn đã lưu trong mục này
        </p>
      </div>

      {/* Error state */}
      {error && (
        <div className="p-4 mb-4 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-500 text-xs flex items-center gap-2">
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      {/* Loading state */}
      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center">
          <Loader2 className="w-8 h-8 text-brand animate-spin mb-3" />
          <p className="text-xs text-appText-secondary">Đang tải bài viết đã lưu...</p>
        </div>
      ) : posts.length === 0 ? (
        /* Empty state */
        <div className="py-16 text-center bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark p-8 shadow-sm">
          <div className="w-16 h-16 rounded-full bg-brand/10 dark:bg-brand/20 text-brand flex items-center justify-center mx-auto mb-4">
            <Bookmark size={30} />
          </div>
          <h3 className="text-base font-bold text-appText-primary dark:text-appText-dark-primary mb-1.5">
            Chưa có bài viết nào được lưu
          </h3>
          <p className="text-xs text-appText-secondary max-w-sm mx-auto mb-6 leading-relaxed">
            Khi bạn bắt gặp một bài viết hay hoặc hình ảnh đẹp trên Bảng tin, hãy bấm Lưu để xem lại bất cứ lúc nào tại đây.
          </p>
          <Link
            href="/explore"
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm shadow-brand/25 active:scale-95 transition"
          >
            <Compass size={16} />
            <span>Khám phá bài viết mới</span>
          </Link>
        </div>
      ) : (
        /* Posts list */
        <div className="space-y-4">
          {posts.map((post) => (
            <PostCard
              key={post.id}
              post={post}
              onPostDeleted={handlePostDeleted}
              onPostHidden={handlePostDeleted}
              onPostSaved={handlePostSaved}
            />
          ))}

          {/* Load More Button */}
          {nextCursor && (
            <div className="pt-4 text-center">
              <button
                onClick={() => loadSavedPosts(nextCursor)}
                disabled={loadingMore}
                className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition active:scale-95 disabled:opacity-50"
              >
                {loadingMore && <Loader2 size={14} className="animate-spin" />}
                <span>Tải thêm bài viết</span>
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
