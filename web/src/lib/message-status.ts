import type { Message } from "@/types";

export type SendState = "sent" | "delivered" | "seen";

/**
 * One of my messages as the other person sees it: "sent" (the server has it), "delivered"
 * (their app fetched it) or "seen". Message ids only grow, so a message counts as delivered
 * or seen when its id is not greater than the other person's marker.
 */
export function sendState(
  messageId: string,
  partnerLastDeliveredId: string | null | undefined,
  partnerLastReadId: string | null | undefined
): SendState {
  if (partnerLastReadId && messageId <= partnerLastReadId) return "seen";
  if (partnerLastDeliveredId && messageId <= partnerLastDeliveredId) return "delivered";
  return "sent";
}

/** The newest of my messages that the other person has read: their small avatar goes under it. */
export function lastSeenOfMine(
  messages: readonly Message[],
  myId: string | undefined,
  partnerLastReadId: string | null | undefined
): string | null {
  if (!partnerLastReadId || !myId) return null;
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.senderId === myId && !m.isRecalled && m.id <= partnerLastReadId) return m.id;
  }
  return null;
}
