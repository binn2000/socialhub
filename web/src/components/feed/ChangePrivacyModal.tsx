"use client";

import React, { useState } from "react";
import { Globe, Users, Lock, Check, X } from "lucide-react";
import { PRIVACY_OPTIONS } from "@/lib/post-constants";
import { clientFetch } from "@/lib/client-api";
import type { Post, Privacy } from "@/types";
import { ApiRequestError } from "@/lib/errors";

interface ChangePrivacyModalProps {
  post: Post | null;
  isOpen: boolean;
  onClose: () => void;
  onPrivacyChanged: (postId: string, newPrivacy: Privacy) => void;
}

export function ChangePrivacyModal({
  post,
  isOpen,
  onClose,
  onPrivacyChanged,
}: ChangePrivacyModalProps) {
  const [selectedPrivacy, setSelectedPrivacy] = useState<Privacy>(
    post?.privacy || "public"
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Sync state when post changes
  React.useEffect(() => {
    if (post) {
      setSelectedPrivacy(post.privacy);
      setError(null);
    }
  }, [post]);

  if (!isOpen || !post) return null;

  const handleSave = async () => {
    if (selectedPrivacy === post.privacy) {
      onClose();
      return;
    }

    setSaving(true);
    setError(null);

    try {
      await clientFetch<{ data: Post }>(`/api/proxy/posts/${post.id}`, {
        method: "PATCH",
        body: JSON.stringify({ privacy: selectedPrivacy }),
      });

      onPrivacyChanged(post.id, selectedPrivacy);
      onClose();
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể cập nhật quyền riêng tư. Vui lòng thử lại.");
      }
    } finally {
      setSaving(false);
    }
  };

  const getIcon = (privacy: Privacy) => {
    switch (privacy) {
      case "friends":
        return <Users className="w-5 h-5" />;
      case "only_me":
        return <Lock className="w-5 h-5" />;
      case "public":
      default:
        return <Globe className="w-5 h-5" />;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
      <div
        className="w-full max-w-md bg-white dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark p-6 overflow-hidden animate-scale-in"
        role="dialog"
        aria-modal="true"
      >
        <div className="flex items-center justify-between pb-4 border-b border-appBorder-light dark:border-appBorder-dark">
          <h2 className="text-lg font-bold text-appText-primary dark:text-white">
            Ai có thể xem bài viết này?
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {error && (
          <div className="mt-4 p-3 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-xs text-red-600 dark:text-red-400">
            {error}
          </div>
        )}

        <div className="py-4 space-y-2">
          {PRIVACY_OPTIONS.map((opt) => {
            const isSelected = selectedPrivacy === opt.value;
            return (
              <button
                key={opt.value}
                type="button"
                onClick={() => setSelectedPrivacy(opt.value)}
                className={`w-full flex items-center justify-between p-3.5 rounded-xl border text-left transition ${
                  isSelected
                    ? "border-brand bg-brand-soft/50 dark:bg-brand/10 text-brand-dark dark:text-brand-soft"
                    : "border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted/50 text-appText-primary dark:text-appText-dark-primary"
                }`}
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`p-2 rounded-xl ${
                      isSelected
                        ? "bg-brand text-white"
                        : "bg-surface-muted dark:bg-surface-dark-muted text-appText-secondary"
                    }`}
                  >
                    {getIcon(opt.value)}
                  </div>
                  <div>
                    <p className="text-sm font-semibold">{opt.label}</p>
                    <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
                      {opt.description}
                    </p>
                  </div>
                </div>

                {isSelected && (
                  <Check className="w-5 h-5 text-brand dark:text-brand-light flex-shrink-0" />
                )}
              </button>
            );
          })}
        </div>

        <div className="flex items-center justify-end gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            disabled={saving}
            className="px-4 py-2 rounded-xl text-sm font-medium text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
          >
            Hủy
          </button>
          <button
            type="button"
            onClick={handleSave}
            disabled={saving}
            className="px-4 py-2 rounded-xl text-sm font-medium text-white bg-brand hover:bg-brand-hover disabled:opacity-50 transition shadow-sm"
          >
            {saving ? "Đang lưu..." : "Xác nhận"}
          </button>
        </div>
      </div>
    </div>
  );
}
