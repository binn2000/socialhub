"use client";

import React from "react";
import { useParams, useRouter } from "next/navigation";
import { ConversationList } from "@/components/chat/ConversationList";
import { ChatPane } from "@/components/chat/ChatPane";
import type { Conversation } from "@/types";

export default function MessageDetailPage() {
  const params = useParams();
  const router = useRouter();
  const conversationId = Array.isArray(params?.id)
    ? params.id[0]
    : (params?.id as string);

  if (!conversationId) {
    return null;
  }

  const handleSelectConversation = (conversation: Conversation) => {
    if (conversation.id !== conversationId) {
      router.push(`/messages/${conversation.id}`);
    }
  };

  return (
    <div className="flex h-[calc(100vh-4rem)] md:h-screen w-full bg-surface-light dark:bg-surface-dark overflow-hidden">
      {/* Left Column: Conversation List - hidden on mobile, visible on desktop */}
      <div className="hidden md:flex w-80 lg:w-96 shrink-0 border-r border-appBorder-light dark:border-appBorder-dark h-full flex-col">
        <ConversationList
          selectedId={conversationId}
          onSelectConversation={handleSelectConversation}
          className="h-full"
        />
      </div>

      {/* Right Column: Chat Pane - fullscreen on mobile, flex-1 on desktop */}
      <div className="flex-1 h-full flex flex-col overflow-hidden">
        <ChatPane
          conversationId={conversationId}
          onBack={() => router.push("/messages")}
          className="h-full"
        />
      </div>
    </div>
  );
}
