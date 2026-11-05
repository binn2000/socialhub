"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "./AuthContext";
import type { Conversation } from "@/types";

interface BadgeContextType {
  unreadNotifications: number;
  unreadMessages: number;
  refreshBadges: () => Promise<void>;
  markNotificationsReadLocally: () => void;
}

const BadgeContext = createContext<BadgeContextType>({
  unreadNotifications: 0,
  unreadMessages: 0,
  refreshBadges: async () => {},
  markNotificationsReadLocally: () => {},
});

export function BadgeProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [unreadNotifications, setUnreadNotifications] = useState(0);
  const [unreadMessages, setUnreadMessages] = useState(0);

  const refreshBadges = useCallback(async () => {
    if (!user) return;

    try {
      // 1. Fetch unread notifications count
      const notifRes = await clientFetch<{ count: number }>(
        "/api/proxy/notifications/unread-count"
      );
      if (typeof notifRes.count === "number") {
        setUnreadNotifications(notifRes.count);
      }
    } catch {
      // Ignore background badge fetch errors
    }

    try {
      // 2. Fetch conversations to sum unread messages
      const convRes = await clientFetch<{ data: Conversation[] }>(
        "/api/proxy/conversations"
      );
      if (Array.isArray(convRes.data)) {
        const totalUnread = convRes.data.reduce(
          (acc, c) => acc + (c.unreadCount || 0),
          0
        );
        setUnreadMessages(totalUnread);
      }
    } catch {
      // Ignore
    }
  }, [user]);

  const markNotificationsReadLocally = useCallback(() => {
    setUnreadNotifications(0);
  }, []);

  useEffect(() => {
    if (!user) {
      setUnreadNotifications(0);
      setUnreadMessages(0);
      return;
    }

    refreshBadges();

    // Poll badges every 30s
    const timer = setInterval(() => {
      refreshBadges();
    }, 30000);

    return () => clearInterval(timer);
  }, [user, refreshBadges]);

  return (
    <BadgeContext.Provider
      value={{
        unreadNotifications,
        unreadMessages,
        refreshBadges,
        markNotificationsReadLocally,
      }}
    >
      {children}
    </BadgeContext.Provider>
  );
}

export function useBadges() {
  return useContext(BadgeContext);
}
