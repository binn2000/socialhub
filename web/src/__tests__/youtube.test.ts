import { describe, expect, it } from "vitest";
import { formatDuration, isYoutubeId, youtubeEmbedUrl } from "@/lib/youtube";

describe("youtube helpers", () => {
  it("only accepts real 11-character ids and builds the privacy-enhanced embed url", () => {
    expect(isYoutubeId("dQw4w9WgXcQ")).toBe(true);
    expect(isYoutubeId("dQw4w9WgXc")).toBe(false);
    expect(isYoutubeId('dQw4w9WgXc"')).toBe(false);
    expect(youtubeEmbedUrl("dQw4w9WgXcQ")).toBe(
      "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0&modestbranding=1&autoplay=1"
    );
    expect(youtubeEmbedUrl("dQw4w9WgXcQ", false)).not.toContain("autoplay");
    // A url or script smuggled in as an id never becomes an iframe source.
    expect(youtubeEmbedUrl("javascript:alert(1)")).toBeNull();
    expect(youtubeEmbedUrl("../../evil")).toBeNull();
  });

  it("formats durations", () => {
    expect(formatDuration(3723)).toBe("1:02:03");
    expect(formatDuration(75)).toBe("1:15");
    expect(formatDuration(5)).toBe("0:05");
    expect(formatDuration(null)).toBe("");
  });
});
