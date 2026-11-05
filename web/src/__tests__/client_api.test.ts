import { describe, it, expect, vi, afterEach } from "vitest";
import { clientFetch } from "@/lib/client-api";

function stubBrowser() {
  const fetchMock = vi.fn(async () => new Response(JSON.stringify({ data: [] }), { status: 200 }));
  vi.stubGlobal("fetch", fetchMock);
  vi.stubGlobal("window", { location: { origin: "http://localhost:3000", pathname: "/" } });
  return fetchMock;
}

function requestedPath(fetchMock: ReturnType<typeof stubBrowser>) {
  const calls = fetchMock.mock.calls as unknown as [string][];
  return new URL(calls[0][0]).pathname + new URL(calls[0][0]).search;
}

describe("clientFetch URL building", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("adds the proxy prefix to a bare endpoint", async () => {
    const fetchMock = stubBrowser();
    await clientFetch("feed");
    expect(requestedPath(fetchMock)).toBe("/api/proxy/feed");
  });

  it("does not double the prefix when the caller already includes it", async () => {
    const fetchMock = stubBrowser();
    await clientFetch("/api/proxy/feed?filter=media");
    expect(requestedPath(fetchMock)).toBe("/api/proxy/feed?filter=media");
  });

  it("leaves /api/auth routes untouched", async () => {
    const fetchMock = stubBrowser();
    await clientFetch("/api/auth/session");
    expect(requestedPath(fetchMock)).toBe("/api/auth/session");
  });
});
