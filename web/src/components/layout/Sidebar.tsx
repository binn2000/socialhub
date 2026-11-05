"use client";

import React from "react";
import Link from "next/navigation";
import { usePathname } from "next/navigation";
import NextLink from "next/link";
import {
  Home,
  Compass,
  Users,
  MessageCircle,
  Bell,
  Bookmark,
  User,
  LogOut,
  Sparkles,
  Settings,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useBadges } from "@/context/BadgeContext";
import { UserAvatar } from "@/components/ui/UserAvatar";

import type { LucideIcon } from "lucide-react";

interface NavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  badge?: number;
}

export function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const { unreadNotifications, unreadMessages } = useBadges();

  const navItems: NavItem[] = [
    { label: "Trang chủ", href: "/", icon: Home },
    { label: "Khám phá", href: "/explore", icon: Compass },
    { label: "Bạn bè", href: "/friends", icon: Users },
    { label: "Tin nhắn", href: "/messages", icon: MessageCircle, badge: unreadMessages },
    { label: "Thông báo", href: "/notifications", icon: Bell, badge: unreadNotifications },
    { label: "Bài đã lưu", href: "/saved", icon: Bookmark },
    { label: "Trang cá nhân", href: "/profile", icon: User },
  ];

  return (
    <aside className="hidden md:flex flex-col w-64 lg:w-72 h-screen sticky top-0 border-r border-appBorder-light dark:border-appBorder-dark bg-surface-light dark:bg-surface-dark px-4 py-6 justify-between select-none">
      <div className="space-y-6">
        {/* Brand Header */}
        <NextLink href="/" className="flex items-center gap-3 px-3 py-1">
          <div className="w-10 h-10 rounded-xl bg-brand flex items-center justify-center text-white shadow-md shadow-brand/20">
            <Sparkles size={22} className="animate-pulse" />
          </div>
          <div>
            <span className="text-xl font-bold tracking-tight text-appText-primary dark:text-appText-dark-primary">
              SocialHub
            </span>
            <span className="block text-[11px] font-medium text-appText-secondary dark:text-appText-dark-secondary -mt-1">
              Mạng xã hội hiện đại
            </span>
          </div>
        </NextLink>

        {/* Navigation list */}
        <nav className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href);

            return (
              <NextLink
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3.5 px-3.5 py-3 rounded-md font-medium text-sm transition-all duration-150 ${
                  isActive
                    ? "bg-brand text-white shadow-sm shadow-brand/25 font-semibold"
                    : "text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted hover:text-appText-primary dark:hover:text-appText-dark-primary"
                }`}
              >
                <Icon
                  size={20}
                  className={isActive ? "text-white" : "text-appText-secondary dark:text-appText-dark-secondary"}
                />
                <span className="flex-1">{item.label}</span>
                {item.badge !== undefined && item.badge > 0 && (
                  <span
                    className={`px-2 py-0.5 text-xs rounded-full font-bold ${
                      isActive
                        ? "bg-white text-brand"
                        : "bg-brand text-white"
                    }`}
                  >
                    {item.badge > 99 ? "99+" : item.badge}
                  </span>
                )}
              </NextLink>
            );
          })}
        </nav>
      </div>

      {/* User profile & Logout */}
      {user && (
        <div className="border-t border-appBorder-light dark:border-appBorder-dark pt-4">
          <div className="flex items-center justify-between p-2 rounded-md hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition-colors">
            <NextLink
              href="/profile"
              className="flex items-center gap-3 min-w-0 flex-1"
            >
              <UserAvatar
                src={user.avatarUrl}
                name={user.name}
                size="sm"
                isOnline={true}
              />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold truncate text-appText-primary dark:text-appText-dark-primary">
                  {user.name}
                </p>
                <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary truncate">
                  @{user.username}
                </p>
              </div>
            </NextLink>

            <div className="flex items-center">
              <NextLink
                href="/settings/profile"
                title="Cài đặt hồ sơ"
                className="p-2 text-appText-secondary hover:text-brand dark:hover:text-brand rounded-lg transition-colors"
              >
                <Settings size={18} />
              </NextLink>
              <button
                onClick={() => logout()}
                title="Đăng xuất"
                className="p-2 text-appText-secondary hover:text-danger dark:hover:text-danger rounded-lg transition-colors"
              >
                <LogOut size={18} />
              </button>
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
