"use client";

import React, { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import {
  Users,
  UserPlus,
  UserCheck,
  Search,
  X,
  MessageCircle,
  Sparkles,
  Check,
  AlertCircle,
  Inbox,
  Clock,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import type { UserListItem, FriendRequest, CursorMeta } from "@/types";

type FriendsCategory = "all" | "connected" | "suggestions";

export default function FriendsPage() {
  const { user: currentUser } = useAuth();

  const [category, setCategory] = useState<FriendsCategory>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");

  // Data states
  const [requests, setRequests] = useState<FriendRequest[]>([]);
  const [requestsLoading, setRequestsLoading] = useState(false);

  const [friends, setFriends] = useState<UserListItem[]>([]);
  const [friendsLoading, setFriendsLoading] = useState(false);
  const [friendsCursor, setFriendsCursor] = useState<string | null>(null);

  const [suggestions, setSuggestions] = useState<UserListItem[]>([]);
  const [suggestionsLoading, setSuggestionsLoading] = useState(false);
  const [suggestionsCursor, setSuggestionsCursor] = useState<string | null>(null);

  const [searchResults, setSearchResults] = useState<UserListItem[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchCursor, setSearchCursor] = useState<string | null>(null);

  // Optimistic tracking for sent requests
  const [pendingUserIds, setPendingUserIds] = useState<Set<string>>(new Set());
  const [actionBusy, setActionBusy] = useState(false);
  const { showToast, toast } = useToast();

  const searchTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Debounce search query
  useEffect(() => {
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    searchTimerRef.current = setTimeout(() => {
      setDebouncedQuery(searchQuery.trim());
    }, 350);

    return () => {
      if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    };
  }, [searchQuery]);

  // 1. Load incoming Friend Requests
  const loadRequests = useCallback(async () => {
    setRequestsLoading(true);
    try {
      const res = await clientFetch<{ data: FriendRequest[] }>(
        "/api/proxy/friend-requests"
      );
      setRequests(res.data || []);
    } catch {
      setRequests([]);
    } finally {
      setRequestsLoading(false);
    }
  }, []);

  // 2. Load Friends List
  const loadFriends = useCallback(
    async (cursor?: string | null) => {
      if (!currentUser?.id) return;
      setFriendsLoading(true);
      try {
        const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
        const res = await clientFetch<{
          data: UserListItem[];
          meta?: CursorMeta;
        }>(`/api/proxy/users/${currentUser.id}/friends${query}`);

        if (cursor) {
          setFriends((prev) => [...prev, ...(res.data || [])]);
        } else {
          setFriends(res.data || []);
        }
        setFriendsCursor(res.meta?.nextCursor || null);
      } catch {
        setFriends([]);
      } finally {
        setFriendsLoading(false);
      }
    },
    [currentUser?.id]
  );

  // 3. Load Suggestions ("Người bạn có thể biết")
  const loadSuggestions = useCallback(async (cursor?: string | null) => {
    setSuggestionsLoading(true);
    try {
      const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{
        data: UserListItem[];
        meta?: CursorMeta;
      }>(`/api/proxy/users/suggestions${query}`);

      if (cursor) {
        setSuggestions((prev) => [...prev, ...(res.data || [])]);
      } else {
        setSuggestions(res.data || []);
      }
      setSuggestionsCursor(res.meta?.nextCursor || null);
    } catch {
      setSuggestions([]);
    } finally {
      setSuggestionsLoading(false);
    }
  }, []);

  // 4. Search Users
  const searchUsers = useCallback(async (queryText: string, cursor?: string | null) => {
    if (!queryText) {
      setSearchResults([]);
      setSearchCursor(null);
      return;
    }
    setSearchLoading(true);
    try {
      const params = new URLSearchParams({ q: queryText });
      if (cursor) params.set("cursor", cursor);

      const res = await clientFetch<{
        data: UserListItem[];
        meta?: CursorMeta;
      }>(`/api/proxy/users?${params.toString()}`);

      if (cursor) {
        setSearchResults((prev) => [...prev, ...(res.data || [])]);
      } else {
        setSearchResults(res.data || []);
      }
      setSearchCursor(res.meta?.nextCursor || null);
    } catch {
      setSearchResults([]);
    } finally {
      setSearchLoading(false);
    }
  }, []);

  useEffect(() => {
    loadRequests();
    loadFriends();
    loadSuggestions();
  }, [loadRequests, loadFriends, loadSuggestions]);

  useEffect(() => {
    if (debouncedQuery) {
      searchUsers(debouncedQuery);
    } else {
      setSearchResults([]);
    }
  }, [debouncedQuery, searchUsers]);

  // Request actions
  const handleAcceptRequest = async (request: FriendRequest) => {
    if (actionBusy) return;
    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friend-requests/${request.id}/accept`, {
        method: "POST",
      });
      setRequests((prev) => prev.filter((r) => r.id !== request.id));
      toast.success(`Đã chấp nhận lời mời kết bạn của ${request.sender.name}`);
      loadFriends();
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleDeclineRequest = async (request: FriendRequest) => {
    if (actionBusy) return;
    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friend-requests/${request.id}`, {
        method: "DELETE",
      });
      setRequests((prev) => prev.filter((r) => r.id !== request.id));
      toast.info(`Đã từ chối lời mời kết bạn của ${request.sender.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleSendFriendRequest = async (targetUser: UserListItem) => {
    if (actionBusy || pendingUserIds.has(targetUser.id)) return;
    setActionBusy(true);
    setPendingUserIds((prev) => new Set(prev).add(targetUser.id));

    try {
      await clientFetch("/api/proxy/friend-requests", {
        method: "POST",
        body: JSON.stringify({ userId: targetUser.id }),
      });
      toast.success(`Đã gửi lời mời kết bạn đến ${targetUser.name}`);
    } catch (err) {
      setPendingUserIds((prev) => {
        const next = new Set(prev);
        next.delete(targetUser.id);
        return next;
      });
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleUnfriend = async (friend: UserListItem) => {
    if (actionBusy) return;
    const confirmed = window.confirm(`Hủy kết bạn với ${friend.name}?`);
    if (!confirmed) return;

    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friends/${friend.id}`, {
        method: "DELETE",
      });
      setFriends((prev) => prev.filter((f) => f.id !== friend.id));
      toast.info(`Đã hủy kết bạn với ${friend.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const isSearching = debouncedQuery.length > 0;

  return (
    <div className="max-w-4xl mx-auto pb-16">
      {/* Header & Search */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-appText-primary dark:text-white mb-3">
          Bạn bè
        </h1>

        {/* Search input */}
        <div className="relative max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm kiếm bạn bè, tên hoặc @username..."
            className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {/* Category Filter Pills (hidden during active search) */}
      {!isSearching && (
        <div className="flex items-center gap-2 mb-6 overflow-x-auto pb-1 select-none">
          {(
            [
              { key: "all", label: "Tất cả mọi người" },
              {
                key: "connected",
                label: `Danh sách bạn bè (${friends.length})`,
              },
              {
                key: "suggestions",
                label: "Người bạn có thể biết",
              },
            ] as const
          ).map((item) => {
            const isActive = category === item.key;
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => setCategory(item.key)}
                className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition whitespace-nowrap ${
                  isActive
                    ? "bg-brand text-white shadow-sm"
                    : "bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                }`}
              >
                {item.label}
              </button>
            );
          })}
        </div>
      )}

      {/* Active Search Results */}
      {isSearching ? (
        <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
          <h2 className="text-base font-bold text-appText-primary dark:text-white mb-4 flex items-center gap-2">
            <Search className="w-4 h-4 text-brand" />
            <span>Kết quả tìm kiếm cho &ldquo;{debouncedQuery}&rdquo;</span>
          </h2>

          {searchLoading && searchResults.length === 0 ? (
            <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tìm kiếm...</span>
            </div>
          ) : searchResults.length === 0 ? (
            <div className="py-12 text-center text-appText-secondary">
              <Inbox className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
                Không tìm thấy người dùng nào phù hợp
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {searchResults.map((user) => {
                const isPending =
                  pendingUserIds.has(user.id) ||
                  user.friendship?.status === "pending_outgoing";
                const isFriend = user.friendship?.status === "friends";

                return (
                  <div
                    key={user.id}
                    className="p-4 rounded-xl border border-appBorder-light dark:border-appBorder-dark flex items-center justify-between gap-3 hover:border-appBorder-light dark:hover:border-appBorder-dark transition"
                  >
                    <Link
                      href={`/profile/${user.id}`}
                      className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-80 transition"
                    >
                      <UserAvatar
                        name={user.name}
                        imageUrl={user.avatarUrl}
                        size="md"
                        isOnline={user.isOnline ?? false}
                      />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                          {user.name}
                        </p>
                        <p className="text-xs text-appText-secondary truncate">
                          @{user.username}
                        </p>
                      </div>
                    </Link>

                    {isFriend ? (
                      <span className="text-xs font-semibold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                        <Check className="w-3.5 h-3.5" />
                        <span>Bạn bè</span>
                      </span>
                    ) : isPending ? (
                      <span className="text-xs font-medium text-appText-secondary flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        <span>Đã gửi</span>
                      </span>
                    ) : (
                      <button
                        type="button"
                        onClick={() => handleSendFriendRequest(user)}
                        className="px-3 py-1.5 rounded-xl bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm transition flex items-center gap-1.5"
                      >
                        <UserPlus className="w-3.5 h-3.5" />
                        <span>Thêm bạn</span>
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-8">
          {/* Section: Incoming Friend Requests (Show on all or connected) */}
          {requests.length > 0 && (
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <h2 className="text-base font-bold text-appText-primary dark:text-white">
                    Lời mời kết bạn
                  </h2>
                  <span className="px-2 py-0.5 rounded-full bg-red-100 dark:bg-red-950/60 text-red-600 dark:text-red-400 font-bold text-xs">
                    {requests.length}
                  </span>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {requests.map((req) => (
                  <div
                    key={req.id}
                    className="p-4 rounded-xl border border-appBorder-light dark:border-appBorder-dark hover:border-appBorder-light dark:hover:border-appBorder-dark flex flex-col justify-between gap-3 transition"
                  >
                    <Link
                      href={`/profile/${req.sender.id}`}
                      className="flex items-center gap-3 min-w-0 hover:opacity-80 transition"
                    >
                      <UserAvatar
                        name={req.sender.name}
                        imageUrl={req.sender.avatarUrl}
                        size="md"
                      />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                          {req.sender.name}
                        </p>
                        <p className="text-xs text-appText-secondary truncate">
                          @{req.sender.username} · {timeAgo(req.createdAt)}
                        </p>
                      </div>
                    </Link>

                    <div className="flex items-center gap-2 pt-1">
                      <button
                        type="button"
                        onClick={() => handleAcceptRequest(req)}
                        className="flex-1 py-1.5 px-3 rounded-xl bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm transition"
                      >
                        Chấp nhận
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeclineRequest(req)}
                        className="flex-1 py-1.5 px-3 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-xs font-semibold transition"
                      >
                        Từ chối
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Section: People you may know ("Người bạn có thể biết") */}
          {(category === "all" || category === "suggestions") && (
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-amber-500" />
                  <h2 className="text-base font-bold text-appText-primary dark:text-white">
                    Người bạn có thể biết
                  </h2>
                </div>
              </div>

              {suggestionsLoading && suggestions.length === 0 ? (
                <div className="py-12 flex flex-col items-center justify-center text-appText-secondary">
                  <div className="w-6 h-6 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
                  <span className="text-xs">Đang tải gợi ý...</span>
                </div>
              ) : suggestions.length === 0 ? (
                <p className="text-sm text-appText-secondary py-4 text-center">
                  Hiện chưa có thêm gợi ý kết bạn mới
                </p>
              ) : (
                <>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {suggestions.map((item) => {
                      const isPending =
                        pendingUserIds.has(item.id) ||
                        item.friendship?.status === "pending_outgoing";

                      return (
                        <div
                          key={item.id}
                          className="p-4 rounded-xl border border-appBorder-light dark:border-appBorder-dark flex items-center justify-between gap-3 hover:border-appBorder-light dark:hover:border-appBorder-dark transition"
                        >
                          <Link
                            href={`/profile/${item.id}`}
                            className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-80 transition"
                          >
                            <UserAvatar
                              name={item.name}
                              imageUrl={item.avatarUrl}
                              size="md"
                              isOnline={item.isOnline ?? false}
                            />
                            <div className="min-w-0 flex-1">
                              <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                                {item.name}
                              </p>
                              <p className="text-xs text-appText-secondary truncate">
                                @{item.username}
                                {item.mutualFriendsCount > 0 && (
                                  <span> · {item.mutualFriendsCount} bạn chung</span>
                                )}
                              </p>
                            </div>
                          </Link>

                          {isPending ? (
                            <span className="text-xs font-medium text-appText-secondary flex items-center gap-1 flex-shrink-0">
                              <Clock className="w-3.5 h-3.5" />
                              <span>Đã gửi</span>
                            </span>
                          ) : (
                            <button
                              type="button"
                              onClick={() => handleSendFriendRequest(item)}
                              className="px-3.5 py-1.5 rounded-xl bg-brand hover:bg-brand-hover text-white text-xs font-semibold shadow-sm transition flex items-center gap-1.5 flex-shrink-0"
                            >
                              <UserPlus className="w-3.5 h-3.5" />
                              <span>Thêm bạn</span>
                            </button>
                          )}
                        </div>
                      );
                    })}
                  </div>

                  {suggestionsCursor && (
                    <div className="pt-6 text-center">
                      <button
                        type="button"
                        disabled={suggestionsLoading}
                        onClick={() => loadSuggestions(suggestionsCursor)}
                        className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                      >
                        {suggestionsLoading ? "Đang tải..." : "Xem thêm gợi ý"}
                      </button>
                    </div>
                  )}
                </>
              )}
            </div>
          )}

          {/* Section: Friends List ("Danh sách bạn bè") */}
          {(category === "all" || category === "connected") && (
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Users className="w-5 h-5 text-brand" />
                  <h2 className="text-base font-bold text-appText-primary dark:text-white">
                    Danh sách bạn bè ({friends.length})
                  </h2>
                </div>
              </div>

              {friendsLoading && friends.length === 0 ? (
                <div className="py-12 flex flex-col items-center justify-center text-appText-secondary">
                  <div className="w-6 h-6 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
                  <span className="text-xs">Đang tải danh sách bạn bè...</span>
                </div>
              ) : friends.length === 0 ? (
                <p className="text-sm text-appText-secondary py-4 text-center">
                  Bạn chưa có người bạn nào. Hãy kết nối thêm bạn bè nhé!
                </p>
              ) : (
                <>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    {friends.map((friend) => (
                      <div
                        key={friend.id}
                        className="p-4 rounded-xl border border-appBorder-light dark:border-appBorder-dark flex items-center justify-between gap-3 hover:border-appBorder-light dark:hover:border-appBorder-dark transition"
                      >
                        <Link
                          href={`/profile/${friend.id}`}
                          className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-80 transition"
                        >
                          <UserAvatar
                            name={friend.name}
                            imageUrl={friend.avatarUrl}
                            size="md"
                            isOnline={friend.isOnline ?? false}
                          />
                          <div className="min-w-0 flex-1">
                            <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                              {friend.name}
                            </p>
                            <p className="text-xs text-appText-secondary truncate">
                              @{friend.username}
                            </p>
                          </div>
                        </Link>

                        <div className="flex items-center gap-2">
                          <Link
                            href={`/messages?user=${friend.id}`}
                            className="p-2 rounded-lg bg-brand-soft dark:bg-brand/20 text-brand dark:text-brand-light hover:bg-brand/15 transition"
                            title="Nhắn tin"
                          >
                            <MessageCircle className="w-4 h-4" />
                          </Link>

                          <button
                            type="button"
                            onClick={() => handleUnfriend(friend)}
                            className="p-2 rounded-lg text-appText-secondary hover:text-red-600 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                            title="Hủy kết bạn"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>

                  {friendsCursor && (
                    <div className="pt-6 text-center">
                      <button
                        type="button"
                        disabled={friendsLoading}
                        onClick={() => loadFriends(friendsCursor)}
                        className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                      >
                        {friendsLoading ? "Đang tải..." : "Xem thêm bạn bè"}
                      </button>
                    </div>
                  )}
                </>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
