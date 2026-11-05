import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { AUTH_COOKIE_NAME } from "./lib/constants";
import { isCrossSiteWrite } from "./lib/origin";

const PUBLIC_PATHS = [
  "/login",
  "/register",
  "/forgot-password",
  "/terms",
  "/privacy",
];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(AUTH_COOKIE_NAME)?.value;

  if (
    pathname.startsWith("/api/") &&
    isCrossSiteWrite(
      request.method,
      request.headers.get("origin"),
      request.headers.get("x-forwarded-host") ?? request.headers.get("host"),
      request.headers.get("sec-fetch-site")
    )
  ) {
    return NextResponse.json(
      { message: "Yêu cầu không hợp lệ", code: "forbidden_origin" },
      { status: 403 }
    );
  }

  // Let Next.js internals, static files, and auth API routes through
  if (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api/auth") ||
    pathname.includes(".") // static files like favicon.ico, images, etc.
  ) {
    return NextResponse.next();
  }

  const isPublicPath = PUBLIC_PATHS.some(
    (path) => pathname === path || pathname.startsWith(`${path}/`)
  );

  // If unauthenticated and trying to access protected route -> redirect to login
  if (!token && !isPublicPath) {
    const url = new URL("/login", request.url);
    if (pathname !== "/") {
      url.searchParams.set("from", pathname);
    }
    return NextResponse.redirect(url);
  }

  // If already authenticated and trying to access auth pages -> redirect to home
  if (token && (pathname === "/login" || pathname === "/register")) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     */
    "/((?!_next/static|_next/image|favicon.ico).*)",
  ],
};
