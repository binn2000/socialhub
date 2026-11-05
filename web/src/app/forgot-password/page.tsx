"use client";

import React, { useState, Suspense } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { ArrowLeft, KeyRound, Mail, CheckCircle2 } from "lucide-react";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";

function ForgotPasswordForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialEmail = searchParams.get("email") || "";

  const [email, setEmail] = useState(initialEmail);
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [codeSent, setCodeSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSendCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setError("Vui lòng nhập email");
      return;
    }

    setBusy(true);
    try {
      await clientFetch("/api/auth/password/forgot", {
        method: "POST",
        body: JSON.stringify({ email: trimmedEmail }),
      });
      setCodeSent(true);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gửi yêu cầu. Vui lòng kiểm tra lại kết nối.");
      }
    } finally {
      setBusy(false);
    }
  };

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);

    const trimmedCode = code.trim();
    if (!/^\d{6}$/.test(trimmedCode)) {
      setError("Mã gồm 6 chữ số");
      return;
    }

    if (password.length < 8) {
      setError("Mật khẩu cần ít nhất 8 ký tự");
      return;
    }

    setBusy(true);
    try {
      await clientFetch("/api/auth/password/reset", {
        method: "POST",
        body: JSON.stringify({
          email: email.trim(),
          code: trimmedCode,
          password,
        }),
      });

      router.push("/login?notice=" + encodeURIComponent("Đã đổi mật khẩu, hãy đăng nhập lại"));
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Đổi mật khẩu thất bại. Vui lòng kiểm tra lại mã xác nhận.");
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="w-full max-w-md bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm p-8">
      <div className="mb-6">
        <Link
          href="/login"
          className="inline-flex items-center text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light transition"
        >
          <ArrowLeft className="w-4 h-4 mr-1.5" />
          Quay lại đăng nhập
        </Link>
      </div>

      <div className="text-center mb-6">
        <div className="w-12 h-12 rounded-2xl bg-brand-soft dark:bg-brand/20 text-brand dark:text-brand-light flex items-center justify-center mx-auto mb-3">
          <KeyRound className="w-6 h-6" />
        </div>
        <h1 className="text-2xl font-bold text-appText-primary dark:text-white">
          Quên mật khẩu
        </h1>
        <p className="mt-2 text-sm text-appText-secondary dark:text-appText-dark-secondary">
          {codeSent
            ? "Nếu email này có tài khoản, chúng tôi đã gửi mã 6 số. Nhập mã và mật khẩu mới."
            : "Nhập email của tài khoản, chúng tôi sẽ gửi mã xác nhận."}
        </p>
      </div>

      {error && (
        <div className="mb-6 p-4 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-sm text-red-600 dark:text-red-400">
          {error}
        </div>
      )}

      {codeSent ? (
        <form onSubmit={handleResetPassword} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1">
              Email
            </label>
            <input
              type="email"
              value={email}
              readOnly
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-surface-muted dark:bg-surface-dark-muted/60 text-appText-secondary text-sm cursor-not-allowed"
            />
          </div>

          <div>
            <label
              htmlFor="code"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Mã xác nhận (6 chữ số)
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

          <div>
            <label
              htmlFor="new-password"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Mật khẩu mới
            </label>
            <input
              id="new-password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Tối thiểu 8 ký tự"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm"
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
                "Đổi mật khẩu"
              )}
            </button>
          </div>

          <div className="text-center pt-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                setCodeSent(false);
                setCode("");
                setPassword("");
              }}
              className="text-xs text-brand dark:text-brand-light hover:underline"
            >
              Gửi lại mã hoặc đổi email
            </button>
          </div>
        </form>
      ) : (
        <form onSubmit={handleSendCode} className="space-y-4">
          <div>
            <label
              htmlFor="email"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Email
            </label>
            <div className="relative">
              <input
                id="email"
                type="email"
                required
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="name@example.com"
                className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm"
              />
            </div>
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
                "Gửi mã xác nhận"
              )}
            </button>
          </div>
        </form>
      )}
    </div>
  );
}

export default function ForgotPasswordPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-muted dark:bg-appBg-dark px-4 py-12">
      <Suspense
        fallback={
          <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin" />
        }
      >
        <ForgotPasswordForm />
      </Suspense>
    </div>
  );
}
