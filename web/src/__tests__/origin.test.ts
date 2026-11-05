import { describe, it, expect } from "vitest";
import { isCrossSiteWrite } from "@/lib/origin";

describe("isCrossSiteWrite", () => {
  it("allows a write from the same site", () => {
    expect(isCrossSiteWrite("POST", "https://socialhub.vercel.app", "socialhub.vercel.app", "same-origin")).toBe(false);
  });

  it("blocks a write whose Origin is another site", () => {
    expect(isCrossSiteWrite("DELETE", "https://evil.example", "socialhub.vercel.app", "cross-site")).toBe(true);
  });

  it("blocks a write with a malformed Origin", () => {
    expect(isCrossSiteWrite("PUT", "null", "socialhub.vercel.app", null)).toBe(true);
  });

  it("blocks a cross-site write that has no Origin header", () => {
    expect(isCrossSiteWrite("POST", null, "socialhub.vercel.app", "cross-site")).toBe(true);
  });

  it("allows non-browser clients that send neither header", () => {
    expect(isCrossSiteWrite("POST", null, "socialhub.vercel.app", null)).toBe(false);
  });

  it("never blocks reads", () => {
    expect(isCrossSiteWrite("GET", "https://evil.example", "socialhub.vercel.app", "cross-site")).toBe(false);
  });
});
