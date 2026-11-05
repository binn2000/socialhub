"use client";

import React, { useState, useEffect, useRef, useCallback } from "react";
import Link from "next/link";
import {
  ArrowLeft,
  Paperclip,
  Send,
  Smile,
  Sparkles,
  File as FileIcon,
  Download,
  X,
  AlertCircle,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "@/context/AuthContext";
import { useBadges } from "@/context/BadgeContext";
import { useToast } from "@/context/ToastContext";
import { ImageViewerModal } from "@/components/feed/ImageViewerModal";
import { parseStickerMessage, StickerItem } from "@/lib/chat-emojis-stickers";
import { oldestFirst } from "@/lib/messages";
import { EmojiStickerPicker } from "./EmojiStickerPicker";
import type { Conversation, Message, Attachment } from "@/types";

interface ChatPaneProps {
  conversationId: string;
  onBack?: () => void;
  className?: string;
}

const QUICK_EMOJIS = ["😊", "❤️", "👍", "🎉", "🔥", "😂", "👏", "✨"];

export function ChatPane({
  conversationId,
  onBack,
  className = "",
}: ChatPaneProps) {
  const { user: currentUser } = useAuth();
  const { refreshBadges } = useBadges();
  const { toast } = useToast();

  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [inputText, setInputText] = useState("");
  const [sending, setSending] = useState(false);
  const [isPartnerTyping, setIsPartnerTyping] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);

  // Attachment states
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [pendingPreviews, setPendingPreviews] = useState<string[]>([]);

  // Lightbox
  const [viewerImages, setViewerImages] = useState<string[]>([]);
  const [viewerIndex, setViewerIndex] = useState(0);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const lastSentTypingRef = useRef<boolean>(false);

  const scrollToBottom = useCallback((smooth = false) => {
    messagesEndRef.current?.scrollIntoView({
      behavior: smooth ? "smooth" : "auto",
    });
  }, []);

  // 1. Initial Load of Messages & Conversation
  const loadInitialData = useCallback(async () => {
    setLoading(true);
    try {
      // Load conversation details
      const convRes = await clientFetch<{ data: Conversation[] }>(
        "/api/proxy/conversations"
      );
      const matched = convRes.data?.find((c) => c.id === conversationId) || null;
      setConversation(matched);

      // Load initial messages
      const msgRes = await clientFetch<{
        data: Message[];
        meta?: { otherTyping?: boolean };
      }>(`/api/proxy/conversations/${conversationId}/messages?limit=100`);

      // The newest message must end up at the bottom, so it is still there after a reload.
      setMessages(oldestFirst(msgRes.data));
      setIsPartnerTyping(Boolean(msgRes.meta?.otherTyping));

      // Mark read
      await clientFetch(`/api/proxy/conversations/${conversationId}/read`, {
        method: "POST",
      });
      refreshBadges();
    } catch {
      // Error handling
    } finally {
      setLoading(false);
      setTimeout(() => scrollToBottom(false), 100);
    }
  }, [conversationId, scrollToBottom]);

  useEffect(() => {
    loadInitialData();
  }, [loadInitialData]);

  // 2. Polling for New Messages & Typing Status every 4 seconds
  useEffect(() => {
    if (!conversationId) return;

    const pollInterval = setInterval(async () => {
      // Don't poll while actively sending to avoid racing state
      if (sending) return;

      try {
        const lastMsgId = messages.length > 0 ? messages[messages.length - 1].id : undefined;
        const query = lastMsgId ? `?after=${encodeURIComponent(lastMsgId)}` : "";

        const res = await clientFetch<{
          data: Message[];
          meta?: { otherTyping?: boolean };
        }>(`/api/proxy/conversations/${conversationId}/messages${query}`);

        setIsPartnerTyping(Boolean(res.meta?.otherTyping));

        if (res.data && res.data.length > 0) {
          setMessages((prev) => {
            const existingIds = new Set(prev.map((m) => m.id));
            const newOnes = res.data.filter((m) => !existingIds.has(m.id));
            if (newOnes.length === 0) return prev;

            // If partner sent a message, mark as read
            const partnerWrote = newOnes.some((m) => m.senderId !== currentUser?.id);
            if (partnerWrote) {
              clientFetch(`/api/proxy/conversations/${conversationId}/read`, {
                method: "POST",
              })
                .then(() => refreshBadges())
                .catch(() => {});
            }

            return [...prev, ...newOnes];
          });
          setTimeout(() => scrollToBottom(true), 80);
        }
      } catch {
        // Silently ignore polling network jitter
      }
    }, 4000);

    return () => clearInterval(pollInterval);
  }, [conversationId, messages, currentUser?.id, sending, scrollToBottom]);

  // 3. Send Typing Signals
  const handleTypingSignal = (isTyping: boolean) => {
    if (lastSentTypingRef.current === isTyping) return;
    lastSentTypingRef.current = isTyping;

    clientFetch(`/api/proxy/conversations/${conversationId}/typing`, {
      method: isTyping ? "PUT" : "DELETE",
    }).catch(() => {});
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const text = e.target.value;
    setInputText(text);

    if (text.trim().length > 0) {
      handleTypingSignal(true);
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      typingTimeoutRef.current = setTimeout(() => {
        handleTypingSignal(false);
      }, 4000);
    } else {
      handleTypingSignal(false);
    }
  };

  // 4. File picker
  const handlePickFiles = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;

    const availableSlots = 5 - pendingFiles.length;
    const addedFiles = files.slice(0, availableSlots);

    const newPreviews = addedFiles.map((f) =>
      f.type.startsWith("image/") ? URL.createObjectURL(f) : ""
    );

    setPendingFiles((prev) => [...prev, ...addedFiles]);
    setPendingPreviews((prev) => [...prev, ...newPreviews]);

    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  const handleRemoveFile = (index: number) => {
    setPendingFiles((prev) => prev.filter((_, i) => i !== index));
    setPendingPreviews((prev) => prev.filter((_, i) => i !== index));
  };

  // 5. Send Message
  const handleSendMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const text = inputText.trim();
    if ((!text && pendingFiles.length === 0) || sending) return;

    setSending(true);
    handleTypingSignal(false);
    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);

    const idempotencyKey = crypto.randomUUID();
    const formData = new FormData();
    if (text) formData.append("text", text);

    for (const file of pendingFiles) {
      formData.append("attachments[]", file);
    }

    try {
      const res = await clientFetch<{ data: Message }>(
        `/api/proxy/conversations/${conversationId}/messages`,
        {
          method: "POST",
          headers: {
            "Idempotency-Key": idempotencyKey,
          },
          body: formData,
        }
      );

      setMessages((prev) => [...prev, res.data]);
      setInputText("");
      setPendingFiles([]);
      setPendingPreviews([]);
      setShowEmojiPicker(false);
      setTimeout(() => scrollToBottom(true), 50);
    } catch {
      toast.error("Không thể gửi tin nhắn. Vui lòng thử lại.");
    } finally {
      setSending(false);
    }
  };

  const handleSendSticker = async (sticker: StickerItem) => {
    if (sending) return;
    setSending(true);
    try {
      const stickerPayload = `[sticker:${sticker.id}:${sticker.url}]`;
      const idempotencyKey = crypto.randomUUID();
      const res = await clientFetch<{ data: Message }>(
        `/api/proxy/conversations/${conversationId}/messages`,
        {
          method: "POST",
          headers: {
            "Idempotency-Key": idempotencyKey,
          },
          body: JSON.stringify({
            text: stickerPayload,
          }),
        }
      );

      setMessages((prev) => [...prev, res.data]);
      setShowEmojiPicker(false);
      setTimeout(() => scrollToBottom(true), 50);
    } catch {
      toast.error("Không thể gửi nhãn dán");
    } finally {
      setSending(false);
    }
  };

  const handleInsertEmoji = (emoji: string) => {
    setInputText((prev) => prev + emoji);
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  };

  const participant = conversation?.participant;
  const isOnline = participant?.isOnline ?? false;
  const lastSeenText = isOnline
    ? "Đang hoạt động"
    : participant?.lastSeenAt
    ? `Hoạt động ${timeAgo(participant.lastSeenAt)}`
    : "Không hoạt động";

  return (
    <div
      className={`flex flex-col h-full bg-surface-muted dark:bg-appBg-dark overflow-hidden ${className}`}
    >
      <input
        ref={fileInputRef}
        type="file"
        multiple
        accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.zip"
        onChange={handlePickFiles}
        className="hidden"
      />

      {/* Header bar */}
      <div className="p-3.5 sm:px-6 bg-white dark:bg-surface-dark border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between z-10 select-none">
        <div className="flex items-center gap-3 min-w-0">
          {onBack && (
            <button
              onClick={onBack}
              className="p-1.5 -ml-1 text-appText-secondary hover:text-appText-primary dark:hover:text-white rounded-lg md:hidden"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
          )}

          {participant ? (
            <Link
              href={`/profile/${participant.id}`}
              className="flex items-center gap-3 min-w-0 hover:opacity-85 transition"
            >
              <UserAvatar
                name={participant.name}
                imageUrl={participant.avatarUrl}
                size="md"
                isOnline={isOnline}
              />
              <div className="min-w-0">
                <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                  {participant.name}
                </p>
                <p className="text-xs text-appText-secondary truncate">
                  {lastSeenText}
                </p>
              </div>
            </Link>
          ) : (
            <div className="w-32 h-6 bg-surface-muted dark:bg-surface-dark-muted rounded animate-pulse" />
          )}
        </div>
      </div>

      {/* Messages Scroll Area */}
      <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-3">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center text-appText-secondary">
            <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
            <span className="text-xs">Đang tải tin nhắn...</span>
          </div>
        ) : messages.length === 0 ? (
          <div className="py-24 text-center text-appText-secondary">
            <UserAvatar
              name={participant?.name}
              imageUrl={participant?.avatarUrl}
              size="lg"
              className="mx-auto mb-3"
            />
            <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
              {participant?.name}
            </p>
            <p className="text-xs text-appText-secondary mt-0.5">
              Hãy gửi tin nhắn đầu tiên để bắt đầu trò chuyện!
            </p>
          </div>
        ) : (
          messages.map((msg) => {
            const isMine = msg.senderId === currentUser?.id;
            const sticker = parseStickerMessage(msg.text);

            if (sticker) {
              return (
                <div
                  key={msg.id}
                  className={`flex flex-col ${isMine ? "items-end" : "items-start"}`}
                >
                  <div className="relative group p-1 select-none">
                    {sticker.url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={sticker.url}
                        alt="Nhãn dán"
                        className="w-28 h-28 sm:w-36 sm:h-36 object-contain hover:scale-105 active:scale-95 transition-transform duration-200 drop-shadow-md cursor-pointer"
                        loading="lazy"
                      />
                    ) : (
                      <span className="text-sm text-appText-secondary">[Nhãn dán]</span>
                    )}
                  </div>
                  <span className="text-[10px] text-appText-secondary mt-0.5 px-2">
                    {timeAgo(msg.createdAt)}
                  </span>
                </div>
              );
            }

            return (
              <div
                key={msg.id}
                className={`flex flex-col ${isMine ? "items-end" : "items-start"}`}
              >
                <div
                  className={`max-w-[85%] sm:max-w-[70%] rounded-2xl p-3 shadow-xs space-y-2 ${
                    isMine
                      ? "bg-brand text-white rounded-br-xs"
                      : "bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-appText-dark-primary border border-appBorder-light/80 dark:border-appBorder-dark/80 rounded-bl-xs"
                  }`}
                >
                  {/* Attachments */}
                  {msg.attachments && msg.attachments.length > 0 && (
                    <div className="space-y-1.5">
                      {msg.attachments.map((att) => {
                        if (att.type === "image") {
                          return (
                            <button
                              key={att.id}
                              type="button"
                              onClick={() => {
                                setViewerImages([att.url]);
                                setViewerIndex(0);
                              }}
                              className="block rounded-xl overflow-hidden max-h-60 max-w-full cursor-pointer hover:opacity-95 transition"
                            >
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={att.url}
                                alt={att.name}
                                className="w-full h-full object-cover max-h-60"
                              />
                            </button>
                          );
                        }

                        // File attachment
                        return (
                          <a
                            key={att.id}
                            href={att.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            download
                            className={`flex items-center gap-2.5 p-2 rounded-xl text-xs font-medium transition ${
                              isMine
                                ? "bg-white/15 hover:bg-white/25 text-white"
                                : "bg-surface-muted dark:bg-appBorder-dark hover:bg-appBorder-light text-appText-primary dark:text-appText-dark-primary"
                            }`}
                          >
                            <FileIcon className="w-4 h-4 flex-shrink-0" />
                            <div className="min-w-0 flex-1 truncate">
                              <p className="truncate">{att.name}</p>
                              <span className="opacity-70 text-[10px]">
                                {formatFileSize(att.sizeBytes)}
                              </span>
                            </div>
                            <Download className="w-4 h-4 flex-shrink-0 opacity-70" />
                          </a>
                        );
                      })}
                    </div>
                  )}

                  {/* Message Text */}
                  {msg.text && (
                    <p className="text-sm whitespace-pre-wrap break-words leading-relaxed">
                      {msg.text}
                    </p>
                  )}
                </div>

                <span className="text-[10px] text-appText-secondary mt-1 px-1">
                  {timeAgo(msg.createdAt)}
                </span>
              </div>
            );
          })
        )}

        {/* Partner Typing Indicator */}
        {isPartnerTyping && (
          <div className="flex items-center gap-2 text-appText-secondary text-xs italic pl-2 animate-pulse">
            <div className="flex gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-slate-400 animate-bounce" />
              <span className="w-1.5 h-1.5 rounded-full bg-slate-400 animate-bounce [animation-delay:0.2s]" />
              <span className="w-1.5 h-1.5 rounded-full bg-slate-400 animate-bounce [animation-delay:0.4s]" />
            </div>
            <span>{participant?.name || "Bạn chat"} đang gõ...</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Pending Attachments Strip */}
      {pendingFiles.length > 0 && (
        <div className="p-2 sm:px-4 bg-white dark:bg-surface-dark border-t border-appBorder-light dark:border-appBorder-dark flex items-center gap-2 overflow-x-auto">
          {pendingFiles.map((file, idx) => (
            <div
              key={idx}
              className="relative p-1.5 pr-6 bg-surface-muted dark:bg-surface-dark-muted rounded-xl text-xs flex items-center gap-2 flex-shrink-0 border border-appBorder-light dark:border-appBorder-dark"
            >
              {pendingPreviews[idx] ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={pendingPreviews[idx]}
                  alt=""
                  className="w-8 h-8 rounded-lg object-cover"
                />
              ) : (
                <FileIcon className="w-4 h-4 text-appText-secondary ml-1" />
              )}
              <span className="max-w-[120px] truncate text-appText-primary dark:text-appText-dark-primary">
                {file.name}
              </span>
              <button
                type="button"
                onClick={() => handleRemoveFile(idx)}
                className="absolute right-1 top-1/2 -translate-y-1/2 p-1 text-appText-secondary hover:text-red-500"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Floating Emoji & Sticker Picker */}
      {showEmojiPicker && (
        <div className="p-3 bg-transparent flex justify-start sm:justify-end z-30">
          <EmojiStickerPicker
            onSelectEmoji={handleInsertEmoji}
            onSelectSticker={handleSendSticker}
            onClose={() => setShowEmojiPicker(false)}
          />
        </div>
      )}

      {/* Input Area */}
      <form
        onSubmit={handleSendMessage}
        className="p-3 sm:p-4 bg-white dark:bg-surface-dark border-t border-appBorder-light dark:border-appBorder-dark flex items-center gap-2"
      >
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="p-2 rounded-xl text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
          title="Đính kèm tệp / ảnh"
        >
          <Paperclip className="w-5 h-5" />
        </button>

        <button
          type="button"
          onClick={() => setShowEmojiPicker(!showEmojiPicker)}
          className={`p-2 rounded-xl transition flex items-center justify-center ${
            showEmojiPicker
              ? "text-brand bg-brand/10 dark:bg-brand/20"
              : "text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
          }`}
          title="Biểu tượng cảm xúc & Nhãn dán 3D"
        >
          <Smile className="w-5 h-5" />
        </button>

        <input
          type="text"
          value={inputText}
          onChange={handleInputChange}
          placeholder="Nhập tin nhắn..."
          className="flex-1 px-4 py-2.5 rounded-full border border-appBorder-light dark:border-appBorder-dark bg-surface-muted dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm outline-none focus:ring-2 focus:ring-brand focus:border-transparent placeholder-appText-secondary"
        />

        <button
          type="submit"
          disabled={(!inputText.trim() && pendingFiles.length === 0) || sending}
          className="p-2.5 rounded-full bg-brand hover:bg-brand-hover text-white disabled:opacity-40 disabled:cursor-not-allowed transition flex-shrink-0"
          title="Gửi"
        >
          {sending ? (
            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
          ) : (
            <Send className="w-4 h-4" />
          )}
        </button>
      </form>

      {/* Image Lightbox Viewer */}
      {viewerImages.length > 0 && (
        <ImageViewerModal
          images={viewerImages}
          initialIndex={viewerIndex}
          isOpen={viewerImages.length > 0}
          onClose={() => setViewerImages([])}
        />
      )}
    </div>
  );
}
