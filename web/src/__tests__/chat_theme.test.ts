import { describe, it, expect } from "vitest";
import { CHAT_THEMES, DEFAULT_CHAT_THEME, getChatTheme } from "../lib/chat-theme";

describe("Chat Theme functionality", () => {
  it("provides standard themes including blue, purple, sunset, midnight, emerald", () => {
    const ids = CHAT_THEMES.map((t) => t.id);
    expect(ids).toContain("blue");
    expect(ids).toContain("purple");
    expect(ids).toContain("sunset");
    expect(ids).toContain("midnight");
    expect(ids).toContain("emerald");
  });

  it("returns default theme for null or unknown theme id", () => {
    expect(getChatTheme(null).id).toBe(DEFAULT_CHAT_THEME.id);
    expect(getChatTheme(undefined).id).toBe(DEFAULT_CHAT_THEME.id);
    expect(getChatTheme("unknown-theme-xyz").id).toBe(DEFAULT_CHAT_THEME.id);
  });

  it("finds specific theme correctly by id", () => {
    const purple = getChatTheme("purple");
    expect(purple.id).toBe("purple");
    expect(purple.name).toBe("Hồng tím");
    expect(purple.bubbleClass).toContain("from-pink-500");
  });
});
