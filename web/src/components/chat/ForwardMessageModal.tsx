"use client";

import React, { useEffect, useState } from "react";
import { X, Search, Send } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { clientFetch } from "@/lib/client-api";
import { parseReplyMessage } from "@/lib/chat-interactions";
import { useToast } from "@/context/ToastContext";
import type { Conversation, Message } from "@/types";

interface ForwardMessageModalProps {
  message: Message;
  currentConversationId: string;
  onClose: () => void;
}

/** Sends the text (or sticker) of a message to another conversation. */
export function ForwardMessageModal({ message, currentConversationId, onClose }: ForwardMessageModalProps) {
  const { toast } = useToast();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [sendingTo, setSendingTo] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    clientFetch<{ data: Conversation[] }>("/api/proxy/conversations", { params: { limit: 50 } })
      .then((res) => {
        if (!cancelled) setConversations(res.data ?? []);
      })
      .catch(() => {
        if (!cancelled) toast.error("Không tải được danh sách trò chuyện");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [toast]);

  const q = query.trim().toLowerCase();
  const shown = conversations.filter(
    (c) =>
      c.id !== currentConversationId &&
      (!q ||
        c.participant.name.toLowerCase().includes(q) ||
        c.participant.username.toLowerCase().includes(q))
  );

  const forwardTo = async (target: Conversation) => {
    if (sendingTo) return;
    setSendingTo(target.id);
    // A quote of the original is not forwarded, only what it said.
    const text = parseReplyMessage(message.text).text || message.text;
    try {
      await clientFetch(`/api/proxy/conversations/${target.id}/messages`, {
        method: "POST",
        headers: { "Idempotency-Key": crypto.randomUUID() },
        body: JSON.stringify({ text }),
      });
      toast.success(`Đã chuyển tiếp cho ${target.participant.name}`);
      onClose();
    } catch {
      toast.error("Không thể chuyển tiếp lúc này");
      setSendingTo(null);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Chuyển tiếp tin nhắn"
    >
      <div
        className="w-full max-w-sm max-h-[80vh] flex flex-col bg-surface-light dark:bg-surface-dark rounded-2xl shadow-2xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-appBorder-light dark:border-appBorder-dark">
          <h2 className="font-bold text-base">Chuyển tiếp tin nhắn</h2>
          <button type="button" onClick={onClose} className="p-1 rounded-full hover:bg-surface-muted" aria-label="Đóng">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="px-4 py-2 border-b border-appBorder-light dark:border-appBorder-dark">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface-muted dark:bg-surface-dark-muted">
            <Search className="w-4 h-4 text-appText-secondary" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Tìm người nhận"
              className="flex-1 bg-transparent outline-none text-sm"
              autoFocus
            />
          </div>
        </div>

        <div className="overflow-y-auto flex-1">
          {loading ? (
            <p className="p-6 text-center text-sm text-appText-secondary">Đang tải...</p>
          ) : shown.length === 0 ? (
            <p className="p-6 text-center text-sm text-appText-secondary">Không có cuộc trò chuyện nào khác</p>
          ) : (
            shown.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => forwardTo(c)}
                disabled={sendingTo !== null}
                className="w-full flex items-center gap-3 px-4 py-2.5 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted disabled:opacity-60"
              >
                <UserAvatar name={c.participant.name} imageUrl={c.participant.avatarUrl} size="sm" />
                <span className="flex-1 min-w-0">
                  <span className="block font-semibold text-sm truncate">{c.participant.name}</span>
                  <span className="block text-xs text-appText-secondary truncate">@{c.participant.username}</span>
                </span>
                <Send className="w-4 h-4 text-brand" />
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
