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
  Reply,
  Copy,
  Undo2,
  Trash2,
  Forward,
  MoreHorizontal,
  Check,
  CheckCheck,
  Pin,
  PinOff,
  Search,
  ChevronUp,
  ChevronDown,
  Info,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { timeAgo } from "@/lib/time-ago";
import { clientFetch } from "@/lib/client-api";
import { useAuth } from "@/context/AuthContext";
import { useBadges } from "@/context/BadgeContext";
import { useToast } from "@/context/ToastContext";
import { ImageViewerModal } from "@/components/feed/ImageViewerModal";
import { parseStickerMessage, StickerItem } from "@/lib/chat-emojis-stickers";
import {
  MESSAGE_REACTIONS,
  parseReplyMessage,
  buildReplyPayload,
  type QuotedMessage,
} from "@/lib/chat-interactions";
import { oldestFirst } from "@/lib/messages";
import { EmojiStickerPicker } from "./EmojiStickerPicker";
import type { Conversation, Message, Attachment } from "@/types";
import { applyStates, withMyReaction, type MessageState } from "@/lib/message-state";
import { lastSeenOfMine, sendState } from "@/lib/message-status";
import { findMatchingMessageIds } from "@/lib/chat-search";
import { ForwardMessageModal } from "./ForwardMessageModal";
import { SharedMediaDrawer } from "./SharedMediaDrawer";
import { getChatTheme } from "@/lib/chat-theme";

