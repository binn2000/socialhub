"use client";

import React, { useState } from "react";
import { AlertTriangle, Lock } from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "@/context/AuthContext";
import { ApiRequestError } from "@/lib/errors";

interface DeleteAccountModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function DeleteAccountModal({ isOpen, onClose }: DeleteAccountModalProps) {
  const { logout } = useAuth();
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleDelete = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;

    if (!password.trim()) {
      setError("Vui lòng nhập mật khẩu");
      return;
    }

    setBusy(true);
    setError(null);

    try {
      await clientFetch("/api/proxy/me", {
        method: "DELETE",
        body: JSON.stringify({ password }),
      });

      // Account deleted -> logout immediately
      await logout();
    } catch (err) {
      if (err instanceof ApiRequestError) {
        if (err.code === "invalid_credentials") {
          setError("Mật khẩu không đúng");
        } else {
          setError(err.message);
        }
      } else {
        setError("Không thể xóa tài khoản. Vui lòng thử lại.");
      }
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
      <div
        className="w-full max-w-md bg-white dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark p-6 overflow-hidden animate-scale-in"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-account-title"
      >
        <div className="flex items-start gap-4 mb-4">
          <div className="p-3 bg-red-100 dark:bg-red-950/60 text-red-600 dark:text-red-400 rounded-2xl flex-shrink-0">
            <AlertTriangle className="w-6 h-6" />
          </div>
          <div>
            <h2
              id="delete-account-title"
              className="text-lg font-bold text-appText-primary dark:text-white"
            >
              Xóa tài khoản?
            </h2>
            <p className="mt-1 text-sm text-appText-secondary dark:text-appText-dark-primary leading-relaxed">
              Hồ sơ, bài viết và tin nhắn của bạn sẽ biến mất và bạn bị đăng xuất
              ngay. Nhập mật khẩu để xác nhận.
            </p>
          </div>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-xs sm:text-sm text-red-600 dark:text-red-400">
            {error}
          </div>
        )}

        <form onSubmit={handleDelete} className="space-y-4">
          <div>
            <label
              htmlFor="delete-password"
              className="block text-xs font-semibold text-appText-primary dark:text-appText-dark-primary mb-1 uppercase tracking-wider"
            >
              Mật khẩu
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
              <input
                id="delete-password"
                type="password"
                required
                autoFocus
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Nhập mật khẩu của bạn"
                className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-red-500 focus:border-transparent transition"
              />
            </div>
          </div>

          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              disabled={busy}
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-sm font-medium text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={busy}
              className="px-4 py-2 rounded-xl text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 transition shadow-sm"
            >
              {busy ? "Đang xử lý..." : "Xóa tài khoản"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
