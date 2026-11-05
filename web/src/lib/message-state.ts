import type { Message } from "@/types";

export type MessageState = Pick<Message, "reactions" | "myReaction" | "isRecalled">;

/** What the server says changed on already known messages (`meta.states` of a poll). */
export function applyStates(
  messages: Message[],
  states: Record<string, MessageState> | undefined | null
): Message[] {
  if (!states) return messages;
  let changed = false;
  const next = messages.map((m) => {
    const s = states[m.id];
    if (!s) return m;
    const same =
      m.isRecalled === s.isRecalled &&
      m.myReaction === s.myReaction &&
      JSON.stringify(m.reactions) === JSON.stringify(s.reactions);
    if (same) return m;
    changed = true;
    // A recalled message loses its text and files for everybody.
    return s.isRecalled
      ? { ...m, ...s, text: "", attachments: [] }
      : { ...m, ...s };
  });
  return changed ? next : messages;
}

/** The message as it looks right after I chose [emoji] (null: took my reaction back), before the server answers. */
export function withMyReaction(message: Message, emoji: string | null): Message {
  const reactions = { ...message.reactions };
  const before = message.myReaction;
  if (before) {
    const left = (reactions[before] ?? 1) - 1;
    if (left <= 0) delete reactions[before];
    else reactions[before] = left;
  }
  if (emoji) reactions[emoji] = (reactions[emoji] ?? 0) + 1;
  return { ...message, reactions, myReaction: emoji as Message["myReaction"] };
}
