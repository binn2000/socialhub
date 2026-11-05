"use client";

import React, { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { MessageCircle, Plus, Loader2 } from "lucide-react";
import { ConversationList } from "@/components/chat/ConversationList";
import { ChatPane } from "@/components/chat/ChatPane";
import { NewConversationModal } from "@/components/chat/NewConversationModal";
import { clientFetch } from "@/lib/client-api";
import type { Conversation } from "@/types";

function MessagesContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const targetUserId = searchParams.get("user");

  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);
  const [loadingTargetUser, setLoadingTargetUser] = useState(false);
  const [newChatModalOpen, setNewChatModalOpen] = useState(false);

  // If ?user=<userId> is passed, create or find conversation with that user
  useEffect(() => {
    if (!targetUserId) return;

    let isMounted = true;
    const initConversationWithUser = async () => {
      setLoadingTargetUser(true);
      try {
        const res = await clientFetch<{ data: Conversation }>(
          "/api/proxy/conversations",
          {
            method: "POST",
            body: JSON.stringify({ userId: targetUserId }),
          }
        );
        if (isMounted && res.data) {
          setSelectedConversationId(res.data.id);
        }
      } catch (err) {
        console.error("Failed to start conversation with user:", err);
      } finally {
        if (isMounted) {
          setLoadingTargetUser(false);
        }
      }
    };

    initConversationWithUser();

    return () => {
      isMounted = false;
    };
  }, [targetUserId]);

  const handleSelectConversation = (conversation: Conversation) => {
    setSelectedConversationId(conversation.id);
  };

  const handleConversationCreated = (conversation: Conversation) => {
    setNewChatModalOpen(false);
    setSelectedConversationId(conversation.id);
  };

  return (
    <div className="flex h-full w-full bg-surface-light dark:bg-surface-dark overflow-hidden">
      {/* Left Column: Conversation List */}
      {/* On desktop: always visible (w-80 or w-96) */}
      {/* On mobile: visible when NO conversation is selected, or hidden if conversation is open */}
      <div
        className={`w-full md:w-80 lg:w-96 shrink-0 border-r border-appBorder-light dark:border-appBorder-dark h-full flex flex-col ${
          selectedConversationId ? "hidden md:flex" : "flex"
        }`}
      >
        <ConversationList
          selectedId={selectedConversationId}
          onSelectConversation={handleSelectConversation}
          className="h-full"
        />
      </div>

      {/* Right Column: Chat Window or Empty Placeholder */}
      {/* On mobile: visible only when a conversation is selected */}
      {/* On desktop: always takes remaining flex-1 space */}
      <div
        className={`flex-1 h-full flex flex-col overflow-hidden ${
          !selectedConversationId ? "hidden md:flex" : "flex"
        }`}
      >
        {loadingTargetUser ? (
          <div className="flex-1 flex flex-col items-center justify-center p-8 text-center bg-surface-muted/30 dark:bg-surface-dark-muted/30">
            <Loader2 className="w-8 h-8 text-brand animate-spin mb-3" />
            <p className="text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary">
              Đang mở cuộc trò chuyện...
            </p>
          </div>
        ) : selectedConversationId ? (
          <ChatPane
            conversationId={selectedConversationId}
            onBack={() => setSelectedConversationId(null)}
            className="h-full"
          />
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center p-8 text-center bg-surface-muted/30 dark:bg-surface-dark-muted/30">
            <div className="w-20 h-20 rounded-full bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand mb-4 shadow-sm">
              <MessageCircle size={40} />
            </div>
            <h2 className="text-xl font-bold text-appText-primary dark:text-appText-dark-primary mb-2">
              Tin nhắn của bạn
            </h2>
            <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary max-w-sm mb-6 leading-relaxed">
              Chọn một đoạn chat bên trái hoặc bắt đầu cuộc trò chuyện mới để kết nối và nhắn tin với bạn bè.
            </p>
            <button
              onClick={() => setNewChatModalOpen(true)}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-brand hover:bg-brand-hover text-white text-sm font-medium shadow-sm shadow-brand/25 active:scale-95 transition-all"
            >
              <Plus size={18} />
              <span>Bắt đầu đoạn chat mới</span>
            </button>
          </div>
        )}
      </div>

      {/* New conversation modal if opened from empty placeholder */}
      {newChatModalOpen && (
        <NewConversationModal
          isOpen={newChatModalOpen}
          onClose={() => setNewChatModalOpen(false)}
          onConversationStarted={handleConversationCreated}
        />
      )}
    </div>
  );
}

export default function MessagesPage() {
  return (
    <Suspense
      fallback={
        <div className="flex h-[calc(100vh-4rem)] md:h-screen w-full items-center justify-center bg-surface-light dark:bg-surface-dark">
          <Loader2 className="w-8 h-8 text-brand animate-spin" />
        </div>
      }
    >
      <MessagesContent />
    </Suspense>
  );
}
