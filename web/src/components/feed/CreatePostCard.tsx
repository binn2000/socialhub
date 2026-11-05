"use client";

import React, { useState, useRef } from "react";
import {
  Image as ImageIcon,
  Video,
  Smile,
  Globe,
  Users,
  Lock,
  X,
  Plus,
  AlertCircle,
  Clock,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import {
  PRIVACY_OPTIONS,
  FEELING_OPTIONS,
  getPrivacyLabel,
} from "@/lib/post-constants";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import type { Post, Privacy, Feeling } from "@/types";

interface CreatePostCardProps {
  onPostCreated: (post: Post) => void;
}

export function CreatePostCard({ onPostCreated }: CreatePostCardProps) {
  const { user } = useAuth();

  const [isOpen, setIsOpen] = useState(false);
  const [content, setContent] = useState("");
  const [privacy, setPrivacy] = useState<Privacy>("public");
  const [feeling, setFeeling] = useState<Feeling | null>(null);

  // Picked files & previews
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [imagePreviews, setImagePreviews] = useState<string[]>([]);
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [videoPreview, setVideoPreview] = useState<string | null>(null);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showFeelingsMenu, setShowFeelingsMenu] = useState(false);
  const [showPrivacyMenu, setShowPrivacyMenu] = useState(false);

  const imageInputRef = useRef<HTMLInputElement>(null);
  const videoInputRef = useRef<HTMLInputElement>(null);

  const resetForm = () => {
    setContent("");
    setPrivacy("public");
    setFeeling(null);
    setImageFiles([]);
    setImagePreviews([]);
    setVideoFile(null);
    setVideoPreview(null);
    setError(null);
    setIsOpen(false);
  };

  const handlePickImages = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;

    // A post has photos OR video, not both
    setVideoFile(null);
    setVideoPreview(null);

    const availableSlots = 10 - imageFiles.length;
    const addedFiles = files.slice(0, availableSlots);

    const newPreviews = addedFiles.map((file) => URL.createObjectURL(file));

    setImageFiles((prev) => [...prev, ...addedFiles]);
    setImagePreviews((prev) => [...prev, ...newPreviews]);

    if (imageInputRef.current) imageInputRef.current.value = "";
  };

  const handleRemoveImage = (index: number) => {
    setImageFiles((prev) => prev.filter((_, i) => i !== index));
    setImagePreviews((prev) => prev.filter((_, i) => i !== index));
  };

  const handlePickVideo = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Check size <= 50MB
    if (file.size > 52428800) {
      setError("Video không được vượt quá 50MB");
      return;
    }

    // A post has photos OR video, not both
    setImageFiles([]);
    setImagePreviews([]);

    setVideoFile(file);
    setVideoPreview(URL.createObjectURL(file));

    if (videoInputRef.current) videoInputRef.current.value = "";
  };

  const handleRemoveVideo = () => {
    setVideoFile(null);
    setVideoPreview(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting) return;

    const trimmed = content.trim();
    if (!trimmed && imageFiles.length === 0 && !videoFile) {
      setError("Hãy thêm nội dung hoặc chọn một ảnh/video");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    const formData = new FormData();
    formData.append("content", trimmed);
    formData.append("privacy", privacy);
    if (feeling) {
      formData.append("feeling", feeling);
    }

    // Append images
    if (imageFiles.length > 0) {
      for (const file of imageFiles) {
        formData.append("images[]", file);
      }
    }

    // Append video
    if (videoFile) {
      formData.append("video", videoFile);
    }

    const idempotencyKey = crypto.randomUUID();

    try {
      const res = await clientFetch<{ data: Post }>("/api/proxy/posts", {
        method: "POST",
        headers: {
          "Idempotency-Key": idempotencyKey,
        },
        body: formData,
      });

      onPostCreated(res.data);
      resetForm();
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể đăng bài viết. Vui lòng kiểm tra lại kết nối.");
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <>
      {/* Hidden file inputs */}
      <input
        ref={imageInputRef}
        type="file"
        multiple
        accept="image/*"
        onChange={handlePickImages}
        className="hidden"
      />
      <input
        ref={videoInputRef}
        type="file"
        accept="video/mp4,video/quicktime,video/webm"
        onChange={handlePickVideo}
        className="hidden"
      />

      {/* Main Create Post Trigger Card */}
      <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm p-4 sm:p-5 mb-6">
        <div className="flex items-center gap-3">
          <UserAvatar
            name={user?.name}
            imageUrl={user?.avatarUrl}
            size="md"
            isOnline={true}
          />
          <button
            type="button"
            onClick={() => setIsOpen(true)}
            className="flex-1 text-left px-4 py-2.5 rounded-full bg-surface-muted hover:bg-appBorder-light/80 dark:bg-surface-dark-muted dark:hover:bg-appBorder-dark/80 text-appText-secondary dark:text-appText-dark-secondary text-sm transition"
          >
            {user ? `${user.name} ơi, bạn đang nghĩ gì thế?` : "Bạn đang nghĩ gì thế?"}
          </button>
        </div>

        <div className="flex items-center justify-between pt-3 mt-3 border-t border-appBorder-light dark:border-appBorder-dark/80 text-xs sm:text-sm">
          <button
            type="button"
            onClick={() => {
              setIsOpen(true);
              setTimeout(() => imageInputRef.current?.click(), 150);
            }}
            className="flex items-center gap-2 px-3 py-1.5 rounded-xl text-appText-secondary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition font-medium"
          >
            <ImageIcon className="w-5 h-5 text-emerald-500" />
            <span>Hình ảnh</span>
          </button>

          <button
            type="button"
            onClick={() => {
              setIsOpen(true);
              setTimeout(() => videoInputRef.current?.click(), 150);
            }}
            className="flex items-center gap-2 px-3 py-1.5 rounded-xl text-appText-secondary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition font-medium"
          >
            <Video className="w-5 h-5 text-rose-500" />
            <span>Video</span>
          </button>

          <button
            type="button"
            onClick={() => {
              setIsOpen(true);
              setShowFeelingsMenu(true);
            }}
            className="flex items-center gap-2 px-3 py-1.5 rounded-xl text-appText-secondary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition font-medium"
          >
            <Smile className="w-5 h-5 text-amber-500" />
            <span>Cảm xúc</span>
          </button>
        </div>
      </div>

      {/* Expanded Modal Composer */}
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
          <div
            className="w-full max-w-lg bg-white dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark overflow-hidden flex flex-col max-h-[90vh] animate-scale-in"
            role="dialog"
            aria-modal="true"
          >
            {/* Header */}
            <div className="p-4 sm:px-6 border-b border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
              <h2 className="text-base font-bold text-appText-primary dark:text-white">
                Tạo bài viết
              </h2>
              <button
                type="button"
                onClick={resetForm}
                className="p-1.5 rounded-lg text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {error && (
              <div className="m-4 mb-0 p-3 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-xs text-red-600 dark:text-red-400 flex items-center gap-2">
                <AlertCircle className="w-4 h-4 flex-shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {/* Content area */}
            <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-4 sm:p-6 flex flex-col">
              {/* Author info & privacy */}
              <div className="flex items-center gap-3 mb-4">
                <UserAvatar
                  name={user?.name}
                  imageUrl={user?.avatarUrl}
                  size="md"
                />

                <div>
                  <p className="text-sm font-bold text-appText-primary dark:text-white">
                    {user?.name}
                  </p>

                  <div className="relative mt-1 flex items-center gap-2">
                    {/* Privacy selector button */}
                    <button
                      type="button"
                      onClick={() => setShowPrivacyMenu(!showPrivacyMenu)}
                      className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-surface-muted hover:bg-appBorder-light/70 dark:bg-surface-dark-muted text-xs font-medium text-appText-primary dark:text-appText-dark-primary transition"
                    >
                      {privacy === "friends" ? (
                        <Users className="w-3 h-3" />
                      ) : privacy === "only_me" ? (
                        <Lock className="w-3 h-3" />
                      ) : (
                        <Globe className="w-3 h-3" />
                      )}
                      <span>{getPrivacyLabel(privacy)}</span>
                    </button>

                    {/* Privacy Dropdown */}
                    {showPrivacyMenu && (
                      <>
                        <div
                          className="fixed inset-0 z-20"
                          onClick={() => setShowPrivacyMenu(false)}
                        />
                        <div className="absolute left-0 top-full mt-1 w-44 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-xl shadow-lg z-30 py-1 text-xs">
                          {PRIVACY_OPTIONS.map((opt) => (
                            <button
                              key={opt.value}
                              type="button"
                              onClick={() => {
                                setPrivacy(opt.value);
                                setShowPrivacyMenu(false);
                              }}
                              className={`w-full px-3 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 flex items-center gap-2 transition ${
                                privacy === opt.value
                                  ? "text-brand dark:text-brand-light font-semibold"
                                  : "text-appText-primary dark:text-appText-dark-primary"
                              }`}
                            >
                              <span>{opt.label}</span>
                            </button>
                          ))}
                        </div>
                      </>
                    )}

                    {/* Feeling badge if chosen */}
                    {feeling && (
                      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 text-xs font-medium border border-amber-200 dark:border-amber-900/40">
                        <span>
                          {FEELING_OPTIONS.find((f) => f.value === feeling)?.emoji}{" "}
                          {FEELING_OPTIONS.find((f) => f.value === feeling)?.label}
                        </span>
                        <button
                          type="button"
                          onClick={() => setFeeling(null)}
                          className="hover:text-amber-900 p-0.5"
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Text editor */}
              <textarea
                autoFocus
                rows={4}
                value={content}
                onChange={(e) => setContent(e.target.value)}
                placeholder={`${user?.name ? `${user.name} ơi, ` : ""}bạn đang nghĩ gì thế?`}
                className="w-full bg-transparent text-appText-primary dark:text-white placeholder-appText-secondary text-base sm:text-lg outline-none resize-none mb-4 leading-relaxed flex-1"
              />

              {/* Image Previews */}
              {imagePreviews.length > 0 && (
                <div className="mb-4">
                  <div className="flex items-center justify-between text-xs text-appText-secondary mb-2">
                    <span>Ảnh đã chọn ({imagePreviews.length}/10)</span>
                    {imagePreviews.length < 10 && (
                      <button
                        type="button"
                        onClick={() => imageInputRef.current?.click()}
                        className="text-brand dark:text-brand-light font-medium hover:underline inline-flex items-center gap-1"
                      >
                        <Plus className="w-3 h-3" />
                        <span>Thêm ảnh</span>
                      </button>
                    )}
                  </div>

                  <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                    {imagePreviews.map((previewUrl, idx) => (
                      <div
                        key={idx}
                        className="relative aspect-square rounded-xl overflow-hidden border border-appBorder-light dark:border-appBorder-dark group"
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={previewUrl}
                          alt=""
                          className="w-full h-full object-cover"
                        />
                        <button
                          type="button"
                          onClick={() => handleRemoveImage(idx)}
                          className="absolute top-1.5 right-1.5 p-1 rounded-full bg-black/60 hover:bg-black/80 text-white transition backdrop-blur-sm"
                          title="Xóa ảnh"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Video Preview */}
              {videoPreview && (
                <div className="mb-4 relative rounded-xl overflow-hidden border border-appBorder-light dark:border-appBorder-dark bg-black aspect-video flex items-center justify-center">
                  <video
                    src={videoPreview}
                    controls
                    className="max-h-full max-w-full object-contain"
                  />
                  <button
                    type="button"
                    onClick={handleRemoveVideo}
                    className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 hover:bg-black/80 text-white transition backdrop-blur-sm z-10"
                    title="Xóa video"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              )}

              {/* Toolbar: Add to post */}
              <div className="mt-auto pt-4 border-t border-appBorder-light dark:border-appBorder-dark flex items-center justify-between">
                <span className="text-xs font-semibold text-appText-secondary dark:text-appText-dark-secondary">
                  Thêm vào bài viết
                </span>

                <div className="flex items-center gap-1 relative">
                  <button
                    type="button"
                    onClick={() => imageInputRef.current?.click()}
                    className="p-2 rounded-xl text-appText-secondary hover:text-emerald-600 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                    title="Thêm ảnh"
                  >
                    <ImageIcon className="w-5 h-5 text-emerald-500" />
                  </button>

                  <button
                    type="button"
                    onClick={() => videoInputRef.current?.click()}
                    className="p-2 rounded-xl text-appText-secondary hover:text-rose-600 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                    title="Thêm video (tối đa 50MB)"
                  >
                    <Video className="w-5 h-5 text-rose-500" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setShowFeelingsMenu(!showFeelingsMenu)}
                    className="p-2 rounded-xl text-appText-secondary hover:text-amber-600 hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                    title="Chọn cảm xúc"
                  >
                    <Smile className="w-5 h-5 text-amber-500" />
                  </button>

                  {/* Feelings Menu */}
                  {showFeelingsMenu && (
                    <>
                      <div
                        className="fixed inset-0 z-20"
                        onClick={() => setShowFeelingsMenu(false)}
                      />
                      <div className="absolute right-0 bottom-full mb-2 w-48 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-xl shadow-lg z-30 p-2 text-xs space-y-1">
                        <p className="px-2 py-1 font-semibold text-appText-secondary">
                          Bạn cảm thấy thế nào?
                        </p>
                        {FEELING_OPTIONS.map((f) => (
                          <button
                            key={f.value}
                            type="button"
                            onClick={() => {
                              setFeeling(f.value);
                              setShowFeelingsMenu(false);
                            }}
                            className="w-full px-2 py-1.5 text-left rounded-lg hover:bg-surface-muted dark:hover:bg-surface-dark-muted/80 flex items-center gap-2 text-appText-primary dark:text-appText-dark-primary"
                          >
                            <span className="text-base">{f.emoji}</span>
                            <span>{f.label}</span>
                          </button>
                        ))}
                      </div>
                    </>
                  )}
                </div>
              </div>

              {/* Submit button */}
              <div className="pt-4">
                <button
                  type="submit"
                  disabled={
                    isSubmitting ||
                    (!content.trim() && imageFiles.length === 0 && !videoFile)
                  }
                  className="w-full py-2.5 px-4 rounded-xl font-semibold text-white bg-brand hover:bg-brand-hover disabled:opacity-50 disabled:cursor-not-allowed transition shadow-sm"
                >
                  {isSubmitting ? (
                    <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin mx-auto" />
                  ) : (
                    "Đăng"
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
