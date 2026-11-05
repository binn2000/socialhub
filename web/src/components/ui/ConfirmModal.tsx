"use client";

import React, { useState } from "react";
import { AlertTriangle, LogOut, Trash2, UserMinus, UserX, Info } from "lucide-react";

export type ConfirmVariant = "danger" | "warning" | "primary" | "neutral";

export interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void> | void;
  title: string;
  message: string | React.ReactNode;
  confirmText?: string;
  cancelText?: string;
  variant?: ConfirmVariant;
  icon?: "danger" | "warning" | "logout" | "unfriend" | "unfollow" | "trash" | "info" | React.ReactNode;
  isLoading?: boolean;
}

export function ConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = "Xác nhận",
  cancelText = "Hủy",
  variant = "danger",
  icon = "danger",
  isLoading: externalLoading = false,
}: ConfirmModalProps) {
  const [internalLoading, setInternalLoading] = useState(false);
  const loading = externalLoading || internalLoading;

  if (!isOpen) return null;

  const handleConfirm = async () => {
    if (loading) return;
    try {
      setInternalLoading(true);
      await onConfirm();
      onClose();
    } catch {
      // Keep modal open or let caller handle error
    } finally {
      setInternalLoading(false);
    }
  };

  const renderIcon = () => {
    if (React.isValidElement(icon)) return icon;

    switch (icon) {
      case "logout":
        return <LogOut className="w-5 h-5 text-amber-500" />;
      case "unfriend":
      case "unfollow":
        return <UserMinus className="w-5 h-5 text-red-500" />;
      case "trash":
        return <Trash2 className="w-5 h-5 text-red-500" />;
      case "warning":
        return <AlertTriangle className="w-5 h-5 text-amber-500" />;
      case "info":
        return <Info className="w-5 h-5 text-brand" />;
      case "danger":
      default:
        return <AlertTriangle className="w-5 h-5 text-red-500" />;
    }
  };

  const getIconWrapperClass = () => {
    switch (variant) {
      case "warning":
        return "bg-amber-100 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400";
      case "primary":
        return "bg-brand/10 dark:bg-brand/20 text-brand";
      case "neutral":
        return "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300";
      case "danger":
      default:
        return "bg-red-100 dark:bg-red-950/60 text-red-600 dark:text-red-400";
    }
  };

  const getConfirmButtonClass = () => {
    switch (variant) {
      case "warning":
        return "bg-amber-500 hover:bg-amber-600 text-white shadow-sm focus:ring-amber-400";
      case "primary":
        return "bg-brand hover:bg-brand-hover text-white shadow-sm focus:ring-brand";
      case "neutral":
        return "bg-slate-800 hover:bg-slate-900 text-white dark:bg-slate-700 dark:hover:bg-slate-600 shadow-sm";
      case "danger":
      default:
        return "bg-red-600 hover:bg-red-700 text-white shadow-sm focus:ring-red-400";
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
      onClick={(e) => {
        if (e.target === e.currentTarget && !loading) onClose();
      }}
    >
      <div
        className="w-full max-w-md bg-white dark:bg-surface-dark rounded-2xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark p-6 overflow-hidden animate-scale-in"
        role="dialog"
        aria-modal="true"
      >
        <div className="flex items-start gap-4 mb-4">
          <div className={`p-3 rounded-2xl flex-shrink-0 ${getIconWrapperClass()}`}>
            {renderIcon()}
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="text-base sm:text-lg font-bold text-appText-primary dark:text-white leading-tight">
              {title}
            </h2>
            <div className="mt-1.5 text-xs sm:text-sm text-appText-secondary dark:text-appText-dark-primary leading-relaxed">
              {message}
            </div>
          </div>
        </div>

        <div className="mt-6 flex items-center justify-end gap-3">
          <button
            type="button"
            disabled={loading}
            onClick={onClose}
            className="px-4 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-white font-medium text-xs sm:text-sm hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition disabled:opacity-50 cursor-pointer"
          >
            {cancelText}
          </button>
          <button
            type="button"
            disabled={loading}
            onClick={handleConfirm}
            className={`px-4 py-2.5 rounded-xl font-medium text-xs sm:text-sm transition disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer active:scale-95 ${getConfirmButtonClass()}`}
          >
            {loading ? (
              <>
                <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                <span>Đang xử lý...</span>
              </>
            ) : (
              <span>{confirmText}</span>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
