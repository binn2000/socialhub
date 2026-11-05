/**
 * The API lists a conversation's messages newest first, but a chat shows them oldest first
 * with the newest at the bottom.
 */
export function oldestFirst<T>(newestFirst: readonly T[] | null | undefined): T[] {
  return [...(newestFirst ?? [])].reverse();
}
