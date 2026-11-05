"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { X, UserCheck, UserPlus, Users, RotateCw } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import { useAuth } from "@/context/AuthContext";
import type { UserListItem, CursorMeta } from "@/types";

interface FollowListModalProps {
  userId: string;
  type: "followers" | "following";
  isOpen: boolean;
  onClose: () => void;
}

export function FollowListModal({
  userId,
  type,
  isOpen,
  onClose,
}: FollowListModalProps) {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [togglingIds, setTogglingIds] = useState<Set<string>>(new Set());
  const [unfollowTarget, setUnfollowTarget] = useState<UserListItem | null>(null);

  const title = type === "followers" ? "Người theo dõi" : "Đang theo dõi";

  const loadList = async (cursor?: string | null) => {
    if (cursor) {
      setLoadingMore(true);
    } else {
      setLoading(true);
    }
    setError(null);

    try {
      const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{
        data: UserListItem[];
        meta?: CursorMeta;
      }>(`/api/proxy/users/${userId}/${type}${query}`);

      if (cursor) {
        setUsers((prev) => [...prev, ...(res.data || [])]);
      } else {
        setUsers(res.data || []);
      }

      setNextCursor(res.meta?.nextCursor || null);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError(`Không thể tải danh sách ${title.toLowerCase()}`);
      }
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadList();
    } else {
      setUsers([]);
      setNextCursor(null);
    }
  }, [isOpen, userId, type]);

  if (!isOpen) return null;

  const executeToggleFollow = async (targetUser: UserListItem, nextIsFollowing: boolean) => {
    if (togglingIds.has(targetUser.id)) return;

    setTogglingIds((prev) => new Set(prev).add(targetUser.id));

    // Optimistic update
    setUsers((prev) =>
      prev.map((u) =>
        u.id === targetUser.id ? { ...u, isFollowing: nextIsFollowing } : u
      )
    );

    try {
      await clientFetch(`/api/proxy/users/${targetUser.id}/follow`, {
        method: nextIsFollowing ? "PUT" : "DELETE",
      });
    } catch {
      // Revert on error
      setUsers((prev) =>
        prev.map((u) =>
          u.id === targetUser.id ? { ...u, isFollowing: !nextIsFollowing } : u
        )
      );
    } finally {
      setTogglingIds((prev) => {
        const next = new Set(prev);
        next.delete(targetUser.id);
        return next;
      });
    }
  };

  const handleToggleFollow = (targetUser: UserListItem) => {
    if (targetUser.isFollowing) {
      setUnfollowTarget(targetUser);
    } else {
      executeToggleFollow(targetUser, true);
    }
  };

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
            {title}
          </h2>
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

        {/* User list */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-6 divide-y divide-appBorder-light dark:divide-appBorder-dark/80">
          {loading ? (
            <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tải danh sách...</span>
            </div>
          ) : users.length === 0 ? (
            <div className="py-16 text-center text-appText-secondary">
              <Users className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-medium text-appText-secondary dark:text-appText-dark-primary">
                Chưa có ai trong danh sách này
              </p>
            </div>
          ) : (
            users.map((item) => {
              const isMe = currentUser?.id === item.id;
              const isToggling = togglingIds.has(item.id);

              return (
                <div
                  key={item.id}
                  className="py-3 flex items-center justify-between gap-3 first:pt-0 last:pb-0"
                >
                  <Link
                    href={`/profile/${item.id}`}
                    onClick={onClose}
                    className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-80 transition"
                  >
                    <UserAvatar
                      name={item.name}
                      imageUrl={item.avatarUrl}
                      size="sm"
                      isOnline={item.isOnline ?? false}
                    />

                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-semibold text-appText-primary dark:text-white truncate">
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

                  {!isMe && (
                    <button
                      type="button"
                      disabled={isToggling}
                      onClick={() => handleToggleFollow(item)}
                      className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition flex items-center gap-1.5 flex-shrink-0 ${
                        item.isFollowing
                          ? "border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                          : "bg-brand hover:bg-brand-hover text-white shadow-sm"
                      }`}
                    >
                      {item.isFollowing ? (
                        <>
                          <UserCheck className="w-3.5 h-3.5" />
                          <span>Đang theo dõi</span>
                        </>
                      ) : (
                        <>
                          <UserPlus className="w-3.5 h-3.5" />
                          <span>Theo dõi</span>
                        </>
                      )}
                    </button>
                  )}
                </div>
              );
            })
          )}

          {nextCursor && (
            <div className="pt-4 text-center">
              <button
                type="button"
                disabled={loadingMore}
                onClick={() => loadList(nextCursor)}
                className="text-xs text-brand dark:text-brand-light font-semibold hover:underline inline-flex items-center gap-1"
              >
                {loadingMore ? "Đang tải thêm..." : "Xem thêm"}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Unfollow Confirm Modal */}
      <ConfirmModal
        isOpen={Boolean(unfollowTarget)}
        onClose={() => setUnfollowTarget(null)}
        onConfirm={() => {
          if (unfollowTarget) {
            executeToggleFollow(unfollowTarget, false);
          }
        }}
        title={`Bỏ theo dõi ${unfollowTarget?.name}?`}
        message={`Bạn sẽ không còn nhìn thấy bài viết của ${unfollowTarget?.name} trên bảng tin của mình nữa.`}
        confirmText="Bỏ theo dõi"
        variant="warning"
        icon="unfollow"
      />
    </div>
  );
}
