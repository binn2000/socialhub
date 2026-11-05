"use client";

import React, { useState, useEffect, useCallback } from "react";
import {
  Sparkles,
  Users,
  Image as ImageIcon,
  Flame,
  RotateCw,
  Inbox,
  AlertCircle,
} from "lucide-react";
import { CreatePostCard } from "./CreatePostCard";
import { PostCard } from "./PostCard";
import { StoryTray } from "./StoryTray";
import { RightSidebar } from "@/components/layout/RightSidebar";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import type { Post, CursorMeta } from "@/types";

type FeedTabKey = "all" | "following" | "media";

interface FeedTabOption {
  key: FeedTabKey;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

const FEED_TABS: FeedTabOption[] = [
  { key: "all", label: "Dành cho bạn", icon: Sparkles },
  { key: "following", label: "Đang theo dõi", icon: Users },
  { key: "media", label: "Đa phương tiện", icon: ImageIcon },
];

export function FeedView() {
  const [activeTab, setActiveTab] = useState<FeedTabKey>("all");
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { showToast, toast } = useToast();

  const loadFeed = useCallback(
    async (tab: FeedTabKey, cursor?: string | null) => {
      if (cursor) {
        setLoadingMore(true);
      } else {
        setLoading(true);
      }
      setError(null);

      try {
        const queryParams = new URLSearchParams();
        if (tab !== "all") {
          queryParams.set("filter", tab);
        }
        if (cursor) {
          queryParams.set("cursor", cursor);
        }

        const queryString = queryParams.toString() ? `?${queryParams.toString()}` : "";
        const res = await clientFetch<{
          data: Post[];
          meta?: CursorMeta;
        }>(`/api/proxy/feed${queryString}`);

        if (cursor) {
          setPosts((prev) => [...prev, ...(res.data || [])]);
        } else {
          setPosts(res.data || []);
        }

        setNextCursor(res.meta?.nextCursor || null);
      } catch (err) {
        if (err instanceof ApiRequestError) {
          setError(err.message);
        } else {
          setError("Không thể tải bảng tin. Vui lòng thử lại sau.");
        }
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    },
    []
  );

  useEffect(() => {
    loadFeed(activeTab);
  }, [activeTab, loadFeed]);

  const handlePostCreated = (newPost: Post) => {
    setPosts((prev) => [newPost, ...prev]);
    showToast("Đã đăng bài viết thành công!");
  };

  const handlePostDeleted = (postId: string) => {
    setPosts((prev) => prev.filter((p) => p.id !== postId));
  };

  const handlePostHidden = (postId: string) => {
    setPosts((prev) => prev.filter((p) => p.id !== postId));
  };

  return (
    <div className="flex justify-center gap-8 w-full pb-16">
      <div className="flex-1 max-w-2xl min-w-0">
        {/* Stories Tray */}
        <StoryTray />

        {/* Feed Filter Tabs */}
      <div className="flex items-center gap-2 p-1.5 bg-surface-muted dark:bg-surface-dark-muted/80 rounded-2xl mb-6 select-none">
        {FEED_TABS.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.key;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key)}
              className={`flex-1 py-2 px-3 rounded-xl text-xs sm:text-sm font-semibold flex items-center justify-center gap-2 transition duration-150 ${
                isActive
                  ? "bg-white dark:bg-surface-dark text-brand dark:text-brand-light shadow-sm"
                  : "text-appText-secondary dark:text-appText-dark-secondary hover:text-appText-primary dark:hover:text-white"
              }`}
            >
              <Icon className="w-4 h-4" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Create Post Card */}
      <CreatePostCard onPostCreated={handlePostCreated} />

      {/* Posts Stream */}
      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-appText-secondary">
          <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin mb-3" />
          <span className="text-sm font-medium">Đang tải bảng tin...</span>
        </div>
      ) : error ? (
        <div className="py-16 text-center px-4 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-8 shadow-sm">
          <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-2 opacity-80" />
          <p className="text-sm text-appText-primary dark:text-appText-dark-primary font-medium mb-4">
            {error}
          </p>
          <button
            onClick={() => loadFeed(activeTab)}
            className="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-brand hover:bg-brand-hover transition"
          >
            Thử lại
          </button>
        </div>
      ) : posts.length === 0 ? (
        <div className="py-16 text-center px-4 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-8 shadow-sm">
          <Inbox className="w-12 h-12 text-appText-secondary/60 dark:text-appText-dark-secondary/50 mx-auto mb-3" />
          <h3 className="text-base font-semibold text-appText-primary dark:text-appText-dark-primary">
            {activeTab === "following"
              ? "Chưa có bài viết từ người bạn theo dõi"
              : activeTab === "media"
              ? "Chưa có bài viết đa phương tiện nào"
              : "Chưa có bài viết nào trên bảng tin"}
          </h3>
          <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-1 max-w-sm mx-auto">
            {activeTab === "following"
              ? "Hãy theo dõi bạn bè hoặc kết nối thêm để cập nhật tin mới từ họ."
              : "Hãy chia sẻ khoảnh khắc đầu tiên của bạn ngay bây giờ!"}
          </p>
        </div>
      ) : (
        <div className="space-y-5">
          {posts.map((post) => (
            <PostCard
              key={post.id}
              post={post}
              onPostDeleted={handlePostDeleted}
              onPostHidden={handlePostHidden}
            />
          ))}

          {/* Load More pagination button */}
          {nextCursor && (
            <div className="pt-4 text-center">
              <button
                type="button"
                disabled={loadingMore}
                onClick={() => loadFeed(activeTab, nextCursor)}
                className="px-6 py-2.5 rounded-full border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-primary dark:text-appText-dark-primary text-sm font-semibold shadow-sm transition disabled:opacity-50 inline-flex items-center gap-2"
              >
                {loadingMore ? (
                  <>
                    <div className="w-4 h-4 border-2 border-brand border-t-transparent rounded-full animate-spin" />
                    <span>Đang tải thêm...</span>
                  </>
                ) : (
                  <>
                    <RotateCw className="w-4 h-4" />
                    <span>Xem thêm bài viết</span>
                  </>
                )}
              </button>
            </div>
          )}
        </div>
      )}
      </div>

      {/* Right Sidebar on desktop (xl+) */}
      <RightSidebar />
    </div>
  );
}
