"use client";

import React, { useState, useEffect, useCallback, Suspense, useRef } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
  Search,
  Compass,
  TrendingUp,
  Video,
  Sparkles,
  Users,
  FileText,
  X,
  Loader2,
  AlertCircle,
  UserPlus,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { PostCard } from "@/components/feed/PostCard";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { RightSidebar } from "@/components/layout/RightSidebar";
import { clientFetch } from "@/lib/client-api";
import type { Post, CursorMeta, UserListItem } from "@/types";

type ExploreFilter = "for_you" | "trending" | "short_video";
type SearchTab = "posts" | "users";

const EXPLORE_FILTERS: { id: ExploreFilter; label: string; icon: LucideIcon }[] = [
  { id: "for_you", label: "Dành cho bạn", icon: Sparkles },
  { id: "trending", label: "Đang thịnh hành", icon: TrendingUp },
  { id: "short_video", label: "Video ngắn", icon: Video },
];

function ExploreContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialQ = searchParams.get("q") || "";

  const [query, setQuery] = useState(initialQ);
  const [activeFilter, setActiveFilter] = useState<ExploreFilter>("for_you");
  const [activeTab, setActiveTab] = useState<SearchTab>("posts");

  // Posts state
  const [posts, setPosts] = useState<Post[]>([]);
  const [loadingPosts, setLoadingPosts] = useState(true);
  const [loadingMorePosts, setLoadingMorePosts] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);

  // Users search state
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(false);

  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Load posts from /explore
  const loadPosts = useCallback(
    async (filter: ExploreFilter, qText: string, cursor?: string | null) => {
      if (cursor) {
        setLoadingMorePosts(true);
      } else {
        setLoadingPosts(true);
      }

      try {
        const params = new URLSearchParams();
        params.set("filter", filter);
        if (qText.trim()) {
          params.set("q", qText.trim());
        }
        if (cursor) {
          params.set("cursor", cursor);
        }

        const res = await clientFetch<{
          data: Post[];
          meta?: CursorMeta;
        }>(`/api/proxy/explore?${params.toString()}`);

        if (cursor) {
          setPosts((prev) => [...prev, ...(res.data || [])]);
        } else {
          setPosts(res.data || []);
        }
        setNextCursor(res.meta?.nextCursor || null);
      } catch {
        if (!cursor) setPosts([]);
      } finally {
        setLoadingPosts(false);
        setLoadingMorePosts(false);
      }
    },
    []
  );

  // Load users from /users?q=...
  const loadUsers = useCallback(async (qText: string) => {
    if (!qText.trim()) {
      setUsers([]);
      return;
    }

    setLoadingUsers(true);
    try {
      const res = await clientFetch<{ data: UserListItem[] }>(
        `/api/proxy/users?q=${encodeURIComponent(qText.trim())}`
      );
      setUsers(res.data || []);
    } catch {
      setUsers([]);
    } finally {
      setLoadingUsers(false);
    }
  }, []);

  // Update URL search query without reloading
  const updateUrlQuery = (qVal: string) => {
    const params = new URLSearchParams(window.location.search);
    if (qVal.trim()) {
      params.set("q", qVal.trim());
    } else {
      params.delete("q");
    }
    const newPath = params.toString() ? `/explore?${params.toString()}` : "/explore";
    window.history.replaceState(null, "", newPath);
  };

  // Initial load
  useEffect(() => {
    loadPosts(activeFilter, query);
    if (query.trim()) {
      loadUsers(query);
    }
  }, [activeFilter, loadPosts, loadUsers]); // eslint-disable-line react-hooks/exhaustive-deps

  // Search input change handler
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setQuery(val);
    updateUrlQuery(val);

    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    debounceTimerRef.current = setTimeout(() => {
      loadPosts(activeFilter, val);
      loadUsers(val);
    }, 350);
  };

  const handleClearSearch = () => {
    setQuery("");
    updateUrlQuery("");
    loadPosts(activeFilter, "");
    setUsers([]);
  };

  const handlePostDeleted = (deletedId: string) => {
    setPosts((prev) => prev.filter((p) => p.id !== deletedId));
  };

  const handlePostUpdated = (updated: Post) => {
    setPosts((prev) => prev.map((p) => (p.id === updated.id ? updated : p)));
  };

  const isSearching = Boolean(query.trim());

  return (
    <div className="flex justify-center gap-8 w-full pb-16">
      <div className="flex-1 max-w-2xl min-w-0">
        {/* Header bar */}
      <div className="mb-6">
        <div className="flex items-center gap-2.5 mb-1.5">
          <div className="w-9 h-9 rounded-xl bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand">
            <Compass size={20} />
          </div>
          <h1 className="text-2xl font-bold text-appText-primary dark:text-appText-dark-primary">
            Khám phá
          </h1>
        </div>
        <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
          Tìm kiếm bài viết thịnh hành, video ngắn và kết nối bạn bè mới
        </p>
      </div>

      {/* Search Input Box */}
      <div className="relative mb-5">
        <Search
          size={18}
          className="absolute left-4 top-1/2 -translate-y-1/2 text-appText-secondary dark:text-appText-dark-secondary"
        />
        <input
          type="text"
          value={query}
          onChange={handleSearchChange}
          placeholder="Tìm kiếm nội dung, tác giả hoặc bạn bè..."
          className="w-full pl-11 pr-10 py-3 rounded-2xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark focus:border-brand focus:ring-2 focus:ring-brand/20 text-sm text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary outline-none transition shadow-sm"
        />
        {query && (
          <button
            onClick={handleClearSearch}
            className="absolute right-3.5 top-1/2 -translate-y-1/2 p-1 text-appText-secondary hover:text-appText-primary rounded-full transition"
            title="Xóa tìm kiếm"
          >
            <X size={16} />
          </button>
        )}
      </div>

      {/* Search result tabs: only show when user is searching */}
      {isSearching && (
        <div className="flex items-center gap-2 mb-4 border-b border-appBorder-light dark:border-appBorder-dark pb-2">
          <button
            onClick={() => setActiveTab("posts")}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold transition ${
              activeTab === "posts"
                ? "bg-brand text-white shadow-sm shadow-brand/25"
                : "text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
            }`}
          >
            <FileText size={15} />
            <span>Bài viết</span>
          </button>
          <button
            onClick={() => setActiveTab("users")}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold transition ${
              activeTab === "users"
                ? "bg-brand text-white shadow-sm shadow-brand/25"
                : "text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
            }`}
          >
            <Users size={15} />
            <span>Mọi người ({users.length})</span>
          </button>
        </div>
      )}

      {/* Category filter chips: show when tab is posts */}
      {activeTab === "posts" && (
        <div className="flex items-center gap-2 overflow-x-auto pb-3 mb-4 scrollbar-none">
          {EXPLORE_FILTERS.map((f) => {
            const Icon = f.icon;
            const isSelected = activeFilter === f.id;
            return (
              <button
                key={f.id}
                onClick={() => {
                  setActiveFilter(f.id);
                  loadPosts(f.id, query);
                }}
                className={`flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition active:scale-95 ${
                  isSelected
                    ? "bg-brand text-white shadow-sm shadow-brand/25"
                    : "bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:text-appText-primary"
                }`}
              >
                <Icon size={14} />
                <span>{f.label}</span>
              </button>
            );
          })}
        </div>
      )}

      {/* Main Content: Users Tab */}
      {isSearching && activeTab === "users" && (
        <div>
          {loadingUsers ? (
            <div className="py-16 flex flex-col items-center justify-center">
              <Loader2 className="w-8 h-8 text-brand animate-spin mb-3" />
              <p className="text-xs text-appText-secondary">Đang tìm kiếm người dùng...</p>
            </div>
          ) : users.length === 0 ? (
            <div className="py-16 text-center bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark p-8">
              <Users size={40} className="mx-auto mb-3 text-appText-secondary opacity-40" />
              <h3 className="text-base font-bold text-appText-primary dark:text-appText-dark-primary mb-1">
                Không tìm thấy người dùng phù hợp
              </h3>
              <p className="text-xs text-appText-secondary max-w-sm mx-auto">
                Không có ai khớp với từ khóa &ldquo;{query}&rdquo;. Thử tìm bằng tên hiển thị hoặc username khác.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {users.map((u) => (
                <div
                  key={u.id}
                  className="flex items-center justify-between p-3.5 bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark hover:shadow-sm transition"
                >
                  <Link
                    href={`/profile/${u.id}`}
                    className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-85 transition"
                  >
                    <UserAvatar
                      name={u.name}
                      src={u.avatarUrl}
                      size="md"
                      isOnline={u.isOnline}
                    />
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                        {u.name}
                      </h4>
                      <p className="text-xs text-appText-secondary truncate">
                        @{u.username}
                      </p>
                    </div>
                  </Link>

                  <Link
                    href={`/profile/${u.id}`}
                    className="px-3.5 py-1.5 rounded-full bg-brand/10 dark:bg-brand/20 hover:bg-brand hover:text-white text-brand text-xs font-semibold transition shrink-0 ml-2"
                  >
                    Xem hồ sơ
                  </Link>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Main Content: Posts Tab */}
      {activeTab === "posts" && (
        <div>
          {loadingPosts ? (
            <div className="py-16 flex flex-col items-center justify-center">
              <Loader2 className="w-8 h-8 text-brand animate-spin mb-3" />
              <p className="text-xs text-appText-secondary">Đang tải bài viết...</p>
            </div>
          ) : posts.length === 0 ? (
            <div className="py-16 text-center bg-surface-light dark:bg-surface-dark rounded-2xl border border-appBorder-light dark:border-appBorder-dark p-8">
              <Sparkles size={40} className="mx-auto mb-3 text-appText-secondary opacity-40" />
              <h3 className="text-base font-bold text-appText-primary dark:text-appText-dark-primary mb-1">
                {isSearching
                  ? `Không tìm thấy bài viết nào cho "${query}"`
                  : "Chưa có bài viết nào trong mục này"}
              </h3>
              <p className="text-xs text-appText-secondary max-w-sm mx-auto">
                {isSearching
                  ? "Hãy thử tìm kiếm với các từ khóa phổ biến hơn."
                  : "Khi có bài viết công khai hoặc video mới, chúng sẽ xuất hiện ở đây."}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {posts.map((post) => (
                <PostCard
                  key={post.id}
                  post={post}
                  onPostDeleted={handlePostDeleted}
                  onPostHidden={handlePostDeleted}
                />
              ))}

              {/* Load More Button */}
              {nextCursor && (
                <div className="pt-4 text-center">
                  <button
                    onClick={() => loadPosts(activeFilter, query, nextCursor)}
                    disabled={loadingMorePosts}
                    className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition active:scale-95 disabled:opacity-50"
                  >
                    {loadingMorePosts && (
                      <Loader2 size={14} className="animate-spin" />
                    )}
                    <span>Tải thêm bài viết</span>
                  </button>
                </div>
              )}
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

export default function ExplorePage() {
  return (
    <Suspense
      fallback={
        <div className="max-w-3xl mx-auto py-16 flex items-center justify-center">
          <Loader2 className="w-8 h-8 text-brand animate-spin" />
        </div>
      }
    >
      <ExploreContent />
    </Suspense>
  );
}