/** The extra things a messages answer carries (`meta`). */
interface ChatMeta {
  otherTyping?: boolean;
  states?: Record<string, MessageState>;
  partnerLastDeliveredMessageId?: string | null;
  partnerLastReadMessageId?: string | null;
  pinnedMessage?: Message | null;
}

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

  // Reply / Quote state
  const [replyingTo, setReplyingTo] = useState<QuotedMessage | null>(null);

  // Forward dialog: the message being forwarded.
  const [forwarding, setForwarding] = useState<Message | null>(null);

  // Context Menu State
  const [contextMenu, setContextMenu] = useState<{
    msg: Message;
    x: number;
    y: number;
  } | null>(null);

  // Search state
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [currentMatchIndex, setCurrentMatchIndex] = useState(0);

  // Pinned message (shared by both people) and how far the other person has fetched and read.
  const [pinnedMessage, setPinnedMessage] = useState<Message | null>(null);
  const pinnedMessageId = pinnedMessage?.id ?? null;
  const [partnerDeliveredId, setPartnerDeliveredId] = useState<string | null>(null);
  const [partnerReadId, setPartnerReadId] = useState<string | null>(null);

  // Lightbox
  const [viewerImages, setViewerImages] = useState<string[]>([]);
  const [viewerIndex, setViewerIndex] = useState(0);

  // Chat theme & Shared Media Drawer state
  const [chatThemeId, setChatThemeId] = useState<string>("blue");
  const [showMediaDrawer, setShowMediaDrawer] = useState(false);

  // Close context menu when clicking outside
  useEffect(() => {
    const handleCloseMenu = () => setContextMenu(null);
    window.addEventListener("click", handleCloseMenu);
    return () => window.removeEventListener("click", handleCloseMenu);
  }, []);

  const handleTogglePin = useCallback(
    async (msgId: string) => {
      const unpin = pinnedMessage?.id === msgId;
      try {
        const res = await clientFetch<{ data: { pinnedMessage: Message | null } }>(
          `/api/proxy/conversations/${conversationId}/pin`,
          unpin
            ? { method: "DELETE" }
            : { method: "PUT", body: JSON.stringify({ messageId: msgId }) }
        );
        setPinnedMessage(res.data.pinnedMessage);
        toast.info(unpin ? "Đã bỏ ghim tin nhắn" : "Đã ghim tin nhắn cho cả hai người");
      } catch {
        toast.error("Không thể ghim tin nhắn lúc này");
      }
    },
    [conversationId, pinnedMessage?.id, toast]
  );

  useEffect(() => {
    if (!conversationId) return;
    try {
      const storedTheme = localStorage.getItem(`chat_theme_${conversationId}`);
      if (storedTheme) {
        setChatThemeId(storedTheme);
      } else {
        setChatThemeId("blue");
      }
    } catch {
      // Ignore
    }
  }, [conversationId]);

  const handleSelectTheme = useCallback((themeId: string) => {
    setChatThemeId(themeId);
    try {
      localStorage.setItem(`chat_theme_${conversationId}`, themeId);
    } catch {
      // Ignore
    }
    toast.success(`Đã đổi chủ đề sang ${getChatTheme(themeId).name}`);
  }, [conversationId, toast]);

  const replaceMessage = useCallback((updated: Message) => {
    setMessages((prev) => prev.map((m) => (m.id === updated.id ? updated : m)));
  }, []);

  const handleToggleReaction = useCallback(
    async (msgId: string, emoji: string) => {
      const before = messages.find((m) => m.id === msgId);
      if (!before || before.isRecalled) return;
      const taking = before.myReaction === emoji; // the same one again takes it back
      replaceMessage(withMyReaction(before, taking ? null : emoji));

      try {
        const res = await clientFetch<{ data: Message }>(
          `/api/proxy/conversations/${conversationId}/messages/${msgId}/reaction`,
          taking
            ? { method: "DELETE" }
            : { method: "PUT", body: JSON.stringify({ emoji }) }
        );
        replaceMessage(res.data);
      } catch {
        replaceMessage(before);
        toast.error("Không thể thả cảm xúc lúc này");
      }
    },
    [messages, conversationId, replaceMessage, toast]
  );

  const handleStartReply = useCallback((msg: Message) => {
    const isMine = msg.senderId === currentUser?.id;
    const authorName = isMine ? "Chính bạn" : (conversation?.participant?.name || "Đối phương");
    const sticker = parseStickerMessage(msg.text);
    const snippet = sticker
      ? "[Nhãn dán 3D]"
      : msg.attachments && msg.attachments.length > 0
      ? `[${msg.attachments[0].type === "image" ? "Hình ảnh" : "Tệp tin"}] ${msg.text || ""}`
      : msg.text || "Tin nhắn";

    setReplyingTo({
      id: msg.id,
      senderName: authorName,
      text: snippet,
    });
  }, [currentUser?.id, conversation?.participant?.name]);

  const handleCopyMessage = useCallback((msg: Message) => {
    const parsed = parseReplyMessage(msg.text);
    const textToCopy = parsed.text || msg.text || "";
    if (textToCopy) {
      navigator.clipboard.writeText(textToCopy);
      toast.success("Đã sao chép tin nhắn vào bộ nhớ tạm");
    } else {
      toast.info("Không có nội dung văn bản để sao chép");
    }
  }, [toast]);

  const handleUnsendMessage = useCallback(
    async (msgId: string) => {
      try {
        const res = await clientFetch<{ data: Message }>(
          `/api/proxy/conversations/${conversationId}/messages/${msgId}`,
          { method: "DELETE" }
        );
        replaceMessage(res.data);
        toast.info("Đã thu hồi tin nhắn");
      } catch {
        toast.error("Không thể thu hồi tin nhắn lúc này");
      }
    },
    [conversationId, replaceMessage, toast]
  );

  const handleDeleteMessage = useCallback(
    async (msgId: string) => {
      try {
        await clientFetch(`/api/proxy/conversations/${conversationId}/messages/${msgId}/hide`, {
          method: "PUT",
        });
        setMessages((prev) => prev.filter((m) => m.id !== msgId));
        setReplyingTo((current) => (current?.id === msgId ? null : current));
        toast.info("Đã xóa tin nhắn ở phía bạn");
      } catch {
        toast.error("Không thể xóa tin nhắn lúc này");
      }
    },
    [conversationId, toast]
  );

  const handleForwardMessage = useCallback(
    (msg: Message) => {
      const parsed = parseReplyMessage(msg.text);
      if (!(parsed.text || msg.text)) {
        toast.info("Chưa thể chuyển tiếp ảnh hoặc tệp");
        return;
      }
      setForwarding(msg);
    },
    [toast]
  );

  const scrollToMessage = useCallback((msgId: string) => {
    const el = document.getElementById(`msg-${msgId}`);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "center" });
      el.classList.add("ring-2", "ring-brand", "ring-offset-2");
      setTimeout(() => {
        el.classList.remove("ring-2", "ring-brand", "ring-offset-2");
      }, 1500);
    } else {
      toast.info("Tin nhắn gốc ở vị trí xa hơn trong lịch sử");
    }
  }, [toast]);

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
  /** What the server says besides the messages: the other person's markers and the pin. */
  const applyChatMeta = useCallback((meta?: ChatMeta) => {
    if (!meta) return;
    if (meta.partnerLastDeliveredMessageId !== undefined) setPartnerDeliveredId(meta.partnerLastDeliveredMessageId);
    if (meta.partnerLastReadMessageId !== undefined) setPartnerReadId(meta.partnerLastReadMessageId);
    if (meta.pinnedMessage !== undefined) setPinnedMessage(meta.pinnedMessage);
  }, []);

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
        meta?: ChatMeta;
      }>(`/api/proxy/conversations/${conversationId}/messages?limit=100`);
      applyChatMeta(msgRes.meta);

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
  }, [conversationId, scrollToBottom, applyChatMeta]);

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
          meta?: ChatMeta;
        }>(`/api/proxy/conversations/${conversationId}/messages${query}`);

        setIsPartnerTyping(Boolean(res.meta?.otherTyping));
        applyChatMeta(res.meta);
        // Reactions and recalls on messages we already have.
        setMessages((prev) => applyStates(prev, res.meta?.states));

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
  }, [conversationId, messages, currentUser?.id, sending, scrollToBottom, applyChatMeta]);

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

    // Format with reply envelope if replying to a message
    const finalPayload = replyingTo && text
      ? buildReplyPayload(replyingTo, text)
      : text;

    if (finalPayload) formData.append("text", finalPayload);

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
      setReplyingTo(null);
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
      let stickerPayload = `[sticker:${sticker.id}:${sticker.url}]`;
      if (replyingTo) {
        stickerPayload = buildReplyPayload(replyingTo, stickerPayload);
      }
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
      setReplyingTo(null);
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

  const visibleMessages = messages;

  // Search filter and matching IDs
  const matchingMessageIds = React.useMemo(
    () => findMatchingMessageIds(visibleMessages, searchQuery),
    [searchQuery, visibleMessages]
  );

  const handlePrevMatch = () => {
    if (matchingMessageIds.length === 0) return;
    const nextIdx =
      (currentMatchIndex - 1 + matchingMessageIds.length) % matchingMessageIds.length;
    setCurrentMatchIndex(nextIdx);
    scrollToMessage(matchingMessageIds[nextIdx]);
  };

  const handleNextMatch = () => {
    if (matchingMessageIds.length === 0) return;
    const nextIdx = (currentMatchIndex + 1) % matchingMessageIds.length;
    setCurrentMatchIndex(nextIdx);
    scrollToMessage(matchingMessageIds[nextIdx]);
  };

  const lastSeenId = lastSeenOfMine(visibleMessages, currentUser?.id, partnerReadId);

  const activeTheme = getChatTheme(chatThemeId);

  /** Ticks under one of my messages; the other person's small avatar marks the last one they have seen. */
  const renderSendStatus = (msg: Message) => {
    const state = sendState(msg.id, partnerDeliveredId, partnerReadId);
    return (
      <span className="flex items-center gap-1 ml-1">
        {state === "sent" && (
          <span title="Đã gửi" className="flex items-center">
            <Check className="w-3.5 h-3.5 text-appText-secondary/70" />
          </span>
        )}
        {state === "delivered" && (
          <span title="Đã nhận" className="flex items-center">
            <CheckCheck className="w-3.5 h-3.5 text-appText-secondary/70" />
          </span>
        )}
        {state === "seen" && (
          <span title="Đã xem" className="flex items-center">
            <CheckCheck className="w-3.5 h-3.5 text-brand" />
          </span>
        )}
        {msg.id === lastSeenId && (
          <span className="flex items-center gap-1" title="Đã xem">
            <UserAvatar
              name={participant?.name}
              imageUrl={participant?.avatarUrl}
              size="xs"
              className="w-3.5 h-3.5 text-[8px]"
            />
            <span className="text-[9px] text-brand font-medium">Đã xem</span>
          </span>
        )}
      </span>
    );
  };

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
            <div
              onClick={() => setShowMediaDrawer(true)}
              className="flex items-center gap-3 min-w-0 hover:opacity-85 transition cursor-pointer"
              title="Xem thông tin hội thoại & tệp chia sẻ"
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
            </div>
          ) : (
            <div className="w-32 h-6 bg-surface-muted dark:bg-surface-dark-muted rounded animate-pulse" />
          )}
        </div>

        {/* Header Right Actions */}
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => {
              setShowSearch(!showSearch);
              if (showSearch) setSearchQuery("");
            }}
            className={`p-2 rounded-xl transition cursor-pointer ${
              showSearch
                ? "text-brand bg-brand/10 dark:bg-brand/20"
                : "text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
            }`}
            title="Tìm kiếm nội dung tin nhắn"
          >
            <Search className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={() => setShowMediaDrawer(!showMediaDrawer)}
            className={`p-2 rounded-xl transition cursor-pointer ${
              showMediaDrawer
                ? "text-brand bg-brand/10 dark:bg-brand/20"
                : "text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
            }`}
            title="Thông tin hội thoại, chủ đề & tệp chia sẻ"
          >
            <Info className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* In-Chat Search Bar */}
      {showSearch && (
        <div className="px-4 py-2.5 bg-surface-muted/90 dark:bg-surface-dark-muted/80 border-b border-appBorder-light dark:border-appBorder-dark flex items-center gap-2 text-xs animate-in fade-in slide-in-from-top-2 duration-150 select-none">
          <Search className="w-4 h-4 text-appText-secondary flex-shrink-0" />
          <input
            type="text"
            autoFocus
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setCurrentMatchIndex(0);
            }}
            placeholder="Tìm kiếm trong cuộc trò chuyện..."
            className="flex-1 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-lg px-3 py-1.5 text-xs text-appText-primary dark:text-white outline-none focus:ring-1 focus:ring-brand"
          />

          {searchQuery.trim() && (
            <div className="flex items-center gap-1 text-[11px] text-appText-secondary flex-shrink-0">
              <span>
                {matchingMessageIds.length > 0
                  ? `${currentMatchIndex + 1}/${matchingMessageIds.length}`
                  : "Không tìm thấy"}
              </span>
              <button
                type="button"
                disabled={matchingMessageIds.length === 0}
                onClick={handlePrevMatch}
                className="p-1 rounded hover:bg-white dark:hover:bg-surface-dark disabled:opacity-30 cursor-pointer"
                title="Tin nhắn trước"
              >
                <ChevronUp className="w-3.5 h-3.5" />
              </button>
              <button
                type="button"
                disabled={matchingMessageIds.length === 0}
                onClick={handleNextMatch}
                className="p-1 rounded hover:bg-white dark:hover:bg-surface-dark disabled:opacity-30 cursor-pointer"
                title="Tin nhắn tiếp theo"
              >
                <ChevronDown className="w-3.5 h-3.5" />
              </button>
            </div>
          )}

          <button
            type="button"
            onClick={() => {
              setShowSearch(false);
              setSearchQuery("");
            }}
            className="p-1 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-white dark:hover:bg-surface-dark transition cursor-pointer"
            title="Đóng tìm kiếm"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Pinned Message Banner */}
      {pinnedMessage && (
        <div className="px-4 py-2 bg-amber-500/10 dark:bg-amber-400/10 border-b border-amber-500/20 flex items-center justify-between text-xs select-none animate-in fade-in slide-in-from-top-1">
          <div
            onClick={() => scrollToMessage(pinnedMessage.id)}
            className="flex items-center gap-2.5 min-w-0 flex-1 cursor-pointer hover:opacity-85 transition"
            title="Nhấp để cuộn đến tin nhắn đã ghim"
          >
            <Pin className="w-4 h-4 text-amber-600 dark:text-amber-400 flex-shrink-0 fill-amber-600/30" />
            <div className="min-w-0 flex-1">
              <p className="font-bold text-amber-700 dark:text-amber-300 truncate text-xs">
                Tin nhắn đã ghim ({pinnedMessage.senderId === currentUser?.id ? "Bạn" : participant?.name})
              </p>
              <p className="text-appText-secondary dark:text-appText-dark-secondary truncate text-[11px] mt-0.5">
                {parseReplyMessage(pinnedMessage.text).text || pinnedMessage.text}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => handleTogglePin(pinnedMessage.id)}
            className="p-1 text-appText-secondary hover:text-amber-600 transition rounded-full cursor-pointer ml-2"
            title="Bỏ ghim tin nhắn"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {/* Messages Scroll Area */}
      <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-3">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center text-appText-secondary">
            <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
            <span className="text-xs">Đang tải tin nhắn...</span>
          </div>
        ) : visibleMessages.length === 0 ? (
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
          visibleMessages.map((msg) => {
            const isMine = msg.senderId === currentUser?.id;
            const isUnsent = msg.isRecalled;
            const msgRx = msg.reactions || {};
            const rxEntries = Object.entries(msgRx).filter(([, count]) => count > 0);
            const myRx = msg.myReaction ?? undefined;
            const { reply: parsedReply, text: cleanText } = parseReplyMessage(msg.text);
            const sticker = parseStickerMessage(cleanText);

            if (isUnsent) {
              return (
                <div
                  key={msg.id}
                  id={`msg-${msg.id}`}
                  className={`flex flex-col ${isMine ? "items-end" : "items-start"}`}
                >
                  <div className="px-3.5 py-1.5 rounded-2xl border border-dashed border-appBorder-light dark:border-appBorder-dark text-xs italic text-appText-secondary bg-surface-muted/50 dark:bg-surface-dark-muted/30 flex items-center gap-1.5 select-none">
                    <Undo2 className="w-3.5 h-3.5 opacity-60" />
                    <span>Tin nhắn đã được thu hồi</span>
                  </div>
                  <div className="flex items-center gap-1 text-[10px] text-appText-secondary mt-0.5 px-2">
                    <span>{timeAgo(msg.createdAt)}</span>
                    {isMine && renderSendStatus(msg)}
                  </div>
                </div>
              );
            }

            if (sticker) {
              return (
                <div
                  key={msg.id}
                  id={`msg-${msg.id}`}
                  className={`relative group flex flex-col ${isMine ? "items-end" : "items-start"}`}
                  onContextMenu={(e) => {
                    e.preventDefault();
                    setContextMenu({
                      msg,
                      x: Math.min(window.innerWidth - 190, e.clientX),
                      y: Math.min(window.innerHeight - 220, e.clientY),
                    });
                  }}
                >
                  {/* Floating Action Bar on Hover */}
                  <div
                    className={`absolute -top-3.5 ${
                      isMine ? "right-2" : "left-2"
                    } z-20 hidden group-hover:flex items-center gap-1 px-2 py-1 bg-white/95 dark:bg-surface-dark/95 backdrop-blur-md rounded-full shadow-lg border border-appBorder-light dark:border-appBorder-dark select-none animate-in fade-in zoom-in-95 duration-150`}
                  >
                    {MESSAGE_REACTIONS.map((emoji) => (
                      <button
                        key={emoji}
                        type="button"
                        onClick={() => handleToggleReaction(msg.id, emoji)}
                        className={`p-0.5 text-base leading-none transition-transform hover:scale-130 active:scale-95 cursor-pointer rounded-full ${
                          myRx === emoji ? "bg-brand/15 scale-110" : ""
                        }`}
                        title={`Thả ${emoji}`}
                      >
                        {emoji}
                      </button>
                    ))}
                    <div className="h-3.5 w-px bg-appBorder-light dark:bg-appBorder-dark mx-0.5" />
                    <button
                      type="button"
                      onClick={() => handleStartReply(msg)}
                      className="p-1 text-appText-secondary hover:text-brand transition rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted cursor-pointer"
                      title="Trả lời"
                    >
                      <Reply className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        const rect = e.currentTarget.getBoundingClientRect();
                        setContextMenu({
                          msg,
                          x: Math.min(window.innerWidth - 190, rect.left),
                          y: Math.min(window.innerHeight - 220, rect.bottom + 4),
                        });
                      }}
                      className="p-1 text-appText-secondary hover:text-brand transition rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted cursor-pointer"
                      title="Tùy chọn khác"
                    >
                      <MoreHorizontal className="w-3.5 h-3.5" />
                    </button>
                  </div>

                  {/* Quoted Reply Box if sticker was a reply */}
                  {parsedReply && (
                    <div
                      onClick={() => scrollToMessage(parsedReply.id)}
                      className={`p-2 rounded-xl mb-1 text-xs border-l-2 cursor-pointer transition select-none ${
                        isMine
                          ? "bg-white/15 hover:bg-white/25 border-white text-white"
                          : "bg-surface-muted/90 dark:bg-appBorder-dark/60 hover:bg-surface-muted border-brand text-appText-primary dark:text-white"
                      }`}
                      title="Nhấp để chuyển đến tin nhắn gốc"
                    >
                      <div className="flex items-center gap-1 font-semibold text-[11px] opacity-90 truncate">
                        <Reply className="w-3 h-3 rotate-180 flex-shrink-0" />
                        <span className="truncate">{parsedReply.senderName}</span>
                      </div>
                      <p className="text-[11px] truncate opacity-80 mt-0.5">
                        {parsedReply.text}
                      </p>
                    </div>
                  )}

                  <div className="relative p-1 select-none">
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

                    {/* Reaction Badge */}
                    {rxEntries.length > 0 && (
                      <button
                        type="button"
                        onClick={() => handleToggleReaction(msg.id, myRx || "❤️")}
                        className={`absolute -bottom-2 ${
                          isMine ? "right-1" : "left-1"
                        } z-10 flex items-center gap-1 px-1.5 py-0.5 rounded-full bg-white dark:bg-surface-dark shadow-sm border border-appBorder-light dark:border-appBorder-dark text-[11px] font-semibold transition hover:scale-105 active:scale-95 cursor-pointer ${
                          myRx ? "ring-1 ring-brand/40" : ""
                        }`}
                        title="Nhấp để thu hồi cảm xúc"
                      >
                        <span className="flex items-center -space-x-1">
                          {rxEntries.map(([em]) => (
                            <span key={em} className="text-xs">
                              {em}
                            </span>
                          ))}
                        </span>
                        <span className="text-[10px] text-appText-secondary ml-0.5">
                          {rxEntries.reduce((sum, [_, c]) => sum + c, 0)}
                        </span>
                      </button>
                    )}
                  </div>
                  <div className="flex items-center gap-1 text-[10px] text-appText-secondary mt-0.5 px-2">
                    <span>{timeAgo(msg.createdAt)}</span>
                    {isMine && renderSendStatus(msg)}
                  </div>
                </div>
              );
            }

            return (
              <div
                key={msg.id}
                id={`msg-${msg.id}`}
                className={`relative group flex flex-col ${isMine ? "items-end" : "items-start"}`}
                onContextMenu={(e) => {
                  e.preventDefault();
                  setContextMenu({
                    msg,
                    x: Math.min(window.innerWidth - 190, e.clientX),
                    y: Math.min(window.innerHeight - 220, e.clientY),
                  });
                }}
              >
                {/* Floating Action Bar on Hover */}
                <div
                  className={`absolute -top-3.5 ${
                    isMine ? "right-2" : "left-2"
                  } z-20 hidden group-hover:flex items-center gap-1 px-2 py-1 bg-white/95 dark:bg-surface-dark/95 backdrop-blur-md rounded-full shadow-lg border border-appBorder-light dark:border-appBorder-dark select-none animate-in fade-in zoom-in-95 duration-150`}
                >
                  {MESSAGE_REACTIONS.map((emoji) => (
                    <button
                      key={emoji}
                      type="button"
                      onClick={() => handleToggleReaction(msg.id, emoji)}
                      className={`p-0.5 text-base leading-none transition-transform hover:scale-130 active:scale-95 cursor-pointer rounded-full ${
                        myRx === emoji ? "bg-brand/15 scale-110" : ""
                      }`}
                      title={`Thả ${emoji}`}
                    >
                      {emoji}
                    </button>
                  ))}
                  <div className="h-3.5 w-px bg-appBorder-light dark:bg-appBorder-dark mx-0.5" />
                  <button
                    type="button"
                    onClick={() => handleStartReply(msg)}
                    className="p-1 text-appText-secondary hover:text-brand transition rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted cursor-pointer"
                    title="Trả lời"
                  >
                    <Reply className="w-3.5 h-3.5" />
                  </button>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      const rect = e.currentTarget.getBoundingClientRect();
                      setContextMenu({
                        msg,
                        x: Math.min(window.innerWidth - 190, rect.left),
                        y: Math.min(window.innerHeight - 220, rect.bottom + 4),
                      });
                    }}
                    className="p-1 text-appText-secondary hover:text-brand transition rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted cursor-pointer"
                    title="Tùy chọn khác"
                  >
                    <MoreHorizontal className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div
                  className={`relative max-w-[85%] sm:max-w-[70%] rounded-2xl p-3 shadow-xs space-y-2 ${
                    isMine
                      ? activeTheme.bubbleClass
                      : "bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-appText-dark-primary border border-appBorder-light/80 dark:border-appBorder-dark/80 rounded-bl-xs"
                  }`}
                  style={isMine ? activeTheme.bubbleStyle : undefined}
                >
                  {/* Quoted Message Preview Box */}
                  {parsedReply && (
                    <div
                      onClick={() => scrollToMessage(parsedReply.id)}
                      className={`p-2 rounded-xl mb-1.5 text-xs border-l-2 cursor-pointer transition select-none ${
                        isMine
                          ? "bg-white/15 hover:bg-white/25 border-white text-white"
                          : "bg-surface-muted/90 dark:bg-appBorder-dark/60 hover:bg-surface-muted border-brand text-appText-primary dark:text-white"
                      }`}
                      title="Nhấp để chuyển đến tin nhắn gốc"
                    >
                      <div className="flex items-center gap-1 font-semibold text-[11px] opacity-90 truncate">
                        <Reply className="w-3 h-3 rotate-180 flex-shrink-0" />
                        <span className="truncate">{parsedReply.senderName}</span>
                      </div>
                      <p className="text-[11px] truncate opacity-80 mt-0.5">
                        {parsedReply.text}
                      </p>
                    </div>
                  )}

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
                  {cleanText && (
                    <p className="text-sm whitespace-pre-wrap break-words leading-relaxed">
                      {cleanText}
                    </p>
                  )}

                  {/* Reaction Badges */}
                  {rxEntries.length > 0 && (
                    <button
                      type="button"
                      onClick={() => handleToggleReaction(msg.id, myRx || "❤️")}
                      className={`absolute -bottom-2.5 ${
                        isMine ? "right-2" : "left-2"
                      } z-10 flex items-center gap-1 px-1.5 py-0.5 rounded-full bg-white dark:bg-surface-dark shadow-sm border border-appBorder-light dark:border-appBorder-dark text-[11px] font-semibold transition hover:scale-105 active:scale-95 cursor-pointer ${
                        myRx ? "ring-1 ring-brand/40" : ""
                      }`}
                      title="Nhấp để thu hồi cảm xúc"
                    >
                      <span className="flex items-center -space-x-1">
                        {rxEntries.map(([em]) => (
                          <span key={em} className="text-xs">
                            {em}
                          </span>
                        ))}
                      </span>
                      <span className="text-[10px] text-appText-secondary ml-0.5">
                        {rxEntries.reduce((sum, [_, c]) => sum + c, 0)}
                      </span>
                    </button>
                  )}
                </div>

                <div className="flex items-center gap-1 text-[10px] text-appText-secondary mt-1 px-1">
                  <span>{timeAgo(msg.createdAt)}</span>
                  {isMine && renderSendStatus(msg)}
                </div>
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

      {/* Quoted Reply Preview Bar */}
      {replyingTo && (
        <div className="px-4 py-2 bg-brand/5 dark:bg-brand/10 border-t border-brand/20 flex items-center justify-between animate-in fade-in slide-in-from-bottom-2 duration-150">
          <div className="flex items-center gap-2.5 min-w-0 flex-1 border-l-2 border-brand pl-2.5">
            <Reply className="w-4 h-4 text-brand flex-shrink-0" />
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold text-brand truncate">
                Đang trả lời {replyingTo.senderName}
              </p>
              <p className="text-xs text-appText-secondary truncate">
                {replyingTo.text}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setReplyingTo(null)}
            className="p-1 rounded-full text-appText-secondary hover:text-appText-primary dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5 transition cursor-pointer"
            title="Hủy trả lời"
          >
            <X className="w-4 h-4" />
          </button>
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
          className={`p-2.5 rounded-full ${activeTheme.sendBtnClass} disabled:opacity-40 disabled:cursor-not-allowed transition flex-shrink-0`}
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

      {/* Floating Context Menu */}
      {contextMenu && (
        <div
          style={{ left: contextMenu.x, top: contextMenu.y }}
          className="fixed z-50 w-44 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-xl shadow-xl py-1.5 text-xs text-appText-primary dark:text-white animate-in fade-in zoom-in-95 duration-100 select-none"
          onClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            onClick={() => {
              handleStartReply(contextMenu.msg);
              setContextMenu(null);
            }}
            className="w-full px-3 py-2 text-left flex items-center gap-2 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            <Reply className="w-4 h-4 text-brand" />
            <span>Trả lời</span>
          </button>

          <button
            type="button"
            onClick={() => {
              handleCopyMessage(contextMenu.msg);
              setContextMenu(null);
            }}
            className="w-full px-3 py-2 text-left flex items-center gap-2 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            <Copy className="w-4 h-4 text-appText-secondary" />
            <span>Sao chép văn bản</span>
          </button>

          <button
            type="button"
            onClick={() => {
              handleForwardMessage(contextMenu.msg);
              setContextMenu(null);
            }}
            className="w-full px-3 py-2 text-left flex items-center gap-2 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            <Forward className="w-4 h-4 text-blue-500" />
            <span>Chuyển tiếp</span>
          </button>

          <button
            type="button"
            onClick={() => {
              handleTogglePin(contextMenu.msg.id);
              setContextMenu(null);
            }}
            className="w-full px-3 py-2 text-left flex items-center gap-2 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            {pinnedMessageId === contextMenu.msg.id ? (
              <>
                <PinOff className="w-4 h-4 text-amber-500" />
                <span>Bỏ ghim tin nhắn</span>
              </>
            ) : (
              <>
                <Pin className="w-4 h-4 text-amber-500" />
                <span>Ghim tin nhắn</span>
              </>
            )}
          </button>

          <div className="h-px bg-appBorder-light dark:border-appBorder-dark my-1" />

          {contextMenu.msg.senderId === currentUser?.id && (
            <button
              type="button"
              onClick={() => {
                handleUnsendMessage(contextMenu.msg.id);
                setContextMenu(null);
              }}
              className="w-full px-3 py-2 text-left flex items-center gap-2 text-amber-600 dark:text-amber-500 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
            >
              <Undo2 className="w-4 h-4" />
              <span>Thu hồi tin nhắn</span>
            </button>
          )}

          <button
            type="button"
            onClick={() => {
              handleDeleteMessage(contextMenu.msg.id);
              setContextMenu(null);
            }}
            className="w-full px-3 py-2 text-left flex items-center gap-2 text-red-600 dark:text-red-500 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer"
          >
            <Trash2 className="w-4 h-4" />
            <span>Xóa ở phía tôi</span>
          </button>
        </div>
      )}
      {forwarding && (
        <ForwardMessageModal
          message={forwarding}
          currentConversationId={conversationId}
          onClose={() => setForwarding(null)}
        />
      )}
      <SharedMediaDrawer
        isOpen={showMediaDrawer}
        onClose={() => setShowMediaDrawer(false)}
        participant={participant}
        messages={visibleMessages}
        currentThemeId={chatThemeId}
        onSelectTheme={handleSelectTheme}
        onSelectImage={(url) => {
          setViewerImages([url]);
          setViewerIndex(0);
        }}
        pinnedMessage={pinnedMessage ?? undefined}
        onJumpToMessage={(msgId) => {
          setShowMediaDrawer(false);
          scrollToMessage(msgId);
        }}
      />
    </div>
  );
}
