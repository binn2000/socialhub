const WRITE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/**
 * CSRF guard for the cookie-authenticated API routes: a request that writes data must come from this site.
 * Browsers always send Origin (or Sec-Fetch-Site) on cross-site writes, so a missing header means a non-browser client.
 */
export function isCrossSiteWrite(
  method: string,
  origin: string | null,
  host: string | null,
  fetchSite: string | null
): boolean {
  if (!WRITE_METHODS.has(method.toUpperCase())) {
    return false;
  }

  if (origin) {
    try {
      return new URL(origin).host !== host;
    } catch {
      return true;
    }
  }

  return fetchSite === "cross-site";
}
