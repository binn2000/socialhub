"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowLeft, UserX, ShieldAlert, Check } from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { useToast } from "@/context/ToastContext";
import type { BlockedUser } from "@/types";
import { ApiRequestError } from "@/lib/errors";

export default function BlockedUsersPage() {
  const [users, setUsers] = useState<BlockedUser[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [unblockingId, setUnblockingId] = useState<string | null>(null);
  const { toast } = useToast();

  const loadBlockedUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await clientFetch<{ data: BlockedUser[] }>("/api/proxy/me/blocks");
      setUsers(res.data || []);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể tải danh sách người đã chặn");
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBlockedUsers();
  }, []);

  const handleUnblock = async (user: BlockedUser) => {
    if (unblockingId) return;
    setUnblockingId(user.id);
    try {
      await clientFetch(`/api/proxy/users/${user.id}/block`, {
        method: "DELETE",
      });
      setUsers((prev) => (prev ? prev.filter((u) => u.id !== user.id) : []));
      toast.success(`Đã bỏ chặn ${user.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        toast.error(err.message);
      } else {
        toast.error("Không thể bỏ chặn người dùng. Vui lòng thử lại.");
      }
    } finally {
      setUnblockingId(null);
    }
  };

  return (
    <div className="max-w-2xl mx-auto py-6">
      <div className="mb-6 flex items-center justify-between">
        <Link
          href="/settings/profile"
          className="inline-flex items-center text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light transition"
        >
          <ArrowLeft className="w-4 h-4 mr-1.5" />
          Chỉnh sửa hồ sơ
        </Link>
      </div>

      <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-red-50 dark:bg-red-950/60 text-red-600 dark:text-red-400 rounded-xl">
              <UserX className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-appText-primary dark:text-white">
                Người đã chặn
              </h1>
              <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
                Những người trong danh sách này không thể xem hồ sơ hoặc nhắn tin cho bạn
              </p>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
            <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin mb-3" />
            <span className="text-sm">Đang tải danh sách...</span>
          </div>
        ) : error ? (
          <div className="py-16 text-center px-4">
            <ShieldAlert className="w-10 h-10 text-red-500 mx-auto mb-2 opacity-80" />
            <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary mb-4">{error}</p>
            <button
              onClick={loadBlockedUsers}
              className="px-4 py-2 rounded-xl text-sm font-medium text-white bg-brand hover:bg-brand-hover transition"
            >
              Thử lại
            </button>
          </div>
        ) : !users || users.length === 0 ? (
          <div className="py-16 text-center px-4">
            <UserX className="w-12 h-12 text-appText-secondary/60 dark:text-appText-dark-secondary/50 mx-auto mb-3" />
            <h3 className="text-base font-semibold text-appText-primary dark:text-appText-dark-primary">
              Bạn chưa chặn ai
            </h3>
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-1 max-w-sm mx-auto">
              Khi bạn chặn một người dùng, họ sẽ xuất hiện tại đây và bạn có thể bỏ chặn bất kỳ lúc nào.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-appBorder-light dark:divide-appBorder-dark">
            {users.map((user) => (
              <div
                key={user.id}
                className="p-4 sm:px-6 flex items-center justify-between gap-4 hover:bg-surface-muted/50 dark:hover:bg-surface-dark-muted/40 transition"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <UserAvatar
                    name={user.name}
                    imageUrl={user.avatarUrl}
                    size="md"
                  />
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-appText-primary dark:text-white truncate">
                      {user.name}
                    </p>
                    <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary truncate">
                      @{user.username}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  disabled={unblockingId === user.id}
                  onClick={() => handleUnblock(user)}
                  className="px-3.5 py-1.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-xs sm:text-sm font-medium text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted disabled:opacity-50 transition flex-shrink-0"
                >
                  {unblockingId === user.id ? "Đang xử lý..." : "Bỏ chặn"}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
