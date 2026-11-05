"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, MailCheck, Send, CheckCircle2 } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";

export default function VerifyEmailPage() {
  const router = useRouter();
  const { user, updateUser, refreshUser } = useAuth();

  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);
    setInfo(null);

    const trimmedCode = code.trim();
    if (!/^\d{6}$/.test(trimmedCode)) {
      setError("Mã gồm 6 chữ số");
      return;
    }

    setBusy(true);
    try {
      await clientFetch("/api/proxy/auth/email/verify", {
        method: "POST",
        body: JSON.stringify({ code: trimmedCode }),
      });

      updateUser({ emailVerified: true });
      setSuccess(true);
      await refreshUser();

      setTimeout(() => {
        router.push("/");
      }, 1500);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể xác thực mã. Vui lòng thử lại.");
      }
    } finally {
      setBusy(false);
    }
  };

  const handleResend = async () => {
    if (resending || busy) return;
    setError(null);
    setInfo(null);
    setResending(true);

    try {
      await clientFetch("/api/proxy/auth/email/verification", {
        method: "POST",
      });
      setInfo("Đã gửi mã mới");
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gửi lại mã xác thực. Vui lòng thử lại sau.");
      }
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-muted dark:bg-appBg-dark px-4 py-12">
      <div className="w-full max-w-md bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm p-8">
        <div className="mb-6">
          <Link
            href="/"
            className="inline-flex items-center text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light transition"
          >
            <ArrowLeft className="w-4 h-4 mr-1.5" />
            Về trang chủ
          </Link>
        </div>

        <div className="text-center mb-6">
          <div className="w-12 h-12 rounded-2xl bg-brand-soft dark:bg-brand/20 text-brand dark:text-brand-light flex items-center justify-center mx-auto mb-3">
            <MailCheck className="w-6 h-6" />
          </div>
          <h1 className="text-2xl font-bold text-appText-primary dark:text-white">
            Xác thực email
          </h1>
          <p className="mt-2 text-sm text-appText-secondary dark:text-appText-dark-secondary">
            {user?.email
              ? `Nhập mã 6 số đã gửi tới ${user.email}.`
              : "Nhập mã 6 số đã gửi tới email của bạn."}
          </p>
        </div>

        {info && (
          <div className="mb-6 p-4 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-sm text-emerald-600 dark:text-emerald-400">
            {info}
          </div>
        )}

        {error && (
          <div className="mb-6 p-4 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-sm text-red-600 dark:text-red-400">
            {error}
          </div>
        )}

        {success ? (
          <div className="text-center py-6">
            <div className="w-12 h-12 rounded-full bg-emerald-100 dark:bg-emerald-900/50 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mx-auto mb-3">
              <CheckCircle2 className="w-6 h-6" />
            </div>
            <h2 className="text-lg font-semibold text-appText-primary dark:text-white mb-1">
              Xác thực thành công!
            </h2>
            <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary">
              Đang chuyển hướng về trang chủ...
            </p>
          </div>
        ) : (
          <form onSubmit={handleVerify} className="space-y-4">
            <div>
              <label
                htmlFor="code"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Mã xác thực
              </label>
              <input
                id="code"
                type="text"
                maxLength={6}
                required
                autoFocus
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="123456"
                className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm font-mono tracking-widest text-center"
              />
            </div>

            <div className="pt-2">
              <button
                type="submit"
                disabled={busy}
                className="w-full py-2.5 px-4 rounded-xl font-medium text-white bg-brand hover:bg-brand-hover focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2 disabled:opacity-50 transition shadow-sm"
              >
                {busy ? (
                  <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin mx-auto" />
                ) : (
                  "Xác nhận"
                )}
              </button>
            </div>

            <div className="text-center pt-2">
              <button
                type="button"
                disabled={resending || busy}
                onClick={handleResend}
                className="inline-flex items-center text-sm font-medium text-brand dark:text-brand-light hover:underline"
              >
                <Send className="w-3.5 h-3.5 mr-1" />
                {resending ? "Đang gửi..." : "Gửi lại mã"}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
