export const AUTH_COOKIE_NAME = "socialhub_token";

// 30 days in seconds (matches Sanctum token lifetime from openapi.yaml)
export const COOKIE_MAX_AGE = 30 * 24 * 60 * 60;

export const BACKEND_API_URL =
  process.env.BACKEND_API_URL || "http://127.0.0.1:8000/api/v1";

export const APP_NAME = "SocialHub";
