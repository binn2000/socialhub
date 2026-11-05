import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { AUTH_COOKIE_NAME, COOKIE_MAX_AGE, BACKEND_API_URL } from "@/lib/constants";
import type { AuthResult, ApiError } from "@/types";

export async function POST(request: Request) {
  try {
    const body = await request.json();

    const response = await fetch(`${BACKEND_API_URL.replace(/\/$/, "")}/auth/register`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(data as ApiError, { status: response.status });
    }

    const authResult = data.data as AuthResult;
    const token = authResult.token.accessToken;

    const cookieStore = cookies();
    cookieStore.set(AUTH_COOKIE_NAME, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      maxAge: COOKIE_MAX_AGE,
    });

    return NextResponse.json({ data: authResult.user }, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { message: "Không thể kết nối đến máy chủ", code: "server_unavailable" },
      { status: 503 }
    );
  }
}
