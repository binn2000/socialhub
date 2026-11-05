"use client";

import React, { useState, useEffect } from "react";
import { X, Search, MessageSquare, Users, AlertCircle } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "@/context/AuthContext";
import { ApiRequestError } from "@/lib/errors";
import type { UserListItem, Conversation } from "@/types";

interface NewConversationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConversationStarted: (conversation: Conversation) => void;
}

export function NewConversationModal({
  isOpen,
  onClose,
  onConversationStarted,
}: NewConversationModalProps) {
  const { user: currentUser } = useAuth();

  const [friends, setFriends] = useState<UserListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [startingId, setStartingId] = useState<string | null>(null);

  useEffect(() => {
    if (!isOpen || !currentUser?.id) return;

    const loadFriends = async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await clientFetch<{ data: UserListItem[] }>(
          `/api/proxy/users/${currentUser.id}/friends`
        );
        setFriends(res.data || []);
      } catch (err) {
        if (err instanceof ApiRequestError) {
          setError(err.message);
        } else {
          setError("Không thể tải danh sách bạn bè");
        }
      } finally {
        setLoading(false);
      }
    };

    loadFriends();
  }, [isOpen, currentUser?.id]);

  if (!isOpen) return null;

  const handleSelectFriend = async (friend: UserListItem) => {
    if (startingId) return;
    setStartingId(friend.id);
    setError(null);

    try {
      const res = await clientFetch<{ data: Conversation }>(
        "/api/proxy/conversations",
        {
          method: "POST",
          body: JSON.stringify({ userId: friend.id }),
        }
      );

      onConversationStarted(res.data);
      onClose();
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể bắt đầu cuộc trò chuyện");
      }
    } finally {
      setStartingId(null);
    }
  };

  const filteredFriends = friends.filter(
    (f) =>
      f.name.toLowerCase().includes(search.toLowerCase()) ||
      f.username.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
      <div
        className="w-full max-w-md bg-white dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark flex flex-col max-h-[85vh] overflow-hidden animate-scale-in"
        role="dialog"
        aria-modal="true"
      >
        {/* Header */}
        <div className="p-4 sm:px-6 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <h2 className="text-base font-bold text-appText-primary dark:text-white">
            Tin nhắn mới
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Search friend */}
        <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
            <input
              type="text"
              autoFocus
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm kiếm bạn bè..."
              className="w-full pl-10 pr-4 py-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-surface-muted dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
            />
          </div>
        </div>

        {error && (
          <div className="m-4 mb-0 p-3 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-xs text-red-600 dark:text-red-400 flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* Friends list */}
        <div className="flex-1 overflow-y-auto p-4 divide-y divide-appBorder-light dark:divide-appBorder-dark/80">
          {loading ? (
            <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-6 h-6 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tải bạn bè...</span>
            </div>
          ) : filteredFriends.length === 0 ? (
            <div className="py-12 text-center text-appText-secondary">
              <Users className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
                {search ? "Không tìm thấy bạn bè nào" : "Bạn chưa có bạn bè để nhắn tin"}
              </p>
              <p className="text-xs text-appText-secondary mt-0.5">
                Chỉ những người đã là bạn bè mới có thể gửi tin nhắn.
              </p>
            </div>
          ) : (
            filteredFriends.map((friend) => (
              <button
                key={friend.id}
                type="button"
                disabled={startingId === friend.id}
                onClick={() => handleSelectFriend(friend)}
                className="w-full py-3 px-2 flex items-center gap-3 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 rounded-xl transition"
              >
                <UserAvatar
                  name={friend.name}
                  imageUrl={friend.avatarUrl}
                  size="md"
                  isOnline={friend.isOnline ?? false}
                />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-appText-primary dark:text-white truncate">
                    {friend.name}
                  </p>
                  <p className="text-xs text-appText-secondary truncate">
                    @{friend.username}
                  </p>
                </div>
                {startingId === friend.id ? (
                  <div className="w-4 h-4 border-2 border-brand border-t-transparent rounded-full animate-spin flex-shrink-0" />
                ) : (
                  <MessageSquare className="w-4 h-4 text-appText-secondary flex-shrink-0" />
                )}
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
