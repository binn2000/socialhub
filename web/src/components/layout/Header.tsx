"use client";

import React, { useEffect, useRef, useState } from "react";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import {
  Bell,
  Bookmark,
  ChevronDown,
  LogOut,
  MessageCircle,
  Moon,
  Search,
  ShieldBan,
  Sparkles,
  Sun,
  User as UserIcon,
  UserCog,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useBadges } from "@/context/BadgeContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { isDarkTheme, setDarkTheme } from "@/lib/theme";

const iconButton =
  "relative p-2.5 rounded-full text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:text-appText-primary dark:hover:text-appText-dark-primary active:scale-95 transition";

function CountBadge({ count, tone }: { count: number; tone: "brand" | "danger" }) {
  if (count <= 0) return null;
  return (
    <span
      className={`absolute top-1 right-1 min-w-[18px] h-[18px] px-1 text-[10px] font-bold text-white rounded-full flex items-center justify-center ring-2 ring-surface-light dark:ring-surface-dark ${
        tone === "brand" ? "bg-brand" : "bg-danger"
      }`}
    >
      {count > 99 ? "99+" : count}
    </span>
  );
}

export function Header() {
  const { user, logout } = useAuth();
  const { unreadNotifications, unreadMessages } = useBadges();
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [isDark, setIsDark] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // The real theme is set by the inline script before hydration.
  useEffect(() => setIsDark(isDarkTheme()), []);

  // Close the account menu on outside click or Escape.
  useEffect(() => {
    if (!menuOpen) return;
    const onClick = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenuOpen(false);
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [menuOpen]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (search.trim()) router.push(`/explore?q=${encodeURIComponent(search.trim())}`);
  };

  const toggleTheme = () => {
    const next = !isDark;
    setDarkTheme(next);
    setIsDark(next);
  };

  const menuLinks = [
    { href: "/profile", label: "Trang cá nhân", icon: UserIcon },
    { href: "/settings/profile", label: "Chỉnh sửa hồ sơ", icon: UserCog },
    { href: "/saved", label: "Bài viết đã lưu", icon: Bookmark },
    { href: "/settings/blocked", label: "Người đã chặn", icon: ShieldBan },
  ];

  return (
    <header className="sticky top-0 z-30 flex items-center justify-between h-16 px-4 md:px-6 bg-surface-light/85 dark:bg-surface-dark/85 backdrop-blur-md border-b border-appBorder-light dark:border-appBorder-dark">
      {/* Mobile brand */}
      <NextLink href="/" className="flex items-center gap-2 md:hidden">
        <div className="w-8 h-8 rounded-lg bg-brand flex items-center justify-center text-white">
          <Sparkles size={18} />
        </div>
        <span className="text-lg font-bold tracking-tight text-appText-primary dark:text-appText-dark-primary">
          SocialHub
        </span>
      </NextLink>

      {/* Search */}
      <form onSubmit={handleSearch} className="hidden sm:flex items-center relative flex-1 max-w-md mx-4">
        <Search size={18} className="absolute left-3.5 text-appText-secondary dark:text-appText-dark-secondary" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Tìm kiếm bạn bè, bài viết..."
          className="w-full pl-10 pr-4 py-2 text-sm rounded-full bg-surface-muted dark:bg-surface-dark-muted border border-transparent focus:border-brand/50 focus:ring-4 focus:ring-brand/10 focus:bg-surface-light dark:focus:bg-surface-dark text-appText-primary dark:text-appText-dark-primary placeholder-appText-secondary dark:placeholder-appText-dark-secondary transition outline-none"
        />
      </form>

      <div className="flex items-center gap-1 ml-auto">
        <button onClick={toggleTheme} title="Chuyển chế độ sáng/tối" className={iconButton}>
          {isDark ? <Sun size={19} /> : <Moon size={19} />}
        </button>

        <NextLink href="/messages" title="Tin nhắn" className={iconButton}>
          <MessageCircle size={19} />
          <CountBadge count={unreadMessages} tone="brand" />
        </NextLink>

        <NextLink href="/notifications" title="Thông báo" className={iconButton}>
          <Bell size={19} />
          <CountBadge count={unreadNotifications} tone="danger" />
        </NextLink>

        {user && (
          <div ref={menuRef} className="relative ml-1">
            <button
              type="button"
              onClick={() => setMenuOpen((v) => !v)}
              aria-haspopup="menu"
              aria-expanded={menuOpen}
              title="Tài khoản"
              className={`flex items-center gap-1.5 p-1 pr-1.5 rounded-full border transition ${
                menuOpen
                  ? "border-brand/40 bg-brand-soft dark:bg-brand/15"
                  : "border-transparent hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
              }`}
            >
              <UserAvatar src={user.avatarUrl} name={user.name} size="xs" />
              <ChevronDown
                size={14}
                className={`hidden sm:block text-appText-secondary dark:text-appText-dark-secondary transition-transform ${
                  menuOpen ? "rotate-180" : ""
                }`}
              />
            </button>

            {menuOpen && (
              <div
                role="menu"
                className="absolute right-0 mt-2 w-72 origin-top-right rounded-2xl bg-surface-light dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark shadow-elevated p-2 animate-dropdown-in"
              >
                <NextLink
                  href="/profile"
                  onClick={() => setMenuOpen(false)}
                  className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                >
                  <UserAvatar src={user.avatarUrl} name={user.name} size="md" />
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary truncate">
                      {user.name}
                    </p>
                    <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary truncate">
                      @{user.username}
                    </p>
                  </div>
                </NextLink>

                <div className="my-2 h-px bg-appBorder-light dark:bg-appBorder-dark" />

                {menuLinks.map(({ href, label, icon: Icon }) => (
                  <NextLink
                    key={href}
                    href={href}
                    role="menuitem"
                    onClick={() => setMenuOpen(false)}
                    className="flex items-center gap-3 px-2.5 py-2 rounded-xl text-sm text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                  >
                    <span className="w-8 h-8 rounded-full bg-surface-muted dark:bg-surface-dark-muted flex items-center justify-center text-appText-secondary dark:text-appText-dark-secondary">
                      <Icon size={16} />
                    </span>
                    {label}
                  </NextLink>
                ))}

                <button
                  type="button"
                  role="menuitem"
                  onClick={toggleTheme}
                  className="w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-sm text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                >
                  <span className="w-8 h-8 rounded-full bg-surface-muted dark:bg-surface-dark-muted flex items-center justify-center text-appText-secondary dark:text-appText-dark-secondary">
                    {isDark ? <Sun size={16} /> : <Moon size={16} />}
                  </span>
                  <span className="flex-1 text-left">Chế độ tối</span>
                  <span
                    className={`w-9 h-5 rounded-full p-0.5 transition-colors ${isDark ? "bg-brand" : "bg-appBorder-light dark:bg-appBorder-dark"}`}
                  >
                    <span
                      className={`block w-4 h-4 rounded-full bg-white shadow transition-transform ${isDark ? "translate-x-4" : ""}`}
                    />
                  </span>
                </button>

                <div className="my-2 h-px bg-appBorder-light dark:bg-appBorder-dark" />

                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    setMenuOpen(false);
                    logout();
                  }}
                  className="w-full flex items-center gap-3 px-2.5 py-2 rounded-xl text-sm font-medium text-danger hover:bg-danger/10 transition"
                >
                  <span className="w-8 h-8 rounded-full bg-danger/10 flex items-center justify-center">
                    <LogOut size={16} />
                  </span>
                  Đăng xuất
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </header>
  );
}
