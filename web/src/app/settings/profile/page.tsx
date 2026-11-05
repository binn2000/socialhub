"use client";

import React, { useState, useEffect, useRef } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Camera,
  Calendar,
  Globe,
  Briefcase,
  GraduationCap,
  MapPin,
  Home,
  UserX,
  FileText,
  Shield,
  Trash2,
  Check,
  AlertCircle,
  X,
  Eye,
  Sparkles,
  User,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { clientFetch } from "@/lib/client-api";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { DeleteAccountModal } from "@/components/settings/DeleteAccountModal";
import { ApiRequestError } from "@/lib/errors";
import type { Me } from "@/types";

export default function EditProfilePage() {
  const router = useRouter();
  const { user, updateUser, refreshUser } = useAuth();

  const [name, setName] = useState("");
  const [bio, setBio] = useState("");
  const [showOnlineStatus, setShowOnlineStatus] = useState(true);

  // About fields
  const [location, setLocation] = useState("");
  const [hometown, setHometown] = useState("");
  const [workplace, setWorkplace] = useState("");
  const [education, setEducation] = useState("");
  const [website, setWebsite] = useState("");
  const [birthday, setBirthday] = useState("");

  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [coverUrl, setCoverUrl] = useState<string | null>(null);

  const [saving, setSaving] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [uploadingCover, setUploadingCover] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [showDeleteModal, setShowDeleteModal] = useState(false);

  const avatarInputRef = useRef<HTMLInputElement>(null);
  const coverInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (user) {
      setName(user.name || "");
      setBio(user.bio || "");
      setShowOnlineStatus(user.showOnlineStatus ?? true);
      setAvatarUrl(user.avatarUrl || null);
      setCoverUrl(user.coverUrl || null);

      if (user.about) {
        setLocation(user.about.location || "");
        setHometown(user.about.hometown || "");
        setWorkplace(user.about.workplace || "");
        setEducation(user.about.education || "");
        setWebsite(user.about.website || "");
        setBirthday(user.about.birthday || "");
      }
    }
  }, [user]);

  const validate = () => {
    const errs: Record<string, string> = {};

    if (!name.trim()) {
      errs.name = "Tên không được để trống";
    }

    if (website.trim()) {
      const trimmed = website.trim();
      const isHttp = trimmed.startsWith("http://") || trimmed.startsWith("https://");
      if (!isHttp) {
        errs.website = "Địa chỉ phải bắt đầu bằng http:// hoặc https://";
      }
    }

    setFieldErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSave = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (saving) return;
    setError(null);
    setSuccess(null);

    if (!validate()) return;

    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        bio: bio.trim(),
        showOnlineStatus,
        location: location.trim() || null,
        hometown: hometown.trim() || null,
        workplace: workplace.trim() || null,
        education: education.trim() || null,
        website: website.trim() || null,
        birthday: birthday || null,
      };

      const res = await clientFetch<{ data: Me }>("/api/proxy/me", {
        method: "PATCH",
        body: JSON.stringify(payload),
      });

      updateUser(res.data);
      setSuccess("Đã lưu thay đổi hồ sơ thành công");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
        if (err.errors) {
          const apiFieldErrs: Record<string, string> = {};
          for (const [key, msgs] of Object.entries(err.errors)) {
            apiFieldErrs[key] = Array.isArray(msgs) ? msgs[0] : msgs;
          }
          setFieldErrors((prev) => ({ ...prev, ...apiFieldErrs }));
        }
      } else {
        setError("Không thể lưu thay đổi. Vui lòng thử lại.");
      }
    } finally {
      setSaving(false);
    }
  };

  const handleAvatarFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadingAvatar(true);
    setError(null);
    try {
      const formData = new FormData();
      formData.append("avatar", file);

      const res = await clientFetch<{ data: Me }>("/api/proxy/me/avatar", {
        method: "POST",
        body: formData,
      });

      setAvatarUrl(res.data.avatarUrl || null);
      updateUser(res.data);
      setSuccess("Đã cập nhật ảnh đại diện");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể tải lên ảnh đại diện.");
      }
    } finally {
      setUploadingAvatar(false);
      if (avatarInputRef.current) avatarInputRef.current.value = "";
    }
  };

  const handleRemoveAvatar = async () => {
    if (!avatarUrl) return;
    setUploadingAvatar(true);
    setError(null);
    try {
      const res = await clientFetch<{ data: Me }>("/api/proxy/me/avatar", {
        method: "DELETE",
      });
      setAvatarUrl(null);
      updateUser(res.data);
      setSuccess("Đã gỡ ảnh đại diện");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gỡ ảnh đại diện.");
      }
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleCoverFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadingCover(true);
    setError(null);
    try {
      const formData = new FormData();
      formData.append("cover", file);

      const res = await clientFetch<{ data: Me }>("/api/proxy/me/cover", {
        method: "POST",
        body: formData,
      });

      setCoverUrl(res.data.coverUrl || null);
      updateUser(res.data);
      setSuccess("Đã cập nhật ảnh bìa");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể tải lên ảnh bìa.");
      }
    } finally {
      setUploadingCover(false);
      if (coverInputRef.current) coverInputRef.current.value = "";
    }
  };

  const handleRemoveCover = async () => {
    if (!coverUrl) return;
    setUploadingCover(true);
    setError(null);
    try {
      const res = await clientFetch<{ data: Me }>("/api/proxy/me/cover", {
        method: "DELETE",
      });
      setCoverUrl(null);
      updateUser(res.data);
      setSuccess("Đã gỡ ảnh bìa");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể gỡ ảnh bìa.");
      }
    } finally {
      setUploadingCover(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto py-6 pb-20">
      {/* Hidden file inputs */}
      <input
        ref={avatarInputRef}
        type="file"
        accept="image/*"
        onChange={handleAvatarFile}
        className="hidden"
      />
      <input
        ref={coverInputRef}
        type="file"
        accept="image/*"
        onChange={handleCoverFile}
        className="hidden"
      />

      {/* Header bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-appText-primary dark:text-white">
            Chỉnh sửa hồ sơ
          </h1>
          <p className="text-sm text-appText-secondary dark:text-appText-dark-secondary">
            Quản lý thông tin cá nhân và quyền riêng tư của bạn
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          {/* Quick Preview Profile Button */}
          <Link
            href="/profile"
            className="px-4 py-2.5 rounded-xl text-sm font-semibold text-appText-primary dark:text-appText-dark-primary bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition shadow-2xs flex items-center gap-1.5"
          >
            <Eye className="w-4 h-4 text-appText-secondary" />
            <span>Xem trang cá nhân</span>
          </Link>

          {/* Top Save Button */}
          <button
            type="submit"
            form="edit-profile-form"
            disabled={saving}
            className="px-5 py-2.5 rounded-xl font-medium text-white bg-brand hover:bg-brand-hover disabled:opacity-50 transition shadow-sm flex items-center gap-2"
          >
            {saving ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <Check className="w-4 h-4" />
            )}
            <span>Lưu thay đổi</span>
          </button>
        </div>
      </div>

      {success && (
        <div className="mb-6 p-4 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-sm text-emerald-600 dark:text-emerald-400 flex items-center gap-2">
          <Check className="w-4 h-4 flex-shrink-0" />
          <span>{success}</span>
        </div>
      )}

      {error && (
        <div className="mb-6 p-4 rounded-xl bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-900 text-sm text-red-600 dark:text-red-400 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      <form id="edit-profile-form" onSubmit={handleSave} className="space-y-6">
        {/* Card 1: Ảnh bìa & Ảnh đại diện (Visual Header Card) */}
        <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm overflow-hidden">
          {/* Cover Photo Area */}
          <div className="relative h-48 sm:h-60 bg-surface-muted dark:bg-surface-dark-muted">
            {coverUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={coverUrl}
                alt="Ảnh bìa"
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-appText-secondary bg-gradient-to-r from-brand-soft to-purple-50 dark:from-slate-800 dark:to-slate-850">
                <span className="text-sm font-medium">Chưa có ảnh bìa</span>
              </div>
            )}

            {/* Gradient Overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent pointer-events-none" />

            {/* Cover Action Buttons */}
            <div className="absolute bottom-3 right-3 sm:bottom-4 sm:right-4 flex items-center gap-2 z-30">
              <button
                type="button"
                disabled={uploadingCover}
                onClick={() => coverInputRef.current?.click()}
                className="px-3.5 py-1.5 rounded-xl bg-black/60 hover:bg-black/80 text-white text-xs font-semibold backdrop-blur-md transition flex items-center gap-1.5 shadow-md active:scale-95 cursor-pointer disabled:cursor-not-allowed"
              >
                <Camera className="w-3.5 h-3.5" />
                <span>{uploadingCover ? "Đang tải..." : "Đổi ảnh bìa"}</span>
              </button>
              {coverUrl && (
                <button
                  type="button"
                  disabled={uploadingCover}
                  onClick={handleRemoveCover}
                  className="p-1.5 rounded-xl bg-black/60 hover:bg-black/80 text-white text-xs backdrop-blur-md transition shadow-md active:scale-95 cursor-pointer disabled:cursor-not-allowed"
                  title="Gỡ ảnh bìa"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
          </div>

          {/* Profile Header: Avatar & Info Preview */}
          <div className="px-6 sm:px-8 pb-6">
            <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4 -mt-12 sm:-mt-14 relative z-10">
              {/* Avatar with Camera Badge */}
              <div className="flex flex-col sm:flex-row sm:items-end gap-4">
                <div className="relative group shrink-0 self-start sm:self-auto">
                  <div className="ring-4 ring-white dark:ring-surface-dark rounded-full overflow-hidden shadow-lg bg-white dark:bg-surface-dark">
                    <UserAvatar
                      imageUrl={avatarUrl}
                      name={name}
                      size="xl"
                    />
                  </div>
                  {/* Floating Camera Button on Avatar */}
                  <button
                    type="button"
                    disabled={uploadingAvatar}
                    onClick={() => avatarInputRef.current?.click()}
                    className="absolute bottom-0 right-0 p-2 rounded-full bg-slate-900/80 hover:bg-slate-900 text-white border-2 border-white dark:border-surface-dark shadow-md transition active:scale-95 cursor-pointer"
                    title="Đổi ảnh đại diện"
                  >
                    <Camera className="w-4 h-4" />
                  </button>
                </div>

                {/* Name Preview & Action buttons placed beside the avatar */}
                <div className="flex flex-col gap-2 pb-1">
                  <div>
                    <h2 className="text-lg font-bold text-appText-primary dark:text-white leading-tight">
                      {name || "Chưa đặt tên"}
                    </h2>
                    {user?.username && (
                      <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
                        @{user.username}
                      </p>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-2 pt-0.5">
                    <button
                      type="button"
                      disabled={uploadingAvatar}
                      onClick={() => avatarInputRef.current?.click()}
                      className="px-3 py-1.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted hover:bg-appBorder-light dark:hover:bg-slate-800 text-xs font-semibold text-appText-primary dark:text-white transition inline-flex items-center gap-1.5 border border-appBorder-light dark:border-appBorder-dark shadow-2xs"
                    >
                      <Camera className="w-3.5 h-3.5 text-brand" />
                      <span>{uploadingAvatar ? "Đang tải lên..." : "Đổi ảnh đại diện"}</span>
                    </button>
                    {avatarUrl && (
                      <button
                        type="button"
                        disabled={uploadingAvatar}
                        onClick={handleRemoveAvatar}
                        className="px-3 py-1.5 rounded-xl hover:bg-red-50 dark:hover:bg-red-950/40 text-xs font-medium text-red-600 dark:text-red-400 transition inline-flex items-center gap-1.5 border border-transparent hover:border-red-200 dark:hover:border-red-900/50"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                        <span>Gỡ ảnh</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Card 2: Thông tin cơ bản (Basic Info Card) */}
        <div className="p-6 sm:p-7 rounded-2xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark shadow-sm space-y-4">
          <div className="flex items-center gap-2 mb-2">
            <User className="w-4 h-4 text-brand" />
            <h2 className="text-base font-semibold text-appText-primary dark:text-white">
              Thông tin cơ bản
            </h2>
          </div>

          <div>
            <label
              htmlFor="name"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Tên hiển thị <span className="text-red-500">*</span>
            </label>
            <input
              id="name"
              type="text"
              required
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                if (fieldErrors.name) {
                  setFieldErrors((prev) => ({ ...prev, name: "" }));
                }
              }}
              placeholder="Nhập tên của bạn"
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm transition"
            />
            {fieldErrors.name && (
              <p className="mt-1 text-xs text-red-500">{fieldErrors.name}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="bio"
              className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
            >
              Tiểu sử
            </label>
            <textarea
              id="bio"
              rows={3}
              maxLength={160}
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              placeholder="Giới thiệu ngắn gọn về bản thân..."
              className="w-full px-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white placeholder-appText-secondary focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent text-sm resize-none transition"
            />
            <div className="flex items-center justify-between mt-1 text-xs text-appText-secondary">
              <span>Có thể để trống</span>
              <span className={bio.length >= 150 ? "text-amber-500 font-semibold" : ""}>
                {bio.length} / 160 ký tự
              </span>
            </div>
          </div>
        </div>

        {/* Card 3: Giới thiệu chi tiết (Detailed About Card) */}
        <div className="p-6 sm:p-7 rounded-2xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark shadow-sm space-y-4">
          <div className="mb-2">
            <div className="flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-brand" />
              <h2 className="text-base font-semibold text-appText-primary dark:text-white">
                Giới thiệu chi tiết
              </h2>
            </div>
            <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary mt-0.5">
              Chia sẻ thêm thông tin để mọi người hiểu rõ hơn về bạn
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label
                htmlFor="location"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Nơi sống
              </label>
              <div className="relative">
                <MapPin className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
                <input
                  id="location"
                  type="text"
                  maxLength={100}
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  placeholder="Thành phố, Quốc gia"
                  className="w-full pl-10 pr-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="hometown"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Quê quán
              </label>
              <div className="relative">
                <Home className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
                <input
                  id="hometown"
                  type="text"
                  maxLength={100}
                  value={hometown}
                  onChange={(e) => setHometown(e.target.value)}
                  placeholder="Quê quán của bạn"
                  className="w-full pl-10 pr-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="workplace"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Nơi làm việc
              </label>
              <div className="relative">
                <Briefcase className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
                <input
                  id="workplace"
                  type="text"
                  maxLength={100}
                  value={workplace}
                  onChange={(e) => setWorkplace(e.target.value)}
                  placeholder="Công ty, Vị trí công việc"
                  className="w-full pl-10 pr-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="education"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Học vấn
              </label>
              <div className="relative">
                <GraduationCap className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
                <input
                  id="education"
                  type="text"
                  maxLength={100}
                  value={education}
                  onChange={(e) => setEducation(e.target.value)}
                  placeholder="Trường đại học, Chuyên ngành"
                  className="w-full pl-10 pr-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="website"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Trang web
              </label>
              <div className="relative">
                <Globe className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary" />
                <input
                  id="website"
                  type="url"
                  maxLength={200}
                  value={website}
                  onChange={(e) => {
                    setWebsite(e.target.value);
                    if (fieldErrors.website) {
                      setFieldErrors((prev) => ({ ...prev, website: "" }));
                    }
                  }}
                  placeholder="https://example.com"
                  className="w-full pl-10 pr-3.5 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
              </div>
              {fieldErrors.website && (
                <p className="mt-1 text-xs text-red-500">{fieldErrors.website}</p>
              )}
            </div>

            <div>
              <label
                htmlFor="birthday"
                className="block text-sm font-medium text-appText-primary dark:text-appText-dark-primary mb-1"
              >
                Ngày sinh
              </label>
              <div className="relative flex items-center">
                <Calendar className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-appText-secondary pointer-events-none" />
                <input
                  id="birthday"
                  type="date"
                  value={birthday}
                  onChange={(e) => setBirthday(e.target.value)}
                  className="w-full pl-10 pr-10 py-2.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark-muted text-appText-primary dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                />
                {birthday && (
                  <button
                    type="button"
                    onClick={() => setBirthday("")}
                    className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary transition"
                    title="Xóa ngày sinh"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Card 4: Quyền riêng tư & Tùy chọn (Privacy & Settings Card) */}
        <div className="p-6 sm:p-7 rounded-2xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark shadow-sm space-y-5">
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-brand" />
            <h2 className="text-base font-semibold text-appText-primary dark:text-white">
              Quyền riêng tư & Cài đặt
            </h2>
          </div>

          {/* Privacy: Online Status */}
          <div className="flex items-center justify-between p-3.5 rounded-xl bg-surface-muted/50 dark:bg-surface-dark-muted/40 border border-appBorder-light/60 dark:border-appBorder-dark/60">
            <div className="flex items-start gap-3">
              <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 mt-1.5 flex-shrink-0" />
              <div>
                <h3 className="text-sm font-semibold text-appText-primary dark:text-white">
                  Hiện trạng thái online
                </h3>
                <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary">
                  Cho phép bạn bè nhìn thấy khi bạn đang hoạt động
                </p>
              </div>
            </div>

            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={showOnlineStatus}
                onChange={(e) => setShowOnlineStatus(e.target.checked)}
                className="sr-only peer"
              />
              <div className="w-11 h-6 bg-appBorder-light peer-focus:outline-none rounded-full peer dark:bg-appBorder-dark peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-appBorder-light after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
            </label>
          </div>

          {/* Settings Links */}
          <div className="space-y-1.5 pt-2 border-t border-appBorder-light dark:border-appBorder-dark">
            <Link
              href="/settings/blocked"
              className="flex items-center justify-between p-3 rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 transition group"
            >
              <div className="flex items-center gap-3">
                <UserX className="w-4.5 h-4.5 text-appText-secondary group-hover:text-brand transition" />
                <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                  Danh sách người đã chặn
                </span>
              </div>
              <span className="text-xs text-appText-secondary group-hover:text-appText-primary dark:group-hover:text-appText-dark-primary">
                Xem danh sách →
              </span>
            </Link>

            <Link
              href="/terms"
              target="_blank"
              className="flex items-center justify-between p-3 rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 transition group"
            >
              <div className="flex items-center gap-3">
                <FileText className="w-4.5 h-4.5 text-appText-secondary group-hover:text-brand transition" />
                <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                  Điều khoản sử dụng
                </span>
              </div>
              <span className="text-xs text-appText-secondary group-hover:text-appText-primary dark:group-hover:text-appText-dark-primary">
                Mở điều khoản →
              </span>
            </Link>

            <Link
              href="/privacy"
              target="_blank"
              className="flex items-center justify-between p-3 rounded-xl hover:bg-surface-muted dark:hover:bg-surface-dark-muted/60 transition group"
            >
              <div className="flex items-center gap-3">
                <Shield className="w-4.5 h-4.5 text-appText-secondary group-hover:text-brand transition" />
                <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                  Chính sách quyền riêng tư
                </span>
              </div>
              <span className="text-xs text-appText-secondary group-hover:text-appText-primary dark:group-hover:text-appText-dark-primary">
                Mở chính sách →
              </span>
            </Link>
          </div>
        </div>

        {/* Bottom Save Action Bar */}
        <div className="p-4 rounded-2xl border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark shadow-sm flex flex-col sm:flex-row items-center justify-between gap-3">
          <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary text-center sm:text-left">
            Đừng quên lưu lại thông tin sau khi cập nhật hồ sơ cá nhân.
          </p>
          <button
            type="submit"
            disabled={saving}
            className="w-full sm:w-auto px-6 py-2.5 rounded-xl font-medium text-white bg-brand hover:bg-brand-hover disabled:opacity-50 transition shadow-sm flex items-center justify-center gap-2"
          >
            {saving ? (
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <Check className="w-4 h-4" />
            )}
            <span>Lưu thay đổi</span>
          </button>
        </div>

        {/* Card 5: Vùng nguy hiểm (Danger Zone Card) */}
        <div className="p-6 rounded-2xl border border-red-200 dark:border-red-900/50 bg-red-50/40 dark:bg-red-950/20 shadow-sm space-y-3">
          <div className="flex items-center gap-2 text-red-600 dark:text-red-400">
            <AlertCircle className="w-4.5 h-4.5" />
            <h2 className="text-sm font-semibold">Vùng nguy hiểm</h2>
          </div>
          <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary leading-relaxed">
            Khi xóa tài khoản, tất cả bài viết, hình ảnh, tin nhắn và thông tin cá nhân của bạn sẽ bị xóa vĩnh viễn và không thể khôi phục lại.
          </p>
          <div className="pt-1">
            <button
              type="button"
              onClick={() => setShowDeleteModal(true)}
              className="px-4 py-2 rounded-xl border border-red-300 dark:border-red-800 text-red-600 dark:text-red-400 text-xs font-semibold hover:bg-red-100 dark:hover:bg-red-950/60 transition flex items-center gap-2 active:scale-95"
            >
              <Trash2 className="w-3.5 h-3.5" />
              <span>Xóa tài khoản</span>
            </button>
          </div>
        </div>
      </form>

      {/* Delete Account Confirmation Modal */}
      <DeleteAccountModal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
      />
    </div>
  );
}
