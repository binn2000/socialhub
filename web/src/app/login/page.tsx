"use client";

import React, { useState, Suspense } from "react";
import NextLink from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Sparkles, Mail, Lock, AlertCircle, ArrowRight } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { ApiRequestError } from "@/lib/errors";

function LoginForm() {
  const { login } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const from = searchParams.get("from") || "/";
  const notice = searchParams.get("notice");

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!email.trim() || !password.trim()) {
      setError("Vui lòng nhập đầy đủ email và mật khẩu");
      return;
    }

    setLoading(true);
    try {
      await login({
        email: email.trim(),
        password: password.trim(),
        deviceName: "Web Browser",
      });
      router.push(from);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        if (err.code === "invalid_credentials") {
          setError("Email hoặc mật khẩu không chính xác");
        } else {
          setError(err.message);
        }
      } else {
        setError("Đã xảy ra lỗi kết nối máy chủ");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-md bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8 shadow-elevated">
      {/* Brand header */}
      <div className="flex flex-col items-center text-center mb-8">
        <div className="w-12 h-12 rounded-2xl bg-brand text-white flex items-center justify-center shadow-lg shadow-brand/25 mb-3">
          <Sparkles size={26} />
        </div>
        <h1 className="text-2xl font-bold text-appText-primary dark:text-appText-dark-primary">
          Chào mừng trở lại
        </h1>
        <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary mt-1">
          Đăng nhập để kết nối với bạn bè trên SocialHub
        </p>
      </div>

      {notice && (
        <div className="flex items-center gap-2.5 p-3.5 mb-5 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-emerald-600 dark:text-emerald-400 text-sm">
          <span>{notice}</span>
        </div>
      )}

      {error && (
        <div className="flex items-center gap-2.5 p-3.5 mb-5 rounded-xl bg-danger/10 border border-danger/20 text-danger text-sm">
          <AlertCircle size={18} className="flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Login form */}
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-appText-secondary dark:text-appText-dark-secondary mb-1.5 uppercase tracking-wider">
            Email
          </label>
          <div className="relative">
            <Mail
              size={18}
              className="absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary dark:text-appText-dark-secondary"
            />
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="example@gmail.com"
              className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand focus:bg-surface-light dark:focus:bg-surface-dark text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary text-sm outline-none transition-all"
            />
          </div>
        </div>

        <div>
          <div className="flex items-center justify-between mb-1.5">
            <label className="block text-xs font-semibold text-appText-secondary dark:text-appText-dark-secondary uppercase tracking-wider">
              Mật khẩu
            </label>
            <NextLink
              href="/forgot-password"
              className="text-xs text-brand hover:underline font-medium"
            >
              Quên mật khẩu?
            </NextLink>
          </div>
          <div className="relative">
            <Lock
              size={18}
              className="absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary dark:text-appText-dark-secondary"
            />
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand focus:bg-surface-light dark:focus:bg-surface-dark text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary text-sm outline-none transition-all"
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full py-3 px-4 rounded-xl bg-brand hover:bg-brand-hover text-white font-semibold text-sm shadow-md shadow-brand/20 transition-all flex items-center justify-center gap-2 mt-6 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <>
              <span>Đăng nhập</span>
              <ArrowRight size={16} />
            </>
          )}
        </button>
      </form>

      {/* Footer link to register */}
      <div className="text-center mt-6 pt-5 border-t border-appBorder-light dark:border-appBorder-dark">
        <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary">
          Chưa có tài khoản?{" "}
          <NextLink
            href="/register"
            className="text-brand font-semibold hover:underline"
          >
            Đăng ký ngay
          </NextLink>
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-appBg-light dark:bg-appBg-dark">
      <Suspense fallback={<div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin" />}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
