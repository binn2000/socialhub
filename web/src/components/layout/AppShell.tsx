"use client";

import React from "react";
import { usePathname } from "next/navigation";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { BottomNav } from "./BottomNav";
import { EmailVerificationBanner } from "../auth/EmailVerificationBanner";

const AUTH_PAGES = ["/login", "/register", "/forgot-password", "/terms", "/privacy"];
const FULLSCREEN_PAGES = ["/stories"];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isAuthPage = AUTH_PAGES.some((p) => pathname.startsWith(p));
  const isFullscreenPage = FULLSCREEN_PAGES.some((p) => pathname.startsWith(p));

  if (isAuthPage) {
    return <main className="min-h-screen bg-appBg-light dark:bg-appBg-dark">{children}</main>;
  }

  if (isFullscreenPage) {
    return <main className="min-h-screen bg-black">{children}</main>;
  }

  return (
    <div className="flex min-h-screen bg-appBg-light dark:bg-appBg-dark text-appText-primary dark:text-appText-dark-primary">
      {/* Desktop Sidebar */}
      <Sidebar />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 pb-16 md:pb-0">
        <Header />
        <EmailVerificationBanner />
        <main className="flex-1 max-w-7xl w-full mx-auto p-4 md:p-6 lg:p-8">
          {children}
        </main>
      </div>

      {/* Mobile Bottom Navigation */}
      <BottomNav />
    </div>
  );
}
