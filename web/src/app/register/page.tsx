"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { ApiRequestError } from "@/lib/errors";

export default function RegisterPage() {
  const router = useRouter();
  const { register } = useAuth();

  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [termsMissing, setTermsMissing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  const validate = () => {
    const errs: Record<string, string> = {};

    if (name.trim().length < 2) {
      errs.name = "Tên cần ít nhất 2 ký tự";
    }

    if (!/^[a-zA-Z0-9_]{3,30}$/.test(username.trim())) {
      errs.username = "Từ 3 đến 30 ký tự: chữ, số hoặc _";
    }

    if (!email.trim()) {
      errs.email = "Vui lòng nhập email";
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      errs.email = "Email không hợp lệ";
    }

    if (password.length < 8) {
      errs.password = "Mật khẩu cần ít nhất 8 ký tự";
    }

    if (!acceptedTerms) {
      setTermsMissing(true);
      errs.terms = "Bạn cần đồng ý với điều khoản để đăng ký";
    }

    setFieldErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);

    if (!validate()) return;

    setBusy(true);
    try {
      await register({
        name: name.trim(),
        username: username.trim().toLowerCase(),
        email: email.trim(),
        password,
      });
      router.push("/");
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
        if (err.errors) {
          const apiFieldErrs: Record<string, string> = {};
          for (const [key, msgs] of Object.entries(err.errors)) {
            apiFieldErrs[key] = Array.isArray(msgs) ? msgs[0] : msgs;
          }
          setFieldErrors((prev) => ({ ...prev, ...apiFieldErrs }));
        }
      } else {
        setError("Không thể đăng ký. Vui lòng kiểm tra lại kết nối.");
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-surface-muted dark:bg-appBg-dark px-4 py-12">
      <div className="w-full max-w-md bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm p-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-extrabold tracking-tight text-brand dark:text-brand-light">
            SocialHub
          </h1>
          <p className="mt-2 text-sm text-appText-secondary dark:text-appText-dark-secondary">
            Tạo tài khoản mới
          </p>
        </div>

        {error && (
          <div className="mb-6 p-4 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-sm text-red-600 dark:text-red-400">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="name"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Tên hiển thị
            </label>
            <input
              id="name"
              type="text"
              required
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                if (fieldErrors.name) {
                  setFieldErrors((prev) => ({ ...prev, name: "" }));
                }
              }}
              placeholder="Ví dụ: Lê Anh Hùng"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm transition"
            />
            {fieldErrors.name && (
              <p className="mt-1 text-xs text-red-500">{fieldErrors.name}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="username"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Tên người dùng
            </label>
            <input
              id="username"
              type="text"
              required
              value={username}
              onChange={(e) => {
                setUsername(e.target.value);
                if (fieldErrors.username) {
                  setFieldErrors((prev) => ({ ...prev, username: "" }));
                }
              }}
              placeholder="Chữ thường, số và dấu gạch dưới"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm transition"
            />
            <p className="mt-1 text-xs text-appText-secondary">
              {fieldErrors.username ? (
                <span className="text-red-500">{fieldErrors.username}</span>
              ) : (
                "Chữ thường, số và dấu gạch dưới (3 - 30 ký tự)"
              )}
            </p>
          </div>

          <div>
            <label
              htmlFor="email"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (fieldErrors.email) {
                  setFieldErrors((prev) => ({ ...prev, email: "" }));
                }
              }}
              placeholder="name@example.com"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm transition"
            />
            {fieldErrors.email && (
              <p className="mt-1 text-xs text-red-500">{fieldErrors.email}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Mật khẩu
            </label>
            <input
              id="password"
              type="password"
              required
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (fieldErrors.password) {
                  setFieldErrors((prev) => ({ ...prev, password: "" }));
                }
              }}
              placeholder="Tối thiểu 8 ký tự"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm transition"
            />
            {fieldErrors.password && (
              <p className="mt-1 text-xs text-red-500">
                {fieldErrors.password}
              </p>
            )}
          </div>

          <div className="pt-2">
            <div className="flex items-start">
              <input
                id="terms"
                type="checkbox"
                checked={acceptedTerms}
                onChange={(e) => {
                  setAcceptedTerms(e.target.checked);
                  if (e.target.checked) setTermsMissing(false);
                }}
                className="mt-1 h-4 w-4 rounded border-appBorder-light text-brand focus:ring-brand dark:border-appBorder-dark dark:bg-surface-dark-muted"
              />
              <label
                htmlFor="terms"
                className="ml-2.5 block text-sm text-appText-primary dark:text-appText-dark-primary select-none"
              >
                Tôi đồng ý với các điều khoản
              </label>
            </div>
            <div className="ml-6.5 mt-1 flex flex-wrap gap-x-2 text-xs text-brand dark:text-brand-light">
              <Link href="/terms" className="hover:underline" target="_blank">
                Điều khoản sử dụng
              </Link>
              <span className="text-appText-secondary">·</span>
              <Link href="/privacy" className="hover:underline" target="_blank">
                Chính sách quyền riêng tư
              </Link>
            </div>
            {termsMissing && (
              <p className="mt-1 text-xs text-red-500 ml-6.5">
                Bạn cần đồng ý với điều khoản để đăng ký
              </p>
            )}
          </div>

          <div className="pt-3">
            <button
              type="submit"
              disabled={busy}
              className="w-full py-2.5 px-4 rounded-xl font-medium text-white bg-brand hover:bg-brand-hover focus:outline-none focus:ring-2 focus:ring-brand focus:ring-offset-2 disabled:opacity-50 transition shadow-sm"
            >
              {busy ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin mx-auto" />
              ) : (
                "Đăng ký"
              )}
            </button>
          </div>
        </form>

        <div className="mt-6 text-center text-sm">
          <Link
            href="/login"
            className="text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light font-medium transition"
          >
            Đã có tài khoản? Đăng nhập
          </Link>
        </div>
      </div>
    </div>
  );
}
