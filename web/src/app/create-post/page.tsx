"use client";

import React from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Sparkles } from "lucide-react";
import { CreatePostCard } from "@/components/feed/CreatePostCard";

export default function CreatePostPage() {
  const router = useRouter();

  return (
    <div className="max-w-xl mx-auto pb-16">
      {/* Mobile Top Header */}
      <div className="flex items-center gap-3 mb-4">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-full hover:bg-surface-muted dark:hover:bg-surface-dark-muted text-appText-secondary hover:text-appText-primary transition"
          title="Quay lại"
        >
          <ArrowLeft size={20} />
        </button>
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-brand/10 dark:bg-brand/20 flex items-center justify-center text-brand">
            <Sparkles size={16} />
          </div>
          <h1 className="text-xl font-bold text-appText-primary dark:text-appText-dark-primary">
            Tạo bài viết
          </h1>
        </div>
      </div>

      <CreatePostCard
        onPostCreated={() => {
          router.push("/");
        }}
      />
    </div>
  );
}
