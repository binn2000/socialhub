"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, AlertCircle } from "lucide-react";
import { PostCard } from "@/components/feed/PostCard";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import type { Post } from "@/types";

export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const postId = params.id as string;

  const [post, setPost] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!postId) return;

    const loadPost = async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await clientFetch<{ data: Post }>(`/api/proxy/posts/${postId}`);
        setPost(res.data);
      } catch (err) {
        if (err instanceof ApiRequestError) {
          setError(err.message);
        } else {
          setError("Không thể tải bài viết này");
        }
      } finally {
        setLoading(false);
      }
    };

    loadPost();
  }, [postId]);

  return (
    <div className="max-w-2xl mx-auto py-6">
      <div className="mb-4">
        <button
          onClick={() => router.back()}
          className="inline-flex items-center text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary hover:text-brand dark:hover:text-brand-light transition"
        >
          <ArrowLeft className="w-4 h-4 mr-1.5" />
          Quay lại
        </button>
      </div>

      {loading ? (
        <div className="py-20 flex flex-col items-center justify-center text-appText-secondary">
          <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin mb-3" />
          <span className="text-sm font-medium">Đang tải bài viết...</span>
        </div>
      ) : error ? (
        <div className="py-16 text-center px-4 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-8 shadow-sm">
          <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-2 opacity-80" />
          <p className="text-sm text-appText-primary dark:text-appText-dark-primary font-medium mb-4">
            {error}
          </p>
          <Link
            href="/"
            className="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-brand hover:bg-brand-hover transition"
          >
            Về trang chủ
          </Link>
        </div>
      ) : post ? (
        <PostCard
          post={post}
          onPostDeleted={() => router.push("/")}
          onPostHidden={() => router.push("/")}
        />
      ) : null}
    </div>
  );
}
