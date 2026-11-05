"use client";

import React, { useState, useEffect, useRef } from "react";
import { Search, Plus, MessageCircle, X, Check } from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { formatMessagePreview } from "@/lib/chat-emojis-stickers";
import { clientFetch } from "@/lib/client-api";
import { NewConversationModal } from "./NewConversationModal";
import { NotesTray } from "./NotesTray";
import type { Conversation } from "@/types";

interface ConversationListProps {
  selectedId?: string | null;
  onSelectConversation: (conversation: Conversation) => void;
  className?: string;
}

export function ConversationList({
  selectedId,
  onSelectConversation,
  className = "",
}: ConversationListProps) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [newChatModalOpen, setNewChatModalOpen] = useState(false);

  const searchTimerRef = useRef<NodeJS.Timeout | null>(null);

  const loadConversations = async (queryText = "") => {
    try {
      const q = queryText.trim() ? `?q=${encodeURIComponent(queryText.trim())}` : "";
      const res = await clientFetch<{ data: Conversation[] }>(
        `/api/proxy/conversations${q}`
      );
      setConversations(res.data || []);
    } catch {
      setConversations([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadConversations();
  }, []);

  // Debounced search
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchQuery(value);

    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    searchTimerRef.current = setTimeout(() => {
      loadConversations(value);
    }, 350);
  };

  const handleConversationStarted = (conv: Conversation) => {
    setConversations((prev) => {
      const exists = prev.some((c) => c.id === conv.id);
      return exists ? prev : [conv, ...prev];
    });
    onSelectConversation(conv);
  };

  return (
    <div
      className={`flex flex-col h-full bg-white dark:bg-surface-dark border-r border-appBorder-light dark:border-appBorder-dark ${className}`}
    >
      {/* Top Header */}
      <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
        <h1 className="text-xl font-bold text-appText-primary dark:text-white">
          Đoạn chat
        </h1>

        <button
          type="button"
          onClick={() => setNewChatModalOpen(true)}
          className="p-2 rounded-xl bg-brand-soft dark:bg-brand/20 text-brand dark:text-brand-light hover:bg-brand/15 transition shadow-sm"
          title="Tin nhắn mới"
        >
          <Plus className="w-5 h-5" />
        </button>
      </div>

      {/* Search Input */}
      <div className="p-3 border-b border-appBorder-light dark:border-appBorder-dark">
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
          <input
            type="text"
            value={searchQuery}
            onChange={handleSearchChange}
            placeholder="Tìm kiếm cuộc trò chuyện..."
            className="w-full pl-9 pr-8 py-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-surface-muted dark:bg-surface-dark-muted/80 text-appText-primary dark:text-white text-xs sm:text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
          />
          {searchQuery && (
            <button
              onClick={() => {
                setSearchQuery("");
                loadConversations("");
              }}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 p-0.5 text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Notes Tray (Facebook Messenger style) */}
      {!searchQuery && (
        <NotesTray
          onOpenConversation={(convId) => {
            loadConversations();
            onSelectConversation({ id: convId } as Conversation);
          }}
        />
      )}

      {/* Conversation Items */}
      <div className="flex-1 overflow-y-auto divide-y divide-appBorder-light dark:divide-appBorder-dark/80 select-none">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center text-appText-secondary">
            <div className="w-6 h-6 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
            <span className="text-xs">Đang tải cuộc trò chuyện...</span>
          </div>
        ) : conversations.length === 0 ? (
          <div className="py-20 text-center px-4 text-appText-secondary">
            <MessageCircle className="w-10 h-10 mx-auto mb-2 opacity-50" />
            <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
              {searchQuery ? "Không tìm thấy kết quả" : "Chưa có đoạn chat nào"}
            </p>
            <p className="text-xs text-appText-secondary mt-0.5">
              Bắt đầu trò chuyện với bạn bè ngay hôm nay!
            </p>
          </div>
        ) : (
          conversations.map((conv) => {
            const isSelected = selectedId === conv.id;
            const hasUnread = conv.unreadCount > 0;
            const snippet =
              conv.lastMessage?.text
                ? formatMessagePreview(conv.lastMessage.text)
                : conv.lastMessage?.attachments && conv.lastMessage.attachments.length > 0
                ? "Đã gửi tệp đính kèm"
                : "Bắt đầu cuộc trò chuyện";

            const timeLabel = conv.lastMessage?.createdAt
              ? timeAgo(conv.lastMessage.createdAt)
              : timeAgo(conv.updatedAt);

            return (
              <button
                key={conv.id}
                type="button"
                onClick={() => onSelectConversation(conv)}
                className={`w-full p-3 sm:px-4 flex items-center gap-3 text-left transition ${
                  isSelected
                    ? "bg-brand-soft/70 dark:bg-brand/15"
                    : "hover:bg-surface-muted dark:hover:bg-surface-dark-muted/40"
                }`}
              >
                <UserAvatar
                  name={conv.participant.name}
                  imageUrl={conv.participant.avatarUrl}
                  size="md"
                  isOnline={conv.participant.isOnline ?? false}
                />

                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between mb-0.5">
                    <p
                      className={`text-sm truncate ${
                        hasUnread
                          ? "font-bold text-appText-primary dark:text-white"
                          : "font-semibold text-appText-primary dark:text-appText-dark-primary"
                      }`}
                    >
                      {conv.participant.name}
                    </p>
                    <span className="text-[11px] text-appText-secondary flex-shrink-0 ml-2">
                      {timeLabel}
                    </span>
                  </div>

                  <div className="flex items-center justify-between gap-2">
                    <p
                      className={`text-xs truncate ${
                        hasUnread
                          ? "font-semibold text-brand dark:text-brand-light"
                          : "text-appText-secondary dark:text-appText-dark-secondary"
                      }`}
                    >
                      {snippet}
                    </p>

                    {hasUnread && (
                      <span className="px-1.5 py-0.5 rounded-full bg-brand text-white font-bold text-[10px] flex-shrink-0">
                        {conv.unreadCount > 99 ? "99+" : conv.unreadCount}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            );
          })
        )}
      </div>

      {/* New conversation modal */}
      {newChatModalOpen && (
        <NewConversationModal
          isOpen={newChatModalOpen}
          onClose={() => setNewChatModalOpen(false)}
          onConversationStarted={handleConversationStarted}
        />
      )}
    </div>
  );
}
