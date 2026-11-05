import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { AUTH_COOKIE_NAME, BACKEND_API_URL } from "@/lib/constants";

async function handleProxy(
  request: NextRequest,
  { params }: { params: { path: string[] } }
) {
  const cookieStore = cookies();
  const token = cookieStore.get(AUTH_COOKIE_NAME)?.value;

  const subPath = params.path.join("/");
  const isPublicEndpoint =
    subPath === "auth/password/forgot" || subPath === "auth/password/reset";

  if (!token && !isPublicEndpoint) {
    return NextResponse.json(
      { message: "Chưa đăng nhập", code: "unauthenticated" },
      { status: 401 }
    );
  }

  const searchParams = request.nextUrl.search;
  const targetUrl = `${BACKEND_API_URL.replace(/\/$/, "")}/${subPath}${searchParams}`;

  const headers = new Headers();
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }
  headers.set("Accept", "application/json");
  headers.set("ngrok-skip-browser-warning", "true");

  // Forward Idempotency-Key if present
  const idempotencyKey = request.headers.get("Idempotency-Key");
  if (idempotencyKey) {
    headers.set("Idempotency-Key", idempotencyKey);
  }

  const contentType = request.headers.get("content-type");

  let body: BodyInit | null = null;
  if (request.method !== "GET" && request.method !== "HEAD") {
    if (contentType?.includes("multipart/form-data")) {
      // Forward formData as is; fetch will set proper multipart boundary
      body = await request.formData();
    } else if (contentType?.includes("application/json")) {
      headers.set("Content-Type", "application/json");
      body = await request.text();
    } else {
      body = await request.blob();
    }
  }

  try {
    const backendResponse = await fetch(targetUrl, {
      method: request.method,
      headers,
      body,
      cache: "no-store",
    });

    if (backendResponse.status === 204) {
      return new NextResponse(null, { status: 204 });
    }

    const responseContentType = backendResponse.headers.get("content-type");
    if (responseContentType?.includes("application/json")) {
      const data = await backendResponse.json();
      return NextResponse.json(data, { status: backendResponse.status });
    }

    const blob = await backendResponse.blob();
    return new NextResponse(blob, {
      status: backendResponse.status,
      headers: {
        "Content-Type": responseContentType || "application/octet-stream",
      },
    });
  } catch (error) {
    return NextResponse.json(
      { message: "Không thể kết nối đến máy chủ Laravel", code: "backend_unreachable" },
      { status: 502 }
    );
  }
}

export const GET = handleProxy;
export const POST = handleProxy;
export const PUT = handleProxy;
export const PATCH = handleProxy;
export const DELETE = handleProxy;
