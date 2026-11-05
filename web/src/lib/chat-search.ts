import type { Message } from "@/types";
import { parseReplyMessage } from "@/lib/chat-interactions";
import { isStickerMessage } from "@/lib/chat-emojis-stickers";

/** Lower case without accents (đ too), so "ha noi" finds "Hà Nội". */
export function normalizeForSearch(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/gi, "d")
    .toLowerCase();
}

/**
 * The ids of the messages that contain [query], oldest first. What a message says is searched, not
 * the quote at the top of a reply; stickers and recalled messages are skipped.
 */
export function findMatchingMessageIds(messages: readonly Message[], query: string): string[] {
  const q = normalizeForSearch(query.trim());
  if (!q) return [];
  return messages
    .filter((m) => {
      if (m.isRecalled) return false;
      const written = parseReplyMessage(m.text).text || m.text || "";
      if (!written || isStickerMessage(written)) return false;
      return normalizeForSearch(written).includes(q);
    })
    .map((m) => m.id);
}
