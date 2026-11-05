"use client";

import React, { useState } from "react";
import { Flag, X, Check } from "lucide-react";
import { REPORT_REASONS, type ReportReasonValue } from "@/lib/post-constants";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";

interface ReportModalProps {
  isOpen: boolean;
  onClose: () => void;
  targetType: "post" | "comment" | "user";
  targetId: string;
  targetTitle?: string;
  onReported?: () => void;
}

export function ReportModal({
  isOpen,
  onClose,
  targetType,
  targetId,
  targetTitle = "bài viết",
  onReported,
}: ReportModalProps) {
  const [reason, setReason] = useState<ReportReasonValue>("spam");
  const [details, setDetails] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      await clientFetch("/api/proxy/reports", {
        method: "POST",
        body: JSON.stringify({
          targetType,
          targetId,
          reason,
          details: details.trim() || null,
        }),
      });

      setSuccess(true);
      onReported?.();

      setTimeout(() => {
        setSuccess(false);
        setDetails("");
        onClose();
      }, 1500);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gửi báo cáo. Vui lòng thử lại.");
      }
    } finally {
      setSubmitting(false);
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
          <div className="flex items-center gap-2.5">
            <div className="p-2 bg-red-50 dark:bg-red-950/60 text-red-600 dark:text-red-400 rounded-xl">
              <Flag className="w-4 h-4" />
            </div>
            <h2 className="text-lg font-bold text-appText-primary dark:text-white">
              Báo cáo {targetTitle}
            </h2>
          </div>
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

        {success ? (
          <div className="py-8 text-center">
            <div className="w-12 h-12 bg-emerald-100 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400 rounded-full flex items-center justify-center mx-auto mb-3">
              <Check className="w-6 h-6" />
            </div>
            <p className="text-base font-semibold text-appText-primary dark:text-white">
              Đã gửi báo cáo, cảm ơn bạn
            </p>
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-1">
              Chúng tôi sẽ xem xét nội dung này sớm nhất có thể.
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="py-4 space-y-4">
            <div>
              <label className="block text-xs font-semibold text-appText-primary dark:text-appText-dark-primary mb-2 uppercase tracking-wider">
                Chọn lý do phù hợp nhất:
              </label>
              <div className="space-y-1.5 max-h-60 overflow-y-auto pr-1">
                {REPORT_REASONS.map((r) => {
                  const isChecked = reason === r.value;
                  return (
                    <label
                      key={r.value}
                      className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition ${
                        isChecked
                          ? "border-brand bg-brand-soft/40 dark:bg-brand/10 text-brand-dark dark:text-brand-soft font-medium"
                          : "border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted/50 text-appText-primary dark:text-appText-dark-primary"
                      }`}
                    >
                      <input
                        type="radio"
                        name="reportReason"
                        value={r.value}
                        checked={isChecked}
                        onChange={() => setReason(r.value)}
                        className="h-4 w-4 text-brand focus:ring-brand"
                      />
                      <span className="text-sm">{r.label}</span>
                    </label>
                  );
                })}
              </div>
            </div>

            <div>
              <label
                htmlFor="report-details"
                className="block text-xs font-semibold text-appText-primary dark:text-appText-dark-primary mb-1 uppercase tracking-wider"
              >
                Chi tiết bổ sung (tùy chọn)
              </label>
              <textarea
                id="report-details"
                maxLength={500}
                rows={3}
                value={details}
                onChange={(e) => setDetails(e.target.value)}
                placeholder="Cung cấp thêm ngữ cảnh nếu cần..."
                className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent resize-none"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={onClose}
                disabled={submitting}
                className="px-4 py-2 rounded-xl text-sm font-medium text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
              >
                Hủy
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="px-4 py-2 rounded-xl text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 transition shadow-sm"
              >
                {submitting ? "Đang gửi..." : "Gửi báo cáo"}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
