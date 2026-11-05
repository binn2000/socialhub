import { NextRequest, NextResponse } from "next/server";
import { BACKEND_API_URL } from "@/lib/constants";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const backendRes = await fetch(
      `${BACKEND_API_URL.replace(/\/$/, "")}/auth/password/forgot`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
      }
    );

    const data = await backendRes.json().catch(() => ({}));
    return NextResponse.json(data, { status: backendRes.status });
  } catch (error) {
    return NextResponse.json(
      { message: "Không thể kết nối đến máy chủ", code: "backend_unreachable" },
      { status: 502 }
    );
  }
}
