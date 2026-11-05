"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { Plus } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { clientFetch } from "@/lib/client-api";
import { getStoryGradient } from "@/lib/story-constants";
import type { Story } from "@/types";

export function StoryTray() {
  const { user } = useAuth();
  const [stories, setStories] = useState<Story[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadStories = async () => {
      try {
        const res = await clientFetch<{ data: Story[] }>("/api/proxy/stories");
        setStories(res.data || []);
      } catch {
        // Fallback gracefully if stories endpoint fails
        setStories([]);
      } finally {
        setLoading(false);
      }
    };

    loadStories();
  }, []);

  return (
    <div className="mb-6 overflow-x-auto pb-2 scrollbar-none">
      <div className="flex items-center gap-3 min-w-max">
        {/* Create Story Card */}
        <Link
          href="/stories/create"
          className="relative w-28 h-44 rounded-2xl overflow-hidden border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark group shadow-sm flex flex-col justify-between p-2 flex-shrink-0 hover:shadow-md transition"
        >
          <div className="h-28 -m-2 mb-0 overflow-hidden bg-surface-muted dark:bg-surface-dark-muted flex items-center justify-center">
            {user?.avatarUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={user.avatarUrl}
                alt=""
                className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
              />
            ) : (
              <div className="w-full h-full bg-gradient-to-tr from-brand to-purple-500 flex items-center justify-center text-white font-bold text-lg">
                {user?.name?.[0] || "U"}
              </div>
            )}
          </div>

          <div className="absolute top-24 left-1/2 -translate-x-1/2 w-8 h-8 rounded-full bg-brand text-white border-2 border-white dark:border-appBorder-dark flex items-center justify-center shadow">
            <Plus className="w-5 h-5" />
          </div>

          <div className="text-center pt-3">
            <span className="text-xs font-semibold text-appText-primary dark:text-appText-dark-primary block truncate">
              Tạo tin
            </span>
          </div>
        </Link>

        {/* Stories list */}
        {stories.map((story) => {
          const isViewed = story.isViewed;
          return (
            <Link
              key={story.id}
              href={`/stories?id=${story.id}`}
              className="relative w-28 h-44 rounded-2xl overflow-hidden group shadow-sm flex flex-col justify-between p-2.5 flex-shrink-0 hover:shadow-md transition bg-slate-900 select-none"
            >
              {story.imageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={story.imageUrl}
                  alt=""
                  className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition duration-300 opacity-80"
                />
              ) : (
                <div
                  className="absolute inset-0 opacity-90"
                  style={getStoryGradient(story.background)}
                />
              )}

              {/* Gradient shadow for text readability */}
              <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black/70 pointer-events-none" />

              {/* Author Avatar with viewed ring */}
              <div className="relative z-10">
                <div
                  className={`w-9 h-9 rounded-full p-0.5 ${
                    isViewed
                      ? "ring-2 ring-slate-400"
                      : "ring-2 ring-brand ring-offset-1 ring-offset-transparent"
                  }`}
                >
                  <UserAvatar
                    name={story.author.name}
                    imageUrl={story.author.avatarUrl}
                    size="xs"
                  />
                </div>
              </div>

              {/* Story text excerpt if any */}
              {story.text && (
                <p className="relative z-10 text-[11px] text-white/90 line-clamp-3 my-auto leading-tight">
                  {story.text}
                </p>
              )}

              {/* Author Name */}
              <span className="relative z-10 text-xs font-semibold text-white truncate block drop-shadow-sm">
                {story.author.name}
              </span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
