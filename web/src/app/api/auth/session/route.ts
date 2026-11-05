import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { AUTH_COOKIE_NAME, BACKEND_API_URL } from "@/lib/constants";
import type { Me, ApiError } from "@/types";

export async function GET() {
  const cookieStore = cookies();
  const token = cookieStore.get(AUTH_COOKIE_NAME)?.value;

  if (!token) {
    return NextResponse.json(
      { message: "Chưa đăng nhập", code: "unauthenticated" },
      { status: 401 }
    );
  }

  try {
    const response = await fetch(`${BACKEND_API_URL.replace(/\/$/, "")}/me`, {
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${token}`,
        "ngrok-skip-browser-warning": "true",
      },
      cache: "no-store",
    });

    const data = await response.json();

    if (!response.ok) {
      if (response.status === 401) {
        // Clear invalid/expired cookie
        cookieStore.set(AUTH_COOKIE_NAME, "", {
          httpOnly: true,
          secure: process.env.NODE_ENV === "production",
          sameSite: "lax",
          path: "/",
          maxAge: 0,
        });
      }
      return NextResponse.json(data as ApiError, { status: response.status });
    }

    return NextResponse.json(data as { data: Me });
  } catch {
    return NextResponse.json(
      { message: "Không thể kết nối đến máy chủ", code: "server_unavailable" },
      { status: 503 }
    );
  }
}
