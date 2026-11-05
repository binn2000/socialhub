import { cookies } from "next/headers";
import { AUTH_COOKIE_NAME, BACKEND_API_URL } from "./constants";
import { ApiRequestError } from "./errors";
import type { ApiError, ValidationError } from "@/types";

export { ApiRequestError };

interface ServerRequestOptions extends RequestInit {
  params?: Record<string, string | number | boolean | null | undefined>;
}

export async function serverFetch<T = unknown>(
  endpoint: string,
  options: ServerRequestOptions = {}
): Promise<T> {
  const cookieStore = cookies();
  const token = cookieStore.get(AUTH_COOKIE_NAME)?.value;

  const url = new URL(`${BACKEND_API_URL.replace(/\/$/, "")}/${endpoint.replace(/^\//, "")}`);

  if (options.params) {
    Object.entries(options.params).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, String(value));
      }
    });
  }

  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");
  headers.set("ngrok-skip-browser-warning", "true");

  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  // Do not set Content-Type if body is FormData
  if (!(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(url.toString(), {
    ...options,
    headers,
    cache: options.cache ?? "no-store",
  });

  if (response.status === 204) {
    return null as T;
  }

  const data = await response.json().catch(() => null);

  if (!response.ok) {
    const errorData = data as (ApiError & Partial<ValidationError>) | null;
    throw new ApiRequestError(
      response.status,
      errorData?.code || "server_error",
      errorData?.message || "Đã xảy ra lỗi kết nối máy chủ",
      errorData?.errors
    );
  }

  return data as T;
}

export async function getServerUser() {
  try {
    const res = await serverFetch<{ data: import("@/types").Me }>("me");
    return res.data;
  } catch {
    return null;
  }
}
