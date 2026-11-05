"use client";

import React, { useState, useEffect, useCallback, useMemo } from "react";
import Link from "next/link";
import {
  X,
  User,
  Image as ImageIcon,
  FileText,
  Download,
  Palette,
  Check,
  ExternalLink,
  Pin,
} from "lucide-react";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { CHAT_THEMES, getChatTheme } from "@/lib/chat-theme";
import { QUICK_REACTIONS } from "@/lib/quick-reactions";
import { timeAgo } from "@/lib/time-ago";
import { clientFetch } from "@/lib/client-api";
import type { Conversation, Message } from "@/types";

/** One picture or file of the conversation, as `GET /conversations/{id}/media` lists it. */
interface MediaItem {
  id: string;
  messageId: string;
  type: "image" | "file";
  url: string;
  name?: string;
  sizeBytes?: number;
  createdAt?: string;
}

interface MediaPage {
  data: MediaItem[];
  meta: { nextCursor: string | null; hasMore: boolean };
}


function formatFileSize(bytes?: number): string {
  if (!bytes) return "Tệp tin";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

interface SharedMediaDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  conversationId: string;
  participant?: Conversation["participant"];
  /** Only used to notice new pictures, recalls and deletions; the lists come from the server. */
  messages: Message[];
  currentThemeId: string;
  onSelectTheme: (themeId: string) => void;
  quickReaction: string;
  onSelectQuickReaction: (emoji: string) => void;
  onSelectImage: (imageUrl: string) => void;
  pinnedMessage?: Message;
  onJumpToMessage?: (msgId: string) => void;
}

