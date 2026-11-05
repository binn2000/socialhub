/** The emojis the quick send button can send (ConversationController::QUICK_REACTIONS). */
export const QUICK_REACTIONS = ["👍", "❤️", "😂", "😮", "😢", "😡", "🔥", "🎉", "👏", "😍", "🙏", "💯"] as const;

export const DEFAULT_QUICK_REACTION = "👍";

/** What the server sent, or the default when it is missing or not in the list. */
export function quickReactionOf(value: string | null | undefined): string {
  return value && (QUICK_REACTIONS as readonly string[]).includes(value) ? value : DEFAULT_QUICK_REACTION;
}
