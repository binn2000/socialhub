"use client";

import React, { useState, useMemo } from "react";
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
import { timeAgo } from "@/lib/time-ago";
import type { Conversation, Message, Attachment } from "@/types";

function formatFileSize(bytes?: number): string {
  if (!bytes) return "Tệp tin";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

interface SharedMediaDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  participant?: Conversation["participant"];
  messages: Message[];
  currentThemeId: string;
  onSelectTheme: (themeId: string) => void;
  onSelectImage: (imageUrl: string) => void;
  pinnedMessage?: Message;
  onJumpToMessage?: (msgId: string) => void;
}

export function SharedMediaDrawer({
  isOpen,
  onClose,
  participant,
  messages,
  currentThemeId,
  onSelectTheme,
  onSelectImage,
  pinnedMessage,
  onJumpToMessage,
}: SharedMediaDrawerProps) {
  const [activeTab, setActiveTab] = useState<"media" | "files">("media");

  // Extract all media and files from non-recalled messages
  const { mediaAttachments, fileAttachments } = useMemo(() => {
    const media: { attachment: Attachment; message: Message }[] = [];
    const files: { attachment: Attachment; message: Message }[] = [];

    for (const msg of messages) {
      if (msg.isRecalled) continue;
      for (const att of msg.attachments || []) {
        if (att.type === "image" || att.url.match(/\.(jpeg|jpg|gif|png|webp)($|\?)/i)) {
          media.push({ attachment: att, message: msg });
        } else {
          files.push({ attachment: att, message: msg });
        }
      }
    }
    return { mediaAttachments: media, fileAttachments: files };
  }, [messages]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-y-0 right-0 z-40 flex">
      {/* Backdrop for mobile */}
      <div
        className="fixed inset-0 bg-black/40 backdrop-blur-xs md:hidden"
        onClick={onClose}
      />

      {/* Drawer Container */}
      <div className="relative w-80 sm:w-96 bg-white dark:bg-surface-dark border-l border-appBorder-light dark:border-appBorder-dark h-full flex flex-col shadow-2xl z-50 animate-in slide-in-from-right duration-200">
        {/* Header */}
        <div className="p-4 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
          <h2 className="text-base font-bold text-appText-primary dark:text-white">
            Thông tin hội thoại
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-appText-primary dark:hover:text-white transition"
            title="Đóng"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-6">
          {/* User Profile Summary */}
          {participant && (
            <div className="flex flex-col items-center text-center pb-4 border-b border-appBorder-light/70 dark:border-appBorder-dark/70">
              <UserAvatar
                name={participant.name}
                imageUrl={participant.avatarUrl}
                size="lg"
                isOnline={participant.isOnline}
              />
              <h3 className="mt-3 text-base font-bold text-appText-primary dark:text-white">
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
                className="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-surface-muted dark:bg-surface-dark-muted hover:bg-brand/10 dark:hover:bg-brand/20 text-appText-primary dark:text-white hover:text-brand transition"
              >
                <User className="w-3.5 h-3.5" />
                <span>Xem trang cá nhân</span>
                <ExternalLink className="w-3 h-3 ml-0.5 opacity-60" />
              </Link>
            </div>
          )}

          {/* Chat Theme Selection */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Palette className="w-4 h-4 text-brand" />
                <span className="text-xs font-bold uppercase tracking-wider text-appText-secondary">
                  Chủ đề cuộc trò chuyện
                </span>
              </div>
              <span className="text-xs text-appText-secondary font-medium">
                {getChatTheme(currentThemeId).name}
              </span>
            </div>

            <div className="grid grid-cols-5 gap-2">
              {CHAT_THEMES.map((theme) => {
                const isSelected = theme.id === currentThemeId;
                return (
                  <button
                    key={theme.id}
                    type="button"
                    onClick={() => onSelectTheme(theme.id)}
                    className="flex flex-col items-center gap-1 p-1 rounded-lg hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition cursor-pointer group"
                    title={theme.name}
                  >
                    <div
                      className={`w-9 h-9 rounded-full flex items-center justify-center transition-transform ${
                        isSelected
                          ? `ring-3 ring-offset-2 dark:ring-offset-surface-dark ${theme.ringColor} scale-105 shadow-md`
                          : "group-hover:scale-105"
                      }`}
                      style={{ background: theme.colorPreview }}
                    >
                      {isSelected && <Check className="w-4 h-4 text-white drop-shadow-md" />}
                    </div>
                    <span
                      className={`text-[10px] text-center truncate max-w-full ${
                        isSelected
                          ? "font-bold text-appText-primary dark:text-white"
                          : "text-appText-secondary"
                      }`}
                    >
                      {theme.name}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Pinned Message Section */}
          {pinnedMessage && (
            <div className="p-3 bg-amber-500/10 dark:bg-amber-500/15 border border-amber-500/20 rounded-xl space-y-1.5">
              <div className="flex items-center gap-1.5 text-xs font-bold text-amber-600 dark:text-amber-400">
                <Pin className="w-3.5 h-3.5" />
                <span>Tin nhắn đang ghim</span>
              </div>
              <p className="text-xs text-appText-primary dark:text-white line-clamp-2">
                {pinnedMessage.text || "[Tệp tin đính kèm]"}
              </p>
              {onJumpToMessage && (
                <button
                  type="button"
                  onClick={() => onJumpToMessage(pinnedMessage.id)}
                  className="text-[11px] text-amber-700 dark:text-amber-300 font-semibold hover:underline"
                >
                  Nhảy tới tin nhắn này →
                </button>
              )}
            </div>
          )}

          {/* Shared Media & Files Section */}
          <div className="space-y-3 pt-2">
            <div className="flex items-center border-b border-appBorder-light dark:border-appBorder-dark">
              <button
                type="button"
                onClick={() => setActiveTab("media")}
                className={`flex-1 pb-2.5 text-xs font-bold text-center border-b-2 transition flex items-center justify-center gap-1.5 cursor-pointer ${
                  activeTab === "media"
                    ? "border-brand text-brand"
                    : "border-transparent text-appText-secondary hover:text-appText-primary dark:hover:text-white"
                }`}
              >
                <ImageIcon className="w-3.5 h-3.5" />
                <span>Ảnh & Video ({mediaAttachments.length})</span>
              </button>
              <button
                type="button"
                onClick={() => setActiveTab("files")}
                className={`flex-1 pb-2.5 text-xs font-bold text-center border-b-2 transition flex items-center justify-center gap-1.5 cursor-pointer ${
                  activeTab === "files"
                    ? "border-brand text-brand"
                    : "border-transparent text-appText-secondary hover:text-appText-primary dark:hover:text-white"
                }`}
              >
                <FileText className="w-3.5 h-3.5" />
                <span>Tài liệu & Tệp ({fileAttachments.length})</span>
              </button>
            </div>

            {/* Media Tab Content */}
            {activeTab === "media" && (
              <div>
                {mediaAttachments.length === 0 ? (
                  <div className="py-8 text-center text-xs text-appText-secondary space-y-1">
                    <ImageIcon className="w-8 h-8 mx-auto opacity-30 stroke-[1.5]" />
                    <p>Chưa có ảnh hoặc video nào được gửi trong cuộc trò chuyện này.</p>
                  </div>
                ) : (
                  <div className="grid grid-cols-3 gap-2 max-h-80 overflow-y-auto pr-1">
                    {mediaAttachments.map(({ attachment, message }, idx) => (
                      <button
                        key={`${attachment.id || idx}-${attachment.url}`}
                        type="button"
                        onClick={() => onSelectImage(attachment.url)}
                        className="group relative aspect-square rounded-lg overflow-hidden bg-surface-muted dark:bg-surface-dark-muted border border-appBorder-light/60 dark:border-appBorder-dark/60 hover:opacity-90 transition cursor-pointer"
                        title={message.createdAt ? timeAgo(message.createdAt) : ""}
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
              </div>
            )}

            {/* Files Tab Content */}
            {activeTab === "files" && (
              <div>
                {fileAttachments.length === 0 ? (
                  <div className="py-8 text-center text-xs text-appText-secondary space-y-1">
                    <FileText className="w-8 h-8 mx-auto opacity-30 stroke-[1.5]" />
                    <p>Chưa có tài liệu hoặc tệp tin nào được chia sẻ.</p>
                  </div>
                ) : (
                  <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
                    {fileAttachments.map(({ attachment, message }, idx) => (
                      <div
                        key={`${attachment.id || idx}-${attachment.url}`}
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
                              {formatFileSize(attachment.sizeBytes)} • {message.createdAt ? timeAgo(message.createdAt) : ""}
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
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
