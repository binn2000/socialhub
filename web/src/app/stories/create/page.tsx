"use client";

import React, { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  X,
  Music2,
  Image as ImageIcon,
  Trash2,
  Lock,
  Globe,
  Users,
  Loader2,
  AlertCircle,
  Play,
  Pause,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { clientFetch } from "@/lib/client-api";
import {
  STORY_BACKGROUNDS,
  STORY_PRIVACY_OPTIONS,
  getStoryGradient,
} from "@/lib/story-constants";
import { TrackPickerModal } from "@/components/story/TrackPickerModal";
import type { StoryBackground, Privacy, Track, Story } from "@/types";

export default function CreateStoryPage() {
  const router = useRouter();
  const { user } = useAuth();

  const [text, setText] = useState("");
  const [selectedBg, setSelectedBg] = useState<StoryBackground>("indigo");
  const [selectedPrivacy, setSelectedPrivacy] = useState<Privacy>("friends");
  const [selectedTrack, setSelectedTrack] = useState<Track | null>(null);

  // Photo upload
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  // Modals & loading
  const [trackModalOpen, setTrackModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Audio preview for attached track
  const [isPlayingPreview, setIsPlayingPreview] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      setError("Dung lượng ảnh tối đa là 10 MB");
      return;
    }

    setImageFile(file);
    const url = URL.createObjectURL(file);
    setImagePreview(url);
    setError(null);
  };

  const removeImage = () => {
    setImageFile(null);
    if (imagePreview) {
      URL.revokeObjectURL(imagePreview);
      setImagePreview(null);
    }
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const toggleTrackAudio = () => {
    if (!selectedTrack?.previewUrl) return;

    if (isPlayingPreview) {
      audioRef.current?.pause();
      setIsPlayingPreview(false);
    } else {
      if (!audioRef.current) {
        audioRef.current = new Audio(selectedTrack.previewUrl);
        audioRef.current.onended = () => setIsPlayingPreview(false);
      }
      audioRef.current.play().catch(() => setIsPlayingPreview(false));
      setIsPlayingPreview(true);
    }
  };

  const handlePublish = async () => {
    if (!text.trim() && !imageFile) {
      setError("Vui lòng nhập nội dung văn bản hoặc chọn một bức ảnh cho tin.");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    // Stop preview audio if playing
    if (audioRef.current) {
      audioRef.current.pause();
      setIsPlayingPreview(false);
    }

    try {
      const idempotencyKey = crypto.randomUUID();

      if (imageFile) {
        // Multipart form-data
        const formData = new FormData();
        formData.append("image", imageFile);
        if (text.trim()) {
          formData.append("text", text.trim());
        }
        formData.append("background", selectedBg);
        formData.append("privacy", selectedPrivacy);
        if (selectedTrack?.id) {
          formData.append("trackId", selectedTrack.id);
        }

        await clientFetch<{ data: Story }>("/api/proxy/stories", {
          method: "POST",
          headers: {
            "Idempotency-Key": idempotencyKey,
          },
          body: formData,
        });
      } else {
        // JSON payload
        await clientFetch<{ data: Story }>("/api/proxy/stories", {
          method: "POST",
          headers: {
            "Idempotency-Key": idempotencyKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text: text.trim(),
            background: selectedBg,
            privacy: selectedPrivacy,
            trackId: selectedTrack?.id,
          }),
        });
      }

      router.push("/");
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : "Đã có lỗi xảy ra khi tạo tin.";
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleClose = () => {
    if (text.trim() || imageFile || selectedTrack) {
      if (confirm("Hủy tạo tin? Những thay đổi của bạn sẽ không được lưu.")) {
        router.push("/");
      }
    } else {
      router.push("/");
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black text-white flex flex-col overflow-hidden select-none">
      {/* Top Bar */}
      <header className="h-16 px-4 md:px-8 flex items-center justify-between border-b border-white/10 shrink-0">
        <div className="flex items-center gap-3">
          <button
            onClick={handleClose}
            className="p-2 text-white/80 hover:text-white rounded-full hover:bg-white/10 transition"
            title="Đóng"
          >
            <X size={24} />
          </button>
          <h1 className="text-lg font-bold">Tạo tin</h1>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={handlePublish}
            disabled={isSubmitting || (!text.trim() && !imageFile)}
            className="px-6 py-2 rounded-full bg-brand hover:bg-brand-hover text-white text-sm font-semibold shadow-lg shadow-brand/30 active:scale-95 disabled:opacity-50 disabled:pointer-events-none transition flex items-center gap-2"
          >
            {isSubmitting && <Loader2 size={16} className="animate-spin" />}
            <span>Chia sẻ</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col md:flex-row items-center justify-center p-4 md:p-6 overflow-y-auto">
        {/* Story Preview Mockup */}
        <div className="relative w-full max-w-sm aspect-[9/16] rounded-3xl overflow-hidden shadow-2xl flex flex-col justify-between p-6 border border-white/15 my-auto">
          {/* Background: Gradient or Image */}
          {imagePreview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={imagePreview}
              alt="Story Preview"
              className="absolute inset-0 w-full h-full object-cover"
            />
          ) : (
            <div
              className="absolute inset-0 transition-all duration-300"
              style={getStoryGradient(selectedBg)}
            />
          )}

          {/* Dark gradient overlay for text readability */}
          <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black/60 pointer-events-none" />

          {/* Header info in preview */}
          <div className="relative z-10 flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-full bg-white/20 backdrop-blur-md overflow-hidden ring-2 ring-white/50">
              {user?.avatarUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={user.avatarUrl}
                  alt={user.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-white font-bold text-sm">
                  {user?.name?.[0] || "U"}
                </div>
              )}
            </div>
            <div>
              <span className="text-sm font-bold text-white block drop-shadow-md">
                {user?.name || "Bạn"}
              </span>
              <span className="text-[11px] text-white/80 block drop-shadow">
                Vừa xong ·{" "}
                {STORY_PRIVACY_OPTIONS.find((p) => p.value === selectedPrivacy)?.label}
              </span>
            </div>
          </div>

          {/* Center Text Input Area */}
          <div className="relative z-10 my-auto flex flex-col items-center justify-center">
            <div className="w-full max-w-xs bg-black/30 backdrop-blur-md rounded-2xl p-4 shadow-lg border border-white/10">
              <textarea
                value={text}
                onChange={(e) => setText(e.target.value)}
                maxLength={500}
                rows={4}
                placeholder="Viết gì đó..."
                className="w-full bg-transparent text-white placeholder-white/70 text-center text-xl md:text-2xl font-bold resize-none outline-none drop-shadow-md"
              />
            </div>
          </div>

          {/* Footer inside story: Song indicator if present */}
          <div className="relative z-10">
            {selectedTrack && (
              <div
                onClick={toggleTrackAudio}
                className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-black/40 backdrop-blur-md border border-white/20 text-white text-xs cursor-pointer hover:bg-black/60 transition"
              >
                <div className="w-5 h-5 rounded-full bg-white/20 flex items-center justify-center shrink-0">
                  {isPlayingPreview ? (
                    <Pause size={10} className="fill-white" />
                  ) : (
                    <Play size={10} className="fill-white ml-0.5" />
                  )}
                </div>
                <Music2 size={13} className="text-white shrink-0" />
                <span className="truncate max-w-[200px] font-medium">
                  {selectedTrack.title} · {selectedTrack.artist}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Controls Sidebar (Desktop) or Bottom Floating Sheet (Mobile) */}
        <div className="w-full md:w-80 md:ml-8 mt-6 md:mt-0 flex flex-col gap-5 bg-white/5 border border-white/10 p-5 rounded-2xl backdrop-blur-md">
          {error && (
            <div className="p-3 bg-rose-500/20 border border-rose-500/30 rounded-xl text-xs text-rose-300 flex items-center gap-2">
              <AlertCircle size={16} className="shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Background Palette */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-white/70 block mb-2.5">
              Màu nền tin
            </label>
            <div className="flex items-center gap-3">
              {STORY_BACKGROUNDS.map((bg) => (
                <button
                  key={bg.id}
                  onClick={() => setSelectedBg(bg.id)}
                  title={bg.label}
                  className={`w-9 h-9 rounded-full transition-all duration-200 ${
                    selectedBg === bg.id
                      ? "ring-4 ring-white ring-offset-2 ring-offset-black scale-110"
                      : "opacity-75 hover:opacity-100"
                  }`}
                  style={{
                    background: `linear-gradient(135deg, ${bg.from}, ${bg.to})`,
                  }}
                />
              ))}
            </div>
          </div>

          {/* Photo attachment control */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-white/70 block mb-2">
              Ảnh đính kèm
            </label>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              onChange={handleImageSelect}
              className="hidden"
            />
            {imagePreview ? (
              <div className="flex items-center justify-between p-2.5 rounded-xl bg-white/10 border border-white/15">
                <div className="flex items-center gap-2 overflow-hidden">
                  <ImageIcon size={18} className="text-emerald-400 shrink-0" />
                  <span className="text-xs text-white/90 truncate">
                    {imageFile?.name || "Ảnh đã chọn"}
                  </span>
                </div>
                <button
                  onClick={removeImage}
                  className="p-1 text-white/70 hover:text-rose-400 rounded-lg transition"
                  title="Xóa ảnh"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ) : (
              <button
                onClick={() => fileInputRef.current?.click()}
                className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-white/10 hover:bg-white/15 border border-white/15 text-sm font-medium transition"
              >
                <ImageIcon size={18} />
                <span>Chọn ảnh từ thiết bị</span>
              </button>
            )}
          </div>

          {/* Music track control */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-white/70 block mb-2">
              Nhạc nền
            </label>
            {selectedTrack ? (
              <div className="flex items-center justify-between p-2.5 rounded-xl bg-white/10 border border-white/15">
                <div className="flex items-center gap-2.5 overflow-hidden">
                  <div className="w-8 h-8 rounded-lg bg-brand/30 flex items-center justify-center shrink-0">
                    <Music2 size={16} className="text-brand" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-xs font-semibold truncate text-white">
                      {selectedTrack.title}
                    </p>
                    <p className="text-[11px] text-white/60 truncate">
                      {selectedTrack.artist}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={toggleTrackAudio}
                    className="p-1.5 text-white/80 hover:text-white rounded-lg transition"
                    title={isPlayingPreview ? "Tạm dừng" : "Nghe thử"}
                  >
                    {isPlayingPreview ? <Pause size={15} /> : <Play size={15} />}
                  </button>
                  <button
                    onClick={() => {
                      if (audioRef.current) audioRef.current.pause();
                      setIsPlayingPreview(false);
                      setSelectedTrack(null);
                    }}
                    className="p-1.5 text-white/60 hover:text-rose-400 rounded-lg transition"
                    title="Bỏ nhạc"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => setTrackModalOpen(true)}
                className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl bg-white/10 hover:bg-white/15 border border-white/15 text-sm font-medium transition"
              >
                <Music2 size={18} />
                <span>Thêm nhạc nền</span>
              </button>
            )}
          </div>

          {/* Privacy setting */}
          <div>
            <label className="text-xs font-semibold uppercase tracking-wider text-white/70 block mb-2">
              Quyền riêng tư
            </label>
            <div className="grid grid-cols-3 gap-2">
              {STORY_PRIVACY_OPTIONS.map((opt) => {
                const isSelected = selectedPrivacy === opt.value;
                return (
                  <button
                    key={opt.value}
                    onClick={() => setSelectedPrivacy(opt.value)}
                    className={`py-2 px-2 rounded-xl text-xs font-medium flex items-center justify-center gap-1.5 border transition ${
                      isSelected
                        ? "bg-brand text-white border-brand shadow-sm shadow-brand/30"
                        : "bg-white/5 border-white/10 text-white/70 hover:bg-white/10"
                    }`}
                  >
                    {opt.value === "public" && <Globe size={13} />}
                    {opt.value === "friends" && <Users size={13} />}
                    {opt.value === "only_me" && <Lock size={13} />}
                    <span>{opt.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </main>

      {/* Music Picker Modal */}
      {trackModalOpen && (
        <TrackPickerModal
          isOpen={trackModalOpen}
          onClose={() => setTrackModalOpen(false)}
          onSelectTrack={(track) => setSelectedTrack(track)}
          selectedTrackId={selectedTrack?.id}
        />
      )}
    </div>
  );
}
