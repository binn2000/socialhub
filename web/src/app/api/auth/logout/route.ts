import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { AUTH_COOKIE_NAME, BACKEND_API_URL } from "@/lib/constants";

export async function POST() {
  const cookieStore = cookies();
  const token = cookieStore.get(AUTH_COOKIE_NAME)?.value;

  if (token) {
    try {
      await fetch(`${BACKEND_API_URL.replace(/\/$/, "")}/auth/logout`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${token}`,
          // Without this ngrok answers with its HTML warning page and the token is never revoked.
          "ngrok-skip-browser-warning": "true",
        },
      });
    } catch {
      // Ignore network errors when logging out
    }
  }

  // Clear cookie
  cookieStore.set(AUTH_COOKIE_NAME, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });

  return NextResponse.json({ success: true });
}
