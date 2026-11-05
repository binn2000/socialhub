import type { Metadata } from "next";
import "./globals.css";
import { AuthProvider } from "@/context/AuthContext";
import { BadgeProvider } from "@/context/BadgeContext";
import { ToastProvider } from "@/context/ToastContext";
import { AppShell } from "@/components/layout/AppShell";
import { getServerUser } from "@/lib/server-api";
import { THEME_INIT_SCRIPT } from "@/lib/theme";

export const metadata: Metadata = {
  title: "SocialHub - Mạng xã hội hiện đại",
  description: "Nền tảng mạng xã hội kết nối bạn bè, chia sẻ khoảnh khắc",
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const initialUser = await getServerUser();

  return (
    <html lang="vi" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body>
        <AuthProvider initialUser={initialUser}>
          <ToastProvider>
            <BadgeProvider>
              <AppShell>{children}</AppShell>
            </BadgeProvider>
          </ToastProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
