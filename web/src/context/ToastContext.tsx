"use client";

import React, { createContext, useContext, useState, useCallback, useRef } from "react";
import { CheckCircle2, AlertCircle, Info, AlertTriangle, X } from "lucide-react";

export type ToastType = "success" | "error" | "info" | "warning";

export interface ToastOptions {
  type?: ToastType;
  duration?: number; // ms, default 3000
  undoAction?: () => void;
  undoLabel?: string;
}

export interface ToastItem {
  id: string;
  message: string;
  type: ToastType;
  duration: number;
  undoAction?: () => void;
  undoLabel?: string;
}

interface ToastContextValue {
  showToast: (message: string, optionsOrUndo?: ToastOptions | (() => void)) => void;
  toast: {
    success: (message: string, options?: Omit<ToastOptions, "type">) => void;
    error: (message: string, options?: Omit<ToastOptions, "type">) => void;
    info: (message: string, options?: Omit<ToastOptions, "type">) => void;
    warning: (message: string, options?: Omit<ToastOptions, "type">) => void;
  };
  dismissToast: (id: string) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const timersRef = useRef<Map<string, NodeJS.Timeout>>(new Map());

  const dismissToast = useCallback((id: string) => {
    const timer = timersRef.current.get(id);
    if (timer) {
      clearTimeout(timer);
      timersRef.current.delete(id);
    }
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const showToast = useCallback(
    (message: string, optionsOrUndo?: ToastOptions | (() => void)) => {
      const options: ToastOptions =
        typeof optionsOrUndo === "function"
          ? { undoAction: optionsOrUndo }
          : optionsOrUndo || {};

      const id = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
      const duration = options?.duration ?? 3000;
      const type = options?.type ?? "success";

      const newToast: ToastItem = {
        id,
        message,
        type,
        duration,
        undoAction: options?.undoAction,
        undoLabel: options?.undoLabel ?? "Hoàn tác",
      };

      // Keep max 4 concurrent toasts
      setToasts((prev) => [...prev.slice(-3), newToast]);

      if (duration > 0) {
        const timer = setTimeout(() => {
          dismissToast(id);
        }, duration);
        timersRef.current.set(id, timer);
      }
    },
    [dismissToast]
  );

  const toast = {
    success: useCallback(
      (msg: string, opts?: Omit<ToastOptions, "type">) => showToast(msg, { ...opts, type: "success" }),
      [showToast]
    ),
    error: useCallback(
      (msg: string, opts?: Omit<ToastOptions, "type">) => showToast(msg, { ...opts, type: "error" }),
      [showToast]
    ),
    info: useCallback(
      (msg: string, opts?: Omit<ToastOptions, "type">) => showToast(msg, { ...opts, type: "info" }),
      [showToast]
    ),
    warning: useCallback(
      (msg: string, opts?: Omit<ToastOptions, "type">) => showToast(msg, { ...opts, type: "warning" }),
      [showToast]
    ),
  };

  return (
    <ToastContext.Provider value={{ showToast, toast, dismissToast }}>
      {children}
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return ctx;
}

function ToastContainer({
  toasts,
  onDismiss,
}: {
  toasts: ToastItem[];
  onDismiss: (id: string) => void;
}) {
  if (toasts.length === 0) return null;

  return (
    <div
      role="region"
      aria-label="Thông báo ứng dụng"
      className="fixed z-[9999] bottom-20 md:bottom-6 right-4 sm:right-6 left-4 sm:left-auto flex flex-col gap-2 max-w-sm w-full pointer-events-none"
    >
      {toasts.map((item) => (
        <ToastCard key={item.id} item={item} onDismiss={onDismiss} />
      ))}
    </div>
  );
}

function ToastCard({
  item,
  onDismiss,
}: {
  item: ToastItem;
  onDismiss: (id: string) => void;
}) {
  const icons = {
    success: <CheckCircle2 size={18} className="text-emerald-500 shrink-0" />,
    error: <AlertCircle size={18} className="text-rose-500 shrink-0" />,
    info: <Info size={18} className="text-brand shrink-0" />,
    warning: <AlertTriangle size={18} className="text-amber-500 shrink-0" />,
  };

  const borders = {
    success: "border-emerald-500/20 dark:border-emerald-500/30",
    error: "border-rose-500/20 dark:border-rose-500/30",
    info: "border-brand/20 dark:border-brand/30",
    warning: "border-amber-500/20 dark:border-amber-500/30",
  };

  return (
    <div
      role="alert"
      className={`pointer-events-auto flex items-center justify-between gap-3 px-4 py-3 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur-md rounded-2xl border ${borders[item.type]} shadow-xl shadow-black/10 dark:shadow-black/40 text-appText-primary dark:text-white animate-toast-in transition-all`}
    >
      <div className="flex items-center gap-2.5 min-w-0 flex-1">
        {icons[item.type]}
        <span className="text-xs sm:text-sm font-semibold truncate leading-tight">
          {item.message}
        </span>
      </div>

      <div className="flex items-center gap-1.5 shrink-0">
        {item.undoAction && (
          <button
            type="button"
            onClick={() => {
              item.undoAction?.();
              onDismiss(item.id);
            }}
            className="text-xs font-bold text-brand hover:text-brand-light px-2 py-1 rounded-lg hover:bg-brand/10 transition active:scale-95"
          >
            {item.undoLabel || "Hoàn tác"}
          </button>
        )}

        <button
          type="button"
          onClick={() => onDismiss(item.id)}
          className="p-1 rounded-full text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
          title="Đóng"
        >
          <X size={14} />
        </button>
      </div>
    </div>
  );
}
