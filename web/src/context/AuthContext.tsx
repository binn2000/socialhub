"use client";

import React, { createContext, useContext, useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import type { Me, LoginRequest, RegisterRequest } from "@/types";
import { clientFetch } from "@/lib/client-api";

interface AuthContextType {
  user: Me | null;
  loading: boolean;
  login: (data: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
  updateUser: (updated: Partial<Me>) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({
  children,
  initialUser = null,
}: {
  children: React.ReactNode;
  initialUser?: Me | null;
}) {
  const [user, setUser] = useState<Me | null>(initialUser);
  const [loading, setLoading] = useState<boolean>(!initialUser);
  const router = useRouter();

  const refreshUser = useCallback(async () => {
    try {
      const res = await clientFetch<{ data: Me }>("/api/auth/session");
      setUser(res.data);
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!initialUser) {
      refreshUser();
    }
  }, [initialUser, refreshUser]);

  // Presence heartbeat every 60s when user is active and has showOnlineStatus enabled
  useEffect(() => {
    if (!user || user.showOnlineStatus === false) return;

    const sendPresence = async () => {
      try {
        await clientFetch("/api/proxy/me/presence", { method: "POST" });
      } catch {
        // Presence failure should not interrupt user workflow
      }
    };

    // Initial heartbeat
    sendPresence();

    const interval = setInterval(sendPresence, 60000);
    return () => clearInterval(interval);
  }, [user]);

  const login = async (data: LoginRequest) => {
    const res = await clientFetch<{ data: Me }>("/api/auth/login", {
      method: "POST",
      body: JSON.stringify(data),
    });
    setUser(res.data);
    router.refresh();
  };

  const register = async (data: RegisterRequest) => {
    const res = await clientFetch<{ data: Me }>("/api/auth/register", {
      method: "POST",
      body: JSON.stringify(data),
    });
    setUser(res.data);
    router.refresh();
  };

  const logout = async () => {
    try {
      await clientFetch("/api/auth/logout", { method: "POST" });
    } finally {
      setUser(null);
      router.push("/login");
      router.refresh();
    }
  };

  const updateUser = (updated: Partial<Me>) => {
    setUser((prev) => (prev ? { ...prev, ...updated } : null));
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        login,
        register,
        logout,
        refreshUser,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
