"use client";

import React, { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Bell,
  CheckCheck,
  Inbox,
  AlertCircle,
  RotateCw,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { getNotificationMeta } from "@/lib/notification-helpers";
import { clientFetch } from "@/lib/client-api";
import { useBadges } from "@/context/BadgeContext";
import { useToast } from "@/context/ToastContext";
import { ApiRequestError } from "@/lib/errors";
import type { Notification, CursorMeta } from "@/types";

type NotificationCategory = "all" | "interactions" | "friends";

export default function NotificationsPage() {
  const router = useRouter();
  const { markNotificationsReadLocally, refreshBadges } = useBadges();
  const { toast } = useToast();

  const [category, setCategory] = useState<NotificationCategory>("all");
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [markingAll, setMarkingAll] = useState(false);

  const loadNotifications = useCallback(
    async (cat: NotificationCategory, cursor?: string | null) => {
      if (cursor) {
        setLoadingMore(true);
      } else {
        setLoading(true);
      }
      setError(null);

      try {
        const queryParams = new URLSearchParams();
        if (cat !== "all") {
          queryParams.set("category", cat);
        }
        if (cursor) {
          queryParams.set("cursor", cursor);
        }

        const queryString = queryParams.toString() ? `?${queryParams.toString()}` : "";
        const res = await clientFetch<{
          data: Notification[];
          meta?: CursorMeta;
        }>(`/api/proxy/notifications${queryString}`);

        if (cursor) {
          setNotifications((prev) => [...prev, ...(res.data || [])]);
        } else {
          setNotifications(res.data || []);
        }
        setNextCursor(res.meta?.nextCursor || null);
      } catch (err) {
        if (err instanceof ApiRequestError) {
          setError(err.message);
        } else {
          setError("Không thể tải thông báo");
        }
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    },
    []
  );

  useEffect(() => {
    loadNotifications(category);
  }, [category, loadNotifications]);

  const handleMarkAllRead = async () => {
    if (markingAll) return;
    setMarkingAll(true);
    markNotificationsReadLocally();
    try {
      await clientFetch("/api/proxy/notifications/read", { method: "POST" });
      setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
      toast.success("Đã đánh dấu tất cả thông báo là đã đọc");
    } catch {
      toast.error("Không thể đánh dấu đã đọc lúc này");
      refreshBadges();
    } finally {
      setMarkingAll(false);
    }
  };

  const handleNotificationClick = async (n: Notification) => {
    if (!n.isRead) {
      // Mark single read
      setNotifications((prev) =>
        prev.map((item) => (item.id === n.id ? { ...item, isRead: true } : item))
      );
      try {
        await clientFetch(`/api/proxy/notifications/${n.id}/read`, {
          method: "POST",
        });
        refreshBadges();
      } catch {}
    }

    // Navigate to target
    if (n.postId) {
      router.push(`/posts/${n.postId}`);
    } else if (n.actor?.id) {
      router.push(`/profile/${n.actor.id}`);
    }
  };

  const hasUnread = notifications.some((n) => !n.isRead);

  return (
    <div className="max-w-2xl mx-auto pb-16">
      {/* Header bar */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-appText-primary dark:text-white">
            Thông báo
          </h1>
          <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-0.5">
            Cập nhật hoạt động mới nhất liên quan đến bạn
          </p>
        </div>

        {hasUnread && (
          <button
            type="button"
            disabled={markingAll}
            onClick={handleMarkAllRead}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
            title="Đánh dấu tất cả đã đọc"
          >
            <CheckCheck className="w-4 h-4 text-brand dark:text-brand-light" />
            <span>Đã đọc tất cả</span>
          </button>
        )}
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-2 p-1.5 bg-surface-muted dark:bg-surface-dark-muted/80 rounded-2xl mb-6 select-none">
        {(
          [
            { key: "all", label: "Tất cả" },
            { key: "interactions", label: "Tương tác" },
            { key: "friends", label: "Kết bạn" },
          ] as const
        ).map((tab) => {
          const isActive = category === tab.key;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setCategory(tab.key)}
              className={`flex-1 py-2 px-3 rounded-xl text-xs sm:text-sm font-semibold transition ${
                isActive
                  ? "bg-white dark:bg-surface-dark text-brand dark:text-brand-light shadow-sm"
                  : "text-appText-secondary dark:text-appText-dark-secondary hover:text-appText-primary dark:hover:text-white"
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Notifications List */}
      <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center text-appText-secondary">
            <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin mb-3" />
            <span className="text-sm font-medium">Đang tải thông báo...</span>
          </div>
        ) : error ? (
          <div className="py-16 text-center px-4">
            <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-2 opacity-80" />
            <p className="text-sm text-appText-primary dark:text-appText-dark-primary font-medium mb-4">
              {error}
            </p>
            <button
              onClick={() => loadNotifications(category)}
              className="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-brand hover:bg-brand-hover transition"
            >
              Thử lại
            </button>
          </div>
        ) : notifications.length === 0 ? (
          <div className="py-20 text-center px-4">
            <Inbox className="w-12 h-12 text-appText-secondary/60 dark:text-appText-dark-secondary/50 mx-auto mb-3" />
            <h3 className="text-base font-semibold text-appText-primary dark:text-appText-dark-primary">
              Chưa có thông báo nào
            </h3>
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-1 max-w-sm mx-auto">
              Khi ai đó thích, bình luận, kết bạn hoặc theo dõi bạn, thông báo sẽ xuất hiện tại đây.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-appBorder-light dark:divide-appBorder-dark/80">
            {notifications.map((n) => {
              const meta = getNotificationMeta(n.type, n.reaction);
              const Icon = meta.icon;

              return (
                <div
                  key={n.id}
                  onClick={() => handleNotificationClick(n)}
                  className={`p-4 sm:p-5 flex items-start gap-3.5 cursor-pointer transition ${
                    n.isRead
                      ? "hover:bg-surface-muted/70 dark:hover:bg-surface-dark-muted/40"
                      : "bg-brand-soft/40 dark:bg-brand/20 hover:bg-brand-soft/70 dark:hover:bg-brand/10"
                  }`}
                >
                  {/* Actor Avatar with Type Icon Badge */}
                  <div className="relative flex-shrink-0">
                    <UserAvatar
                      name={n.actor.name}
                      imageUrl={n.actor.avatarUrl}
                      size="md"
                    />
                    <div
                      className={`absolute -bottom-1 -right-1 p-1 rounded-full border-2 border-white dark:border-appBorder-dark ${meta.iconColor}`}
                    >
                      {meta.emoji ? (
                        <span className="block w-3 h-3 text-[10px] leading-3 text-center">{meta.emoji}</span>
                      ) : (
                        <Icon className="w-3 h-3" />
                      )}
                    </div>
                  </div>

                  {/* Notification Content */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-appText-primary dark:text-appText-dark-primary leading-snug">
                      <strong className="font-bold text-appText-primary dark:text-white">
                        {n.actor.name}
                      </strong>{" "}
                      <span>{meta.description}</span>
                    </p>

                    {n.relatedContent && (
                      <p className="mt-1 text-xs text-appText-secondary dark:text-appText-dark-secondary line-clamp-1 italic bg-surface-muted dark:bg-surface-dark-muted/60 p-1.5 rounded-lg border border-appBorder-light dark:border-appBorder-dark">
                        &ldquo;{n.relatedContent}&rdquo;
                      </p>
                    )}

                    <span className="text-xs text-appText-secondary mt-1 block">
                      {timeAgo(n.createdAt)}
                    </span>
                  </div>

                  {/* Unread indicator dot */}
                  {!n.isRead && (
                    <div className="w-2.5 h-2.5 rounded-full bg-brand flex-shrink-0 mt-2" />
                  )}
                </div>
              );
            })}
          </div>
        )}

        {/* Next Cursor Pagination */}
        {nextCursor && (
          <div className="p-4 border-t border-appBorder-light dark:border-appBorder-dark text-center">
            <button
              type="button"
              disabled={loadingMore}
              onClick={() => loadNotifications(category, nextCursor)}
              className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition inline-flex items-center gap-1.5"
            >
              {loadingMore ? (
                <>
                  <div className="w-3.5 h-3.5 border-2 border-brand border-t-transparent rounded-full animate-spin" />
                  <span>Đang tải...</span>
                </>
              ) : (
                <>
                  <RotateCw className="w-3.5 h-3.5" />
                  <span>Xem thêm thông báo</span>
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
