"use client";

import React, { useEffect, useState } from "react";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import { Check, UserPlus } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { clientFetch } from "@/lib/client-api";
import type { UserListItem } from "@/types";

const card =
  "rounded-2xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark shadow-card";

function WidgetSkeleton({ rows }: { rows: number }) {
  return (
    <div className="space-y-3 animate-pulse">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-surface-muted dark:bg-surface-dark-muted" />
          <div className="flex-1 space-y-1.5">
            <div className="h-3 w-2/3 rounded bg-surface-muted dark:bg-surface-dark-muted" />
            <div className="h-2.5 w-1/3 rounded bg-surface-muted dark:bg-surface-dark-muted" />
          </div>
        </div>
      ))}
    </div>
  );
}

/** Desktop-only (xl+) companion column: online friends, people you may know, footer links. */
export function RightSidebar() {
  const { user } = useAuth();
  const { toast } = useToast();
  const router = useRouter();

  const [friends, setFriends] = useState<UserListItem[]>([]);
  const [friendsLoading, setFriendsLoading] = useState(true);
  const [suggestions, setSuggestions] = useState<UserListItem[]>([]);
  const [suggestionsLoading, setSuggestionsLoading] = useState(true);
  const [requested, setRequested] = useState<Set<string>>(new Set());
  const [openingChat, setOpeningChat] = useState<string | null>(null);

  useEffect(() => {
    if (!user?.id) return;
    clientFetch<{ data: UserListItem[] }>(`/api/proxy/users/${user.id}/friends?limit=30`)
      .then((res) => {
        // Online first, then by name.
        const list = [...(res.data || [])].sort(
          (a, b) => Number(Boolean(b.isOnline)) - Number(Boolean(a.isOnline)) || a.name.localeCompare(b.name, "vi")
        );
        setFriends(list);
      })
      .catch(() => setFriends([]))
      .finally(() => setFriendsLoading(false));

    clientFetch<{ data: UserListItem[] }>("/api/proxy/users/suggestions?limit=3")
      .then((res) => setSuggestions((res.data || []).slice(0, 3)))
      .catch(() => setSuggestions([]))
      .finally(() => setSuggestionsLoading(false));
  }, [user?.id]);

  const openChat = async (friend: UserListItem) => {
    if (openingChat) return;
    setOpeningChat(friend.id);
    try {
      const res = await clientFetch<{ data: { id: string } }>("/api/proxy/conversations", {
        method: "POST",
        body: JSON.stringify({ userId: friend.id }),
      });
      router.push(`/messages/${res.data.id}`);
    } catch {
      router.push(`/profile/${friend.id}`);
    } finally {
      setOpeningChat(null);
    }
  };

  const sendRequest = async (target: UserListItem) => {
    if (requested.has(target.id)) return;
    setRequested((prev) => new Set(prev).add(target.id));
    try {
      await clientFetch("/api/proxy/friend-requests", {
        method: "POST",
        body: JSON.stringify({ userId: target.id }),
      });
      toast.success(`Đã gửi lời mời kết bạn đến ${target.name}`);
    } catch {
      setRequested((prev) => {
        const next = new Set(prev);
        next.delete(target.id);
        return next;
      });
      toast.error(`Không thể gửi lời mời đến ${target.name}`);
    }
  };

  const onlineCount = friends.filter((f) => f.isOnline).length;
  const visibleFriends = friends.slice(0, 8);

  return (
    <aside className="hidden xl:block w-80 shrink-0">
      <div className="sticky top-[5.5rem] space-y-5 max-h-[calc(100vh-6.5rem)] overflow-y-auto scrollbar-none pb-6">
        {/* Online friends */}
        <section className={`${card} p-4`}>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
              Bạn bè trực tuyến
            </h2>
            {onlineCount > 0 && (
              <span className="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-success/10 text-success">
                {onlineCount} đang hoạt động
              </span>
            )}
          </div>

          {friendsLoading ? (
            <WidgetSkeleton rows={4} />
          ) : visibleFriends.length === 0 ? (
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary py-2">
              Kết bạn để thấy ai đang hoạt động.
            </p>
          ) : (
            <ul className="-mx-2">
              {visibleFriends.map((friend) => (
                <li key={friend.id}>
                  <button
                    type="button"
                    onClick={() => openChat(friend)}
                    disabled={openingChat === friend.id}
                    title={`Nhắn tin cho ${friend.name}`}
                    className="w-full flex items-center gap-3 px-2 py-1.5 rounded-xl text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition disabled:opacity-60"
                  >
                    <UserAvatar src={friend.avatarUrl} name={friend.name} size="sm" isOnline={Boolean(friend.isOnline)} />
                    <span className="flex-1 min-w-0 text-sm font-medium text-appText-primary dark:text-appText-dark-primary truncate">
                      {friend.name}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}

          {friends.length > visibleFriends.length && (
            <NextLink href="/friends" className="block mt-2 text-xs font-semibold text-brand dark:text-brand-light hover:underline">
              Xem tất cả bạn bè
            </NextLink>
          )}
        </section>

        {/* People you may know */}
        {(suggestionsLoading || suggestions.length > 0) && (
          <section className={`${card} p-4`}>
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
                Những người bạn có thể biết
              </h2>
              <NextLink href="/friends" className="text-xs font-semibold text-brand dark:text-brand-light hover:underline">
                Xem thêm
              </NextLink>
            </div>

            {suggestionsLoading ? (
              <WidgetSkeleton rows={3} />
            ) : (
              <ul className="space-y-3">
                {suggestions.map((s) => {
                  const sent = requested.has(s.id);
                  return (
                    <li key={s.id} className="flex items-center gap-3">
                      <NextLink href={`/profile/${s.id}`} className="shrink-0">
                        <UserAvatar src={s.avatarUrl} name={s.name} size="sm" />
                      </NextLink>
                      <div className="flex-1 min-w-0">
                        <NextLink
                          href={`/profile/${s.id}`}
                          className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary truncate hover:underline"
                        >
                          {s.name}
                        </NextLink>
                        <p className="text-[11px] text-appText-secondary dark:text-appText-dark-secondary truncate">
                          {s.mutualFriendsCount ? `${s.mutualFriendsCount} bạn chung` : `@${s.username}`}
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={() => sendRequest(s)}
                        disabled={sent}
                        title={sent ? "Đã gửi lời mời" : "Thêm bạn bè"}
                        className={`shrink-0 w-8 h-8 rounded-full flex items-center justify-center transition active:scale-90 ${
                          sent
                            ? "bg-success/10 text-success"
                            : "bg-brand-soft dark:bg-brand/15 text-brand dark:text-brand-light hover:bg-brand hover:text-white"
                        }`}
                      >
                        {sent ? <Check size={15} /> : <UserPlus size={15} />}
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </section>
        )}

        {/* Footer */}
        <footer className="px-2 text-[11px] leading-relaxed text-appText-secondary dark:text-appText-dark-secondary">
          <nav className="flex flex-wrap gap-x-3 gap-y-1 mb-1">
            <NextLink href="/terms" className="hover:underline">Điều khoản</NextLink>
            <NextLink href="/privacy" className="hover:underline">Quyền riêng tư</NextLink>
            <NextLink href="/explore" className="hover:underline">Khám phá</NextLink>
          </nav>
          <p>© {new Date().getFullYear()} SocialHub</p>
        </footer>
      </div>
    </aside>
  );
}
