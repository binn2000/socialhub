/** The emojis the quick send button can send as default presets. */
export const QUICK_REACTIONS = ["👍", "❤️", "😂", "😮", "😢", "😡", "🔥", "🎉", "👏", "😍", "🙏", "💯"] as const;

export const DEFAULT_QUICK_REACTION = "👍";

/** What the server sent, or the default when it is missing or empty. */
export function quickReactionOf(value: string | null | undefined): string {
  if (!value || typeof value !== "string") return DEFAULT_QUICK_REACTION;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : DEFAULT_QUICK_REACTION;
}
