"use client";

import React from "react";
import NextLink from "next/link";
import { usePathname } from "next/navigation";
import { Home, Compass, PlusCircle, Users, Bell, User } from "lucide-react";
import { useBadges } from "@/context/BadgeContext";

export function BottomNav() {
  const pathname = usePathname();
  const { unreadNotifications } = useBadges();

  const items = [
    { label: "Trang chủ", href: "/", icon: Home },
    { label: "Khám phá", href: "/explore", icon: Compass },
    { label: "Đăng bài", href: "/create-post", icon: PlusCircle, isAction: true },
    { label: "Bạn bè", href: "/friends", icon: Users },
    {
      label: "Thông báo",
      href: "/notifications",
      icon: Bell,
      badge: unreadNotifications,
    },
    { label: "Cá nhân", href: "/profile", icon: User },
  ];

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur-md border-t border-appBorder-light dark:border-appBorder-dark flex items-center justify-around py-2 px-1">
      {items.map((item) => {
        const Icon = item.icon;
        const isActive =
          item.href === "/"
            ? pathname === "/"
            : pathname.startsWith(item.href);

        if (item.isAction) {
          return (
            <NextLink
              key={item.href}
              href={item.href}
              className="flex flex-col items-center justify-center -mt-5"
            >
              <div className="w-12 h-12 rounded-full bg-brand text-white flex items-center justify-center shadow-lg shadow-brand/30 hover:bg-brand-hover transition-transform active:scale-95">
                <Icon size={24} />
              </div>
              <span className="text-[10px] font-medium text-appText-secondary dark:text-appText-dark-secondary mt-1">
                {item.label}
              </span>
            </NextLink>
          );
        }

        return (
          <NextLink
            key={item.href}
            href={item.href}
            className={`flex flex-col items-center justify-center py-1 px-2 rounded-lg transition-colors relative ${
              isActive
                ? "text-brand font-semibold"
                : "text-appText-secondary dark:text-appText-dark-secondary hover:text-appText-primary"
            }`}
          >
            <div className="relative">
              <Icon size={20} className={isActive ? "text-brand" : ""} />
              {item.badge !== undefined && item.badge > 0 && (
                <span className="absolute -top-1 -right-2 min-w-[14px] h-[14px] px-0.5 text-[9px] font-bold text-white bg-red-500 rounded-full flex items-center justify-center">
                  {item.badge > 99 ? "99+" : item.badge}
                </span>
              )}
            </div>
            <span className="text-[10px] mt-1 font-medium">{item.label}</span>
          </NextLink>
        );
      })}
    </nav>
  );
}
