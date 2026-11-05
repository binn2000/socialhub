export const MESSAGE_REACTIONS = ["❤️", "👍", "😂", "😮", "😢", "😡"] as const;

export type MessageReactionEmoji = (typeof MESSAGE_REACTIONS)[number];

export interface QuotedMessage {
  id: string;
  senderName: string;
  text: string;
}

/**
 * Checks if a message text begins with the reply envelope [reply:id:sender:preview]
 * and extracts the quote and remaining actual text.
 */
export function parseReplyMessage(rawText: string | null | undefined): {
  reply: QuotedMessage | null;
  text: string;
} {
  if (!rawText) return { reply: null, text: "" };
  const match = rawText.match(/^\[reply:([^:]+):([^:]+):([^\]]*)\]\n?([\s\S]*)$/);
  if (match) {
    return {
      reply: {
        id: match[1],
        senderName: match[2],
        text: match[3],
      },
      text: match[4] || "",
    };
  }
  return { reply: null, text: rawText };
}

/**
 * Formats a message with a quoted reply envelope.
 */
export function buildReplyPayload(reply: QuotedMessage, text: string): string {
  const cleanSender = reply.senderName.replace(/[:\]\n]/g, "").trim();
  const cleanSnippet = (reply.text || "[Tệp tin/Ảnh]").replace(/[:\]\n]/g, " ").slice(0, 80).trim();
  return `[reply:${reply.id}:${cleanSender}:${cleanSnippet}]\n${text.trim()}`;
}