export function SharedMediaDrawer({
  isOpen,
  onClose,
  conversationId,
  participant,
  messages,
  currentThemeId,
  onSelectTheme,
  quickReaction,
  onSelectQuickReaction,
  onSelectImage,
  pinnedMessage,
  onJumpToMessage,
}: SharedMediaDrawerProps) {
  const [activeTab, setActiveTab] = useState<"media" | "files">("media");

  // The messages list only holds the latest page, so pictures and files come from their own paged endpoint.
  const [lists, setLists] = useState<Record<"image" | "file", { items: MediaItem[]; next: string | null; loaded: boolean }>>({
    image: { items: [], next: null, loaded: false },
    file: { items: [], next: null, loaded: false },
  });
  const [loadingMore, setLoadingMore] = useState(false);

  // Changes when a picture/file arrives or a message is recalled, so an open drawer stays correct.
  const signature = useMemo(
    () =>
      messages
        .filter((m) => m.isRecalled || (m.attachments?.length ?? 0) > 0)
        .map((m) => `${m.id}${m.isRecalled ? "r" : ""}`)
        .join(","),
    [messages]
  );

  const loadFirstPages = useCallback(async () => {
    try {
      const [images, files] = await Promise.all(
        (["image", "file"] as const).map((type) =>
          clientFetch<MediaPage>(`/conversations/${conversationId}/media?type=${type}&limit=30`)
        )
      );
      setLists({
        image: { items: images.data, next: images.meta.nextCursor, loaded: true },
        file: { items: files.data, next: files.meta.nextCursor, loaded: true },
      });
    } catch {
      // Keep what is shown; the next change tries again.
    }
  }, [conversationId]);

  useEffect(() => {
    setLists({
      image: { items: [], next: null, loaded: false },
      file: { items: [], next: null, loaded: false },
    });
  }, [conversationId]);

  useEffect(() => {
    if (isOpen) void loadFirstPages();
  }, [isOpen, signature, loadFirstPages]);

  const loadMore = async (type: "image" | "file") => {
    const cursor = lists[type].next;
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const page = await clientFetch<MediaPage>(
        `/conversations/${conversationId}/media?type=${type}&limit=30&cursor=${encodeURIComponent(cursor)}`
      );
      setLists((prev) => ({
        ...prev,
        [type]: { items: [...prev[type].items, ...page.data], next: page.meta.nextCursor, loaded: true },
      }));
    } catch {
      // The button stays, so the person can try again.
    } finally {
      setLoadingMore(false);
    }
  };

  const mediaAttachments = lists.image.items;
  const fileAttachments = lists.file.items;
  const countLabel = (type: "image" | "file") => `${lists[type].items.length}${lists[type].next ? "+" : ""}`;

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 md:relative md:inset-auto md:z-0 flex md:flex-shrink-0 h-full">
      {/* Backdrop for mobile */}
      <div
        className="fixed inset-0 bg-black/40 backdrop-blur-sm md:hidden"
        onClick={onClose}
      />

      {/* Drawer Container (1-screen fixed layout like Messenger) */}
      <div className="relative w-full sm:w-80 lg:w-96 bg-white dark:bg-surface-dark border-l border-appBorder-light dark:border-appBorder-dark h-full flex flex-col shadow-2xl md:shadow-none z-10 overflow-hidden">
        {/* 1. Header (Fixed) */}
        <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between flex-shrink-0">
          <h2 className="text-base font-bold text-appText-primary dark:text-white">
            Chi tiết hội thoại
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-appText-primary dark:hover:text-white transition cursor-pointer"
            title="Đóng"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 2. Top Summary Section (Partner Profile & Themes - Always visible on top) */}
        <div className="p-4 space-y-4 border-b border-appBorder-light/70 dark:border-appBorder-dark/70 flex-shrink-0 bg-surface-muted/30 dark:bg-surface-dark-muted/20">
          {/* User Profile Summary */}
          {participant && (
            <div className="flex flex-col items-center text-center">
              <UserAvatar
                name={participant.name}
                imageUrl={participant.avatarUrl}
                size="lg"
                isOnline={participant.isOnline}
              />
              <h3 className="mt-2 text-base font-bold text-appText-primary dark:text-white">
                {participant.name}
              </h3>
              <p className="text-xs text-appText-secondary">
                {participant.isOnline
                  ? "Đang trực tuyến"
                  : participant.lastSeenAt
                  ? `Hoạt động gần đây`
                  : "Ngoại tuyến"}
              </p>
              <Link
                href={`/profile/${participant.id}`}
                className="mt-2.5 inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-white dark:bg-surface-dark hover:bg-brand/10 dark:hover:bg-brand/20 text-appText-primary dark:text-white hover:text-brand border border-appBorder-light dark:border-appBorder-dark transition shadow-sm"
              >
                <User className="w-3.5 h-3.5" />
                <span>Xem trang cá nhân</span>
                <ExternalLink className="w-3 h-3 ml-0.5 opacity-60" />
              </Link>
            </div>
          )}

          {/* Chat Theme Selection Bar */}
          <div className="space-y-2 pt-1">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <Palette className="w-3.5 h-3.5 text-brand" />
                <span className="text-[11px] font-bold uppercase tracking-wider text-appText-secondary">
                  Chủ đề đoạn chat
                </span>
              </div>
              <span className="text-xs text-brand font-semibold">
                {getChatTheme(currentThemeId).name}
              </span>
            </div>

            <div className="flex items-center justify-between gap-1.5 bg-white dark:bg-surface-dark p-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark">
              {CHAT_THEMES.map((theme) => {
                const isSelected = theme.id === currentThemeId;
                return (
                  <button
                    key={theme.id}
                    type="button"
                    onClick={() => onSelectTheme(theme.id)}
                    className="flex flex-col items-center gap-1 cursor-pointer group"
                    title={theme.name}
                  >
                    <div
                      className={`w-7 h-7 rounded-full flex items-center justify-center transition-transform ${
                        isSelected
                          ? `ring-2 ring-offset-2 dark:ring-offset-surface-dark ${theme.ringColor} scale-110 shadow-sm`
                          : "group-hover:scale-105 opacity-80 hover:opacity-100"
                      }`}
                      style={{ background: theme.colorPreview }}
                    >
                      {isSelected && <Check className="w-3.5 h-3.5 text-white drop-shadow-md" />}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Quick send emoji (the button shown while the message box is empty) */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-appText-secondary">
                Biểu tượng cảm xúc nhanh
              </span>
              <span className="text-lg leading-none">{quickReaction}</span>
            </div>
            <div className="grid grid-cols-6 gap-1 bg-white dark:bg-surface-dark p-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark">
              {QUICK_REACTIONS.map((emoji) => (
                <button
                  key={emoji}
                  type="button"
                  onClick={() => onSelectQuickReaction(emoji)}
                  className={`text-xl p-1 rounded-lg hover:scale-110 transition cursor-pointer ${
                    emoji === quickReaction ? "bg-brand/10 ring-1 ring-brand" : "hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                  }`}
                  title={`Dùng ${emoji}`}
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>

          {/* Pinned Message Banner */}
          {pinnedMessage && (
            <div className="p-2.5 bg-amber-500/10 dark:bg-amber-500/15 border border-amber-500/20 rounded-xl space-y-1">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1 text-[11px] font-bold text-amber-600 dark:text-amber-400">
                  <Pin className="w-3 h-3" />
                  <span>Tin nhắn đã ghim</span>
                </div>
                {onJumpToMessage && (
                  <button
                    type="button"
                    onClick={() => onJumpToMessage(pinnedMessage.id)}
                    className="text-[10px] text-amber-700 dark:text-amber-300 font-semibold hover:underline"
                  >
                    Xem vị trí →
                  </button>
                )}
              </div>
              <p className="text-xs text-appText-primary dark:text-white line-clamp-1">
                {pinnedMessage.text || "[Tệp tin đính kèm]"}
              </p>
            </div>
          )}
        </div>

        {/* 3. Pinned Tab Bar (Fixed, never scrolls away) */}
        <div className="flex items-center border-b border-appBorder-light dark:border-appBorder-dark flex-shrink-0 bg-white dark:bg-surface-dark">
          <button
            type="button"
            onClick={() => setActiveTab("media")}
            className={`flex-1 py-3 text-xs font-bold text-center border-b-2 transition flex items-center justify-center gap-1.5 cursor-pointer ${
              activeTab === "media"
                ? "border-brand text-brand"
                : "border-transparent text-appText-secondary hover:text-appText-primary dark:hover:text-white"
            }`}
          >
            <ImageIcon className="w-3.5 h-3.5" />
            <span>Ảnh ({countLabel("image")})</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("files")}
            className={`flex-1 py-3 text-xs font-bold text-center border-b-2 transition flex items-center justify-center gap-1.5 cursor-pointer ${
              activeTab === "files"
                ? "border-brand text-brand"
                : "border-transparent text-appText-secondary hover:text-appText-primary dark:hover:text-white"
            }`}
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Tài liệu & Tệp ({countLabel("file")})</span>
          </button>
        </div>

        {/* 4. Scrollable Media & Files Gallery (Single independent scroll container) */}
        <div className="flex-1 min-h-0 overflow-y-auto p-4">
          {/* Media Tab Content */}
          {activeTab === "media" && (
            <div>
              {mediaAttachments.length === 0 ? (
                <div className="py-12 text-center text-xs text-appText-secondary space-y-2">
                  <ImageIcon className="w-10 h-10 mx-auto opacity-30 stroke-[1.5]" />
                  <p className="font-medium">Chưa có ảnh nào</p>
                  <p className="text-[11px] opacity-75">Tất cả ảnh gửi trong đoạn chat sẽ lưu tại đây.</p>
                </div>
              ) : (
                <div className="grid grid-cols-3 gap-2">
                  {mediaAttachments.map((attachment) => (
                    <button
                      key={attachment.id}
                      type="button"
                      onClick={() => onSelectImage(attachment.url)}
                      className="group relative aspect-square rounded-lg overflow-hidden bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light/60 dark:border-appBorder-dark/60 hover:opacity-90 transition cursor-pointer"
                      title={attachment.createdAt ? timeAgo(attachment.createdAt) : ""}
                    >
                      <img
                        src={attachment.url}
                        alt="shared-media"
                        className="w-full h-full object-cover group-hover:scale-105 transition duration-200"
                      />
                      <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                    </button>
                  ))}
                </div>
              )}
              {lists.image.next && (
                <button
                  type="button"
                  onClick={() => loadMore("image")}
                  disabled={loadingMore}
                  className="mt-3 w-full py-2 rounded-lg text-xs font-semibold text-brand hover:bg-brand/10 transition disabled:opacity-50 cursor-pointer"
                >
                  {loadingMore ? "Đang tải..." : "Xem thêm"}
                </button>
              )}
            </div>
          )}

          {/* Files Tab Content */}
          {activeTab === "files" && (
            <div>
              {fileAttachments.length === 0 ? (
                <div className="py-12 text-center text-xs text-appText-secondary space-y-2">
                  <FileText className="w-10 h-10 mx-auto opacity-30 stroke-[1.5]" />
                  <p className="font-medium">Chưa có tài liệu hoặc tệp tin nào</p>
                  <p className="text-[11px] opacity-75">Các tệp đính kèm được chia sẻ sẽ lưu tại đây.</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {fileAttachments.map((attachment) => (
                    <div
                      key={attachment.id}
                      className="p-2.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light/70 dark:border-appBorder-dark/70 flex items-center justify-between gap-3 text-xs"
                    >
                      <div className="flex items-center gap-2.5 min-w-0 flex-1">
                        <div className="p-2 rounded-lg bg-brand/10 text-brand flex-shrink-0">
                          <FileText className="w-4 h-4" />
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="font-semibold text-appText-primary dark:text-white truncate">
                            {attachment.name || "Tài liệu đính kèm"}
                          </p>
                          <p className="text-[10px] text-appText-secondary">
                            {formatFileSize(attachment.sizeBytes)} • {attachment.createdAt ? timeAgo(attachment.createdAt) : ""}
                          </p>
                        </div>
                      </div>
                      <a
                        href={attachment.url}
                        download
                        target="_blank"
                        rel="noreferrer"
                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-surface-dark text-appText-secondary hover:text-brand transition flex-shrink-0"
                        title="Tải xuống tệp"
                      >
                        <Download className="w-4 h-4" />
                      </a>
                    </div>
                  ))}
                </div>
              )}
              {lists.file.next && (
                <button
                  type="button"
                  onClick={() => loadMore("file")}
                  disabled={loadingMore}
                  className="mt-3 w-full py-2 rounded-lg text-xs font-semibold text-brand hover:bg-brand/10 transition disabled:opacity-50 cursor-pointer"
                >
                  {loadingMore ? "Đang tải..." : "Xem thêm"}
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
