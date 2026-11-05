import { ApiRequestError } from "./errors";
import type { ApiError, ValidationError } from "@/types";

interface RequestOptions extends RequestInit {
  params?: Record<string, string | number | boolean | null | undefined>;
}

export async function clientFetch<T = unknown>(
  endpoint: string,
  options: RequestOptions = {}
): Promise<T> {
  // If calling an auth route (e.g. /api/auth/login), hit it directly, else proxy to /api/proxy/...
  const isAuthRoute = endpoint.startsWith("/api/auth");
  // Callers pass either "feed" or "/api/proxy/feed"; strip the prefix so it is added only once.
  const path = isAuthRoute
    ? endpoint
    : `/api/proxy/${endpoint.replace(/^\/?(api\/proxy\/)?/, "")}`;

  const url = new URL(path, window.location.origin);

  if (options.params) {
    Object.entries(options.params).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, String(value));
      }
    });
  }

  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");

  if (!(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(url.toString(), {
    ...options,
    headers,
    credentials: "same-origin",
  });

  if (response.status === 204) {
    return null as T;
  }

  const data = await response.json().catch(() => null);

  if (!response.ok) {
    // If 401 unauthenticated, redirect to login unless on auth page
    if (response.status === 401 && !window.location.pathname.startsWith("/login")) {
      window.location.href = `/login?from=${encodeURIComponent(window.location.pathname)}`;
    }

    const errorData = data as (ApiError & Partial<ValidationError>) | null;
    throw new ApiRequestError(
      response.status,
      errorData?.code || "client_error",
      errorData?.message || "Đã xảy ra lỗi, vui lòng thử lại",
      errorData?.errors
    );
  }

  return data as T;
}
