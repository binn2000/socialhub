"use client";

import React, { useState } from "react";
import Link from "next/link";
import { AlertTriangle, ArrowRight, X } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

export function EmailVerificationBanner() {
  const { user } = useAuth();
  const [dismissed, setDismissed] = useState(false);

  // If unauthenticated or already verified or dismissed for this session
  if (!user || user.emailVerified || dismissed) {
    return null;
  }

  return (
    <div className="bg-amber-50 dark:bg-amber-950/50 border-b border-amber-200 dark:border-amber-900/60 text-amber-800 dark:text-amber-200 px-4 py-2.5 sm:px-6 transition-colors">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-3 text-xs sm:text-sm">
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <AlertTriangle className="w-4 h-4 text-amber-600 dark:text-amber-400 flex-shrink-0" />
          <span className="truncate">
            <strong className="font-semibold">Email chưa được xác thực.</strong>{" "}
            <span className="hidden sm:inline">
              Vui lòng xác thực email để bảo vệ tài khoản tốt hơn.
            </span>
          </span>
        </div>

        <div className="flex items-center gap-2 flex-shrink-0">
          <Link
            href="/verify-email"
            className="inline-flex items-center gap-1 font-semibold text-amber-900 dark:text-amber-100 hover:underline"
          >
            <span>Xác thực ngay</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </Link>
          <button
            onClick={() => setDismissed(true)}
            aria-label="Đóng thông báo"
            className="p-1 rounded-lg hover:bg-amber-100 dark:hover:bg-amber-900/50 text-amber-600 dark:text-amber-400 transition"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </div>
  );
}
