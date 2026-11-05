"use client";

import React, { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Camera,
  MapPin,
  Home,
  Briefcase,
  GraduationCap,
  Globe,
  Calendar,
  MoreHorizontal,
  Flag,
  UserX,
  Lock,
  UserPlus,
  UserCheck,
  UserMinus,
  MessageCircle,
  Bookmark,
  Share2,
  Check,
  AlertCircle,
  FileText,
  Image as ImageIcon,
  Users,
  Grid,
  Music2,
  Info,
  User,
} from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { UserAvatar } from "@/components/ui/UserAvatar";
import { PostCard } from "@/components/feed/PostCard";
import { CreatePostCard } from "@/components/feed/CreatePostCard";
import { ImageViewerModal } from "@/components/feed/ImageViewerModal";
import { ReportModal } from "@/components/feed/ReportModal";
import { FollowListModal } from "./FollowListModal";
import { CreateNoteModal } from "@/components/chat/CreateNoteModal";
import { ViewNoteModal } from "@/components/chat/ViewNoteModal";
import { useToast } from "@/context/ToastContext";
import { clientFetch } from "@/lib/client-api";
import { ApiRequestError } from "@/lib/errors";
import type {
  UserProfile,
  Me,
  Post,
  Photo,
  UserListItem,
  CursorMeta,
  Note,
} from "@/types";

type ProfileTab = "posts" | "about" | "photos" | "friends";

interface ProfileViewProps {
  userId?: string; // If undefined, loads current user's profile
}

export function ProfileView({ userId }: ProfileViewProps) {
  const router = useRouter();
  const { user: currentUser } = useAuth();

  const isMyProfile = !userId || userId === currentUser?.id;
  const targetId = userId || currentUser?.id;

  const [profile, setProfile] = useState<UserProfile | Me | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<ProfileTab>("posts");

  // Tab data states
  const [posts, setPosts] = useState<Post[]>([]);
  const [postsLoading, setPostsLoading] = useState(false);
  const [postsCursor, setPostsCursor] = useState<string | null>(null);

  const [photos, setPhotos] = useState<Photo[]>([]);
  const [photosLoading, setPhotosLoading] = useState(false);
  const [photosCursor, setPhotosCursor] = useState<string | null>(null);

  const [friends, setFriends] = useState<UserListItem[]>([]);
  const [friendsLoading, setFriendsLoading] = useState(false);
  const [friendsCursor, setFriendsCursor] = useState<string | null>(null);

  // Modals & Menu
  const [menuOpen, setMenuOpen] = useState(false);
  const [reportModalOpen, setReportModalOpen] = useState(false);
  const [viewingNote, setViewingNote] = useState<Note | null>(null);
  const [createNoteModalOpen, setCreateNoteModalOpen] = useState(false);
  const [followModal, setFollowModal] = useState<{
    isOpen: boolean;
    type: "followers" | "following";
  }>({ isOpen: false, type: "followers" });

  const [imageViewerOpen, setImageViewerOpen] = useState(false);
  const [selectedPhotoIndex, setSelectedPhotoIndex] = useState(0);

  // Action states
  const [actionBusy, setActionBusy] = useState(false);
  const { toast } = useToast();

  const coverInputRef = useRef<HTMLInputElement>(null);

  // 1. Load Profile
  const loadProfile = useCallback(async () => {
    if (!targetId) return;
    setLoading(true);
    setError(null);
    try {
      const endpoint = isMyProfile ? "/api/proxy/me" : `/api/proxy/users/${targetId}`;
      const res = await clientFetch<{ data: UserProfile | Me }>(endpoint);
      setProfile(res.data);
    } catch (err) {
      if (err instanceof ApiRequestError) {
        setError(err.message);
      } else {
        setError("Không thể tải thông tin hồ sơ");
      }
    } finally {
      setLoading(false);
    }
  }, [targetId, isMyProfile]);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  // 2. Load Posts
  const loadPosts = useCallback(async (cursor?: string | null) => {
    if (!targetId) return;
    setPostsLoading(true);
    try {
      const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{ data: Post[]; meta?: CursorMeta }>(
        `/api/proxy/users/${targetId}/posts${query}`
      );
      if (cursor) {
        setPosts((prev) => [...prev, ...(res.data || [])]);
      } else {
        setPosts(res.data || []);
      }
      setPostsCursor(res.meta?.nextCursor || null);
    } catch {
      setPosts([]);
    } finally {
      setPostsLoading(false);
    }
  }, [targetId]);

  // 3. Load Photos
  const loadPhotos = useCallback(async (cursor?: string | null) => {
    if (!targetId) return;
    setPhotosLoading(true);
    try {
      const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{ data: Photo[]; meta?: CursorMeta }>(
        `/api/proxy/users/${targetId}/photos${query}`
      );
      if (cursor) {
        setPhotos((prev) => [...prev, ...(res.data || [])]);
      } else {
        setPhotos(res.data || []);
      }
      setPhotosCursor(res.meta?.nextCursor || null);
    } catch {
      setPhotos([]);
    } finally {
      setPhotosLoading(false);
    }
  }, [targetId]);

  // 4. Load Friends
  const loadFriends = useCallback(async (cursor?: string | null) => {
    if (!targetId) return;
    setFriendsLoading(true);
    try {
      const query = cursor ? `?cursor=${encodeURIComponent(cursor)}` : "";
      const res = await clientFetch<{ data: UserListItem[]; meta?: CursorMeta }>(
        `/api/proxy/users/${targetId}/friends${query}`
      );
      if (cursor) {
        setFriends((prev) => [...prev, ...(res.data || [])]);
      } else {
        setFriends(res.data || []);
      }
      setFriendsCursor(res.meta?.nextCursor || null);
    } catch {
      setFriends([]);
    } finally {
      setFriendsLoading(false);
    }
  }, [targetId]);

  // Switch tabs
  const handleTabChange = (tab: ProfileTab) => {
    setActiveTab(tab);
    if (tab === "posts" && posts.length === 0) loadPosts();
    if (tab === "photos" && photos.length === 0) loadPhotos();
    if (tab === "friends" && friends.length === 0) loadFriends();
  };

  useEffect(() => {
    if (targetId) {
      loadPosts();
      loadPhotos();
      loadFriends();
    }
  }, [targetId, loadPosts, loadPhotos, loadFriends]);

  // Friend Actions
  const handleSendRequest = async () => {
    if (actionBusy || !targetId) return;
    setActionBusy(true);
    try {
      await clientFetch("/api/proxy/friend-requests", {
        method: "POST",
        body: JSON.stringify({ userId: targetId }),
      });
      await loadProfile();
      toast.success("Đã gửi lời mời kết bạn");
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleCancelRequest = async (requestId: string) => {
    if (actionBusy) return;
    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friend-requests/${requestId}`, {
        method: "DELETE",
      });
      await loadProfile();
      toast.info("Đã hủy lời mời kết bạn");
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleAcceptRequest = async (requestId: string) => {
    if (actionBusy) return;
    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friend-requests/${requestId}/accept`, {
        method: "POST",
      });
      await loadProfile();
      toast.success("Đã chấp nhận lời mời kết bạn");
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleUnfriend = async () => {
    if (actionBusy || !targetId || !profile) return;
    const confirmed = window.confirm(`Hủy kết bạn với ${profile.name}?`);
    if (!confirmed) return;

    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/friends/${targetId}`, {
        method: "DELETE",
      });
      await loadProfile();
      toast.info(`Đã hủy kết bạn với ${profile.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleToggleFollow = async () => {
    if (actionBusy || !targetId || isMyProfile) return;
    const userProf = profile as UserProfile;
    const nextIsFollowing = !userProf.isFollowing;

    setActionBusy(true);
    try {
      await clientFetch(`/api/proxy/users/${targetId}/follow`, {
        method: nextIsFollowing ? "PUT" : "DELETE",
      });
      setProfile((prev) =>
        prev
          ? {
              ...prev,
              isFollowing: nextIsFollowing,
              followersCount: nextIsFollowing
                ? (userProf.followersCount || 0) + 1
                : Math.max(0, (userProf.followersCount || 1) - 1),
            }
          : null
      );
      if (nextIsFollowing) {
        toast.success(`Đã theo dõi ${userProf.name}`);
      } else {
        toast.info(`Đã bỏ theo dõi ${userProf.name}`);
      }
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    } finally {
      setActionBusy(false);
    }
  };

  const handleBlockUser = async () => {
    if (!targetId || !profile || isMyProfile) return;
    const confirmed = window.confirm(
      `Chặn ${profile.name}? Hai bạn sẽ không thấy bài viết của nhau và không nhắn tin được.`
    );
    if (!confirmed) return;

    try {
      await clientFetch(`/api/proxy/users/${targetId}/block`, { method: "PUT" });
      await loadProfile();
      toast.info(`Đã chặn ${profile.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    }
  };

  const handleUnblockUser = async () => {
    if (!targetId || !profile || isMyProfile) return;
    try {
      await clientFetch(`/api/proxy/users/${targetId}/block`, { method: "DELETE" });
      await loadProfile();
      toast.success(`Đã bỏ chặn ${profile.name}`);
    } catch (err) {
      if (err instanceof ApiRequestError) toast.error(err.message);
    }
  };

  const handleCoverUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      const formData = new FormData();
      formData.append("cover", file);
      const res = await clientFetch<{ data: Me }>("/api/proxy/me/cover", {
        method: "POST",
        body: formData,
      });
      setProfile((prev) => (prev ? { ...prev, coverUrl: res.data.coverUrl } : null));
      toast.success("Đã cập nhật ảnh bìa");
    } catch {
      toast.error("Không thể cập nhật ảnh bìa");
    }
  };

  if (loading) {
    return (
      <div className="py-24 flex flex-col items-center justify-center text-appText-secondary">
        <div className="w-8 h-8 border-2 border-brand border-t-transparent rounded-full animate-spin mb-3" />
        <span className="text-sm font-medium">Đang tải hồ sơ...</span>
      </div>
    );
  }

  if (error || !profile) {
    return (
      <div className="max-w-2xl mx-auto py-16 text-center px-4 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-8 shadow-sm">
        <AlertCircle className="w-10 h-10 text-red-500 mx-auto mb-2 opacity-80" />
        <p className="text-sm text-appText-primary dark:text-appText-dark-primary font-medium mb-4">
          {error || "Không tìm thấy người dùng này"}
        </p>
        <Link
          href="/"
          className="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-brand hover:bg-brand-hover transition"
        >
          Về trang chủ
        </Link>
      </div>
    );
  }

  const otherProfile = isMyProfile ? null : (profile as UserProfile);
  const friendship = otherProfile?.friendship?.status || "none";
  const requestId = otherProfile?.friendship?.requestId;
  const isBlocked = otherProfile?.isBlocked || false;

  const joinDate = profile.createdAt
    ? new Date(profile.createdAt).toLocaleDateString("vi-VN", {
        month: "long",
        year: "numeric",
      })
    : null;

  return (
    <div className="max-w-5xl mx-auto pb-16">
      <input
        ref={coverInputRef}
        type="file"
        accept="image/*"
        onChange={handleCoverUpload}
        className="hidden"
      />

      {/* Header Container */}
      <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl shadow-sm overflow-hidden mb-6">
        {/* Cover Image */}
        <div className="relative h-48 sm:h-64 md:h-72 bg-surface-muted dark:bg-surface-dark-muted">
          {profile.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={profile.coverUrl}
              alt="Ảnh bìa"
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-r from-brand/20 via-purple-500/20 to-pink-500/20 flex items-center justify-center text-appText-secondary" />
          )}

          {/* Gradient Overlay at bottom */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/45 via-transparent to-transparent pointer-events-none" />

          {/* Change cover button for owner */}
          {isMyProfile && (
            <button
              type="button"
              onClick={() => coverInputRef.current?.click()}
              className="absolute bottom-4 right-4 z-10 px-3.5 py-2 rounded-xl bg-black/60 hover:bg-black/80 text-white text-xs font-semibold backdrop-blur-md transition flex items-center gap-1.5 shadow-md active:scale-95"
            >
              <Camera className="w-4 h-4" />
              <span>Đổi ảnh bìa</span>
            </button>
          )}
        </div>

        {/* Profile Info & Action Buttons */}
        <div className="px-6 sm:px-8 pb-6">
          <div className="flex flex-col sm:flex-row items-center sm:items-end gap-5 sm:gap-6 -mt-16 sm:-mt-20 relative z-20">
            {/* Large Floating Avatar with Ring and Bubble */}
            <div className="relative shrink-0">
              {/* Note Speech Bubble if present */}
              {otherProfile?.note && (
                <div
                  onClick={() => setViewingNote(otherProfile.note!)}
                  className="absolute -top-12 left-1/2 -translate-x-1/2 sm:left-4 sm:translate-x-0 z-30 cursor-pointer group animate-in zoom-in-95"
                  title="Xem ghi chú"
                >
                  <div className="relative max-w-[140px] px-3 py-1.5 bg-surface-light dark:bg-surface-dark rounded-2xl shadow-xl border border-appBorder-light dark:border-appBorder-dark group-hover:scale-105 transition-transform">
                    {otherProfile.note.text ? (
                      <p className="text-[11px] font-bold text-appText-primary dark:text-appText-dark-primary truncate">
                        {otherProfile.note.text}
                      </p>
                    ) : otherProfile.note.track ? (
                      <div className="flex items-center gap-1 text-[11px] text-brand font-semibold">
                        <Music2 size={12} />
                        <span className="truncate">{otherProfile.note.track.title}</span>
                      </div>
                    ) : null}
                    {otherProfile.note.text && otherProfile.note.track && (
                      <div className="flex items-center gap-1 text-[9px] text-brand font-medium truncate mt-0.5">
                        <Music2 size={9} />
                        <span>{otherProfile.note.track.title}</span>
                      </div>
                    )}
                    {/* Bubble Tail */}
                    <div className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 sm:left-5 sm:translate-x-0 w-2.5 h-2.5 bg-surface-light dark:bg-surface-dark rounded-full border-b border-r border-appBorder-light dark:border-appBorder-dark" />
                    <div className="absolute -bottom-3 left-1/2 -translate-x-1 sm:left-4 sm:translate-x-0 w-1.5 h-1.5 bg-surface-light dark:bg-surface-dark rounded-full" />
                  </div>
                </div>
              )}

              {otherProfile?.hasStories ? (
                <Link
                  href={`/stories?user=${profile.id}`}
                  className="block p-1 bg-gradient-to-tr from-brand via-purple-500 to-rose-500 rounded-full shadow-xl hover:scale-105 transition-transform"
                  title="Xem tin của người này"
                >
                  <div className="ring-4 ring-white dark:ring-surface-dark rounded-full overflow-hidden bg-white dark:bg-surface-dark">
                    <UserAvatar
                      name={profile.name}
                      imageUrl={profile.avatarUrl}
                      size="2xl"
                      isOnline={
                        isMyProfile
                          ? true
                          : (otherProfile?.isOnline ?? false)
                      }
                    />
                  </div>
                </Link>
              ) : (
                <div className="ring-4 ring-white dark:ring-surface-dark rounded-full overflow-hidden shadow-xl bg-white dark:bg-surface-dark">
                  <UserAvatar
                    name={profile.name}
                    imageUrl={profile.avatarUrl}
                    size="2xl"
                    isOnline={
                      isMyProfile
                        ? true
                        : (otherProfile?.isOnline ?? false)
                    }
                  />
                </div>
              )}
            </div>

            {/* Profile Info (Name, Username, Stats) - to the right of Avatar on Desktop */}
            <div className="flex-1 min-w-0 text-center sm:text-left pt-1 sm:pt-0">
              <div className="flex flex-col sm:flex-row sm:items-center gap-2 justify-center sm:justify-start">
                <h1 className="text-2xl sm:text-3xl font-extrabold text-appText-primary dark:text-white tracking-tight truncate">
                  {profile.name}
                </h1>
                {otherProfile?.followsYou && (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-brand/10 dark:bg-brand/20 text-brand border border-brand/20 self-center sm:self-auto">
                    Theo dõi bạn
                  </span>
                )}
              </div>
              <p className="text-sm font-medium text-appText-secondary dark:text-appText-dark-secondary mt-0.5">
                @{profile.username}
              </p>

              {/* Stats Bar */}
              <div className="flex items-center justify-center sm:justify-start gap-3 mt-2 text-xs text-appText-secondary flex-wrap">
                <button
                  type="button"
                  onClick={() => handleTabChange("friends")}
                  className="hover:text-brand dark:hover:text-brand-light transition font-medium"
                >
                  <strong className="text-appText-primary dark:text-white font-bold">{profile.friendsCount || 0}</strong> bạn bè
                </button>
                <span className="opacity-40">•</span>
                <button
                  type="button"
                  onClick={() => setFollowModal({ isOpen: true, type: "followers" })}
                  className="hover:text-brand dark:hover:text-brand-light transition font-medium"
                >
                  <strong className="text-appText-primary dark:text-white font-bold">{profile.followersCount || 0}</strong> người theo dõi
                </button>
                <span className="opacity-40">•</span>
                <button
                  type="button"
                  onClick={() => setFollowModal({ isOpen: true, type: "following" })}
                  className="hover:text-brand dark:hover:text-brand-light transition font-medium"
                >
                  <strong className="text-appText-primary dark:text-white font-bold">{profile.followingCount || 0}</strong> đang theo dõi
                </button>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex items-center justify-center sm:justify-end gap-2 w-full sm:w-auto mt-3 sm:mt-0 flex-wrap sm:flex-nowrap shrink-0">
              {isMyProfile ? (
                <>
                  <Link
                    href="/settings/profile"
                    className="px-4 py-2 rounded-xl text-sm font-semibold bg-surface-muted hover:bg-appBorder-light dark:bg-surface-dark-muted dark:hover:bg-appBorder-dark text-appText-primary dark:text-appText-dark-primary transition shadow-sm active:scale-95"
                  >
                    Chỉnh sửa hồ sơ
                  </Link>
                  <Link
                    href="/saved"
                    className="p-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95"
                    title="Bài đã lưu"
                  >
                    <Bookmark className="w-5 h-5" />
                  </Link>
                </>
              ) : isBlocked ? (
                <button
                  type="button"
                  disabled={actionBusy}
                  onClick={handleUnblockUser}
                  className="px-4 py-2 rounded-xl text-sm font-semibold bg-red-600 hover:bg-red-700 text-white transition flex items-center gap-1.5 active:scale-95"
                >
                  <Lock className="w-4 h-4" />
                  <span>Bỏ chặn</span>
                </button>
              ) : (
                <>
                  {/* Friendship Buttons */}
                  {friendship === "none" && (
                    <button
                      type="button"
                      disabled={actionBusy}
                      onClick={handleSendRequest}
                      className="px-4 py-2 rounded-xl text-sm font-semibold bg-brand hover:bg-brand-hover text-white shadow-sm transition flex items-center gap-1.5 active:scale-95"
                    >
                      <UserPlus className="w-4 h-4" />
                      <span>Thêm bạn</span>
                    </button>
                  )}

                  {friendship === "pending_outgoing" && (
                    <button
                      type="button"
                      disabled={actionBusy || !requestId}
                      onClick={() => requestId && handleCancelRequest(requestId)}
                      className="px-4 py-2 rounded-xl text-sm font-semibold border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95"
                    >
                      Hủy lời mời
                    </button>
                  )}

                  {friendship === "pending_incoming" && (
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        disabled={actionBusy || !requestId}
                        onClick={() => requestId && handleAcceptRequest(requestId)}
                        className="px-4 py-2 rounded-xl text-sm font-semibold bg-brand hover:bg-brand-hover text-white shadow-sm transition active:scale-95"
                      >
                        Chấp nhận
                      </button>
                      <button
                        type="button"
                        disabled={actionBusy || !requestId}
                        onClick={() => requestId && handleCancelRequest(requestId)}
                        className="px-4 py-2 rounded-xl text-sm font-semibold border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95"
                      >
                        Từ chối
                      </button>
                    </div>
                  )}

                  {friendship === "friends" && (
                    <>
                      <Link
                        href={`/messages?user=${targetId}`}
                        className="px-4 py-2 rounded-xl text-sm font-semibold bg-brand hover:bg-brand-hover text-white shadow-sm transition flex items-center gap-1.5 active:scale-95"
                      >
                        <MessageCircle className="w-4 h-4" />
                        <span>Nhắn tin</span>
                      </Link>
                      <button
                        type="button"
                        disabled={actionBusy}
                        onClick={handleUnfriend}
                        className="px-3.5 py-2 rounded-xl text-sm font-semibold border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition flex items-center gap-1.5 active:scale-95"
                        title="Bạn bè (Bấm để hủy kết bạn)"
                      >
                        <Check className="w-4 h-4 text-emerald-500" />
                        <span>Bạn bè</span>
                      </button>
                    </>
                  )}

                  {/* Follow Button */}
                  <button
                    type="button"
                    disabled={actionBusy}
                    onClick={handleToggleFollow}
                    className={`px-3.5 py-2 rounded-xl text-sm font-semibold transition flex items-center gap-1.5 active:scale-95 ${
                      otherProfile?.isFollowing
                        ? "border border-appBorder-light dark:border-appBorder-dark text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted"
                        : "bg-surface-muted dark:bg-surface-dark-muted text-appText-primary dark:text-appText-dark-primary hover:bg-appBorder-light"
                    }`}
                  >
                    {otherProfile?.isFollowing ? (
                      <>
                        <UserCheck className="w-4 h-4 text-emerald-500" />
                        <span>Đang theo dõi</span>
                      </>
                    ) : (
                      <>
                        <UserPlus className="w-4 h-4" />
                        <span>Theo dõi</span>
                      </>
                    )}
                  </button>

                  {/* More options (Report / Block) */}
                  <div className="relative">
                    <button
                      type="button"
                      onClick={() => setMenuOpen(!menuOpen)}
                      className="p-2 rounded-xl border border-appBorder-light dark:border-appBorder-dark text-appText-secondary dark:text-appText-dark-secondary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95"
                    >
                      <MoreHorizontal className="w-5 h-5" />
                    </button>

                    {menuOpen && (
                      <>
                        <div
                          className="fixed inset-0 z-30"
                          onClick={() => setMenuOpen(false)}
                        />
                        <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-xl shadow-lg z-40 py-1.5 text-xs animate-dropdown-in">
                          <button
                            type="button"
                            onClick={() => {
                              setMenuOpen(false);
                              setReportModalOpen(true);
                            }}
                            className="w-full px-3.5 py-2 text-left hover:bg-surface-muted dark:hover:bg-surface-dark-muted flex items-center gap-2 text-appText-primary dark:text-appText-dark-primary"
                          >
                            <Flag className="w-4 h-4 text-appText-secondary" />
                            <span>Báo cáo trang cá nhân</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setMenuOpen(false);
                              handleBlockUser();
                            }}
                            className="w-full px-3.5 py-2 text-left hover:bg-red-50 dark:hover:bg-red-950/40 text-red-600 dark:text-red-400 flex items-center gap-2"
                          >
                            <UserX className="w-4 h-4" />
                            <span>Chặn {profile.name}</span>
                          </button>
                        </div>
                      </>
                    )}
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Bio Section */}
          {profile.bio && (
            <div className="mt-4 pt-4 border-t border-appBorder-light/70 dark:border-appBorder-dark/70 text-center sm:text-left">
              <p className="text-sm text-appText-primary dark:text-appText-dark-primary max-w-2xl leading-relaxed whitespace-pre-wrap">
                {profile.bio}
              </p>
            </div>
          )}
        </div>

        {/* Section Tabs */}
        <div className="flex border-t border-appBorder-light dark:border-appBorder-dark px-4 sm:px-8 select-none overflow-x-auto scrollbar-none">
          {(
            [
              { key: "posts", label: "Bài viết", icon: FileText, count: null },
              { key: "about", label: "Giới thiệu", icon: Info, count: null },
              { key: "photos", label: "Ảnh", icon: ImageIcon, count: photos.length },
              { key: "friends", label: "Bạn bè", icon: Users, count: profile.friendsCount || friends.length },
            ] as const
          ).map((t) => {
            const isActive = activeTab === t.key;
            const Icon = t.icon;
            return (
              <button
                key={t.key}
                type="button"
                onClick={() => handleTabChange(t.key)}
                className={`flex items-center gap-2 py-3.5 px-4 font-semibold text-sm border-b-2 transition whitespace-nowrap -mb-[1px] ${
                  isActive
                    ? "border-brand text-brand dark:text-brand-light"
                    : "border-transparent text-appText-secondary hover:text-appText-primary dark:hover:text-appText-dark-primary"
                }`}
              >
                <Icon size={16} />
                <span>{t.label}</span>
                {typeof t.count === "number" && t.count > 0 && (
                  <span
                    className={`text-[11px] px-2 py-0.5 rounded-full font-medium ${
                      isActive
                        ? "bg-brand/10 text-brand dark:bg-brand/20 dark:text-brand-light"
                        : "bg-surface-muted dark:bg-surface-dark-muted text-appText-secondary"
                    }`}
                  >
                    {t.count}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Tab Contents */}
      {/* 1. Posts Tab */}
      {activeTab === "posts" && (
        <div className="flex flex-col lg:flex-row gap-6 items-start">
          {/* Left Column: Intro, Photos, Friends widgets (lg:w-80 xl:w-88 shrink-0 space-y-4) */}
          <div className="w-full lg:w-80 xl:w-88 shrink-0 space-y-4">
            {/* Widget 1: Giới thiệu */}
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-5 shadow-sm space-y-3">
              <h3 className="font-bold text-base text-appText-primary dark:text-white">
                Giới thiệu
              </h3>
              {profile.bio && (
                <p className="text-xs text-appText-secondary dark:text-appText-dark-secondary italic text-center pb-3 border-b border-appBorder-light dark:border-appBorder-dark">
                  &ldquo;{profile.bio}&rdquo;
                </p>
              )}
              <div className="space-y-2.5 text-xs text-appText-primary dark:text-appText-dark-primary">
                {profile.about?.location && (
                  <div className="flex items-center gap-2.5">
                    <MapPin size={16} className="text-brand shrink-0" />
                    <span>Sống tại <strong className="font-semibold">{profile.about.location}</strong></span>
                  </div>
                )}
                {profile.about?.hometown && (
                  <div className="flex items-center gap-2.5">
                    <Home size={16} className="text-emerald-500 shrink-0" />
                    <span>Đến từ <strong className="font-semibold">{profile.about.hometown}</strong></span>
                  </div>
                )}
                {profile.about?.workplace && (
                  <div className="flex items-center gap-2.5">
                    <Briefcase size={16} className="text-amber-500 shrink-0" />
                    <span>Làm việc tại <strong className="font-semibold">{profile.about.workplace}</strong></span>
                  </div>
                )}
                {profile.about?.education && (
                  <div className="flex items-center gap-2.5">
                    <GraduationCap size={16} className="text-purple-500 shrink-0" />
                    <span>Học tại <strong className="font-semibold">{profile.about.education}</strong></span>
                  </div>
                )}
                {profile.about?.website && (
                  <div className="flex items-center gap-2.5">
                    <Globe size={16} className="text-blue-500 shrink-0" />
                    <a
                      href={profile.about.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-brand hover:underline truncate"
                    >
                      {profile.about.website}
                    </a>
                  </div>
                )}
                {joinDate && (
                  <div className="flex items-center gap-2.5 text-appText-secondary">
                    <Calendar size={16} className="shrink-0" />
                    <span>Tham gia từ {joinDate}</span>
                  </div>
                )}
              </div>

              {isMyProfile && (
                <Link
                  href="/settings/profile"
                  className="block w-full py-2 text-center rounded-xl bg-surface-muted hover:bg-appBorder-light dark:bg-surface-dark-muted dark:hover:bg-appBorder-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary transition mt-3 active:scale-95"
                >
                  Chỉnh sửa chi tiết
                </Link>
              )}
            </div>

            {/* Widget 2: Ảnh gần đây */}
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <h3 className="font-bold text-base text-appText-primary dark:text-white">Ảnh</h3>
                  <span className="text-xs text-appText-secondary">{photos.length} ảnh</span>
                </div>
                <button
                  type="button"
                  onClick={() => handleTabChange("photos")}
                  className="text-xs text-brand hover:underline font-semibold"
                >
                  Xem tất cả
                </button>
              </div>
              {photos.length === 0 ? (
                <p className="text-xs text-appText-secondary py-4 text-center">Chưa có ảnh nào</p>
              ) : (
                <div className="grid grid-cols-3 gap-1.5 rounded-xl overflow-hidden">
                  {photos.slice(0, 6).map((photo, idx) => (
                    <button
                      key={photo.postId || idx}
                      type="button"
                      onClick={() => {
                        setSelectedPhotoIndex(idx);
                        setImageViewerOpen(true);
                      }}
                      className="aspect-square relative group overflow-hidden bg-surface-muted dark:bg-surface-dark-muted"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={photo.imageUrl}
                        alt=""
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Widget 3: Bạn bè */}
            <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <h3 className="font-bold text-base text-appText-primary dark:text-white">Bạn bè</h3>
                  <span className="text-xs text-appText-secondary">{profile.friendsCount || friends.length} người bạn</span>
                </div>
                <button
                  type="button"
                  onClick={() => handleTabChange("friends")}
                  className="text-xs text-brand hover:underline font-semibold"
                >
                  Xem tất cả
                </button>
              </div>
              {friends.length === 0 ? (
                <p className="text-xs text-appText-secondary py-4 text-center">Chưa có bạn bè</p>
              ) : (
                <div className="grid grid-cols-3 gap-2.5">
                  {friends.slice(0, 6).map((friend) => (
                    <Link
                      key={friend.id}
                      href={`/profile/${friend.id}`}
                      className="group text-center"
                    >
                      <div className="aspect-square rounded-xl overflow-hidden mb-1.5 bg-brand-soft text-brand dark:bg-surface-dark-muted dark:text-brand-soft ring-1 ring-appBorder-light dark:ring-appBorder-dark flex items-center justify-center">
                        {friend.avatarUrl ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={friend.avatarUrl}
                            alt={friend.name}
                            className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                          />
                        ) : (
                          <User size={28} className="text-brand dark:text-brand-soft opacity-80" />
                        )}
                      </div>
                      <p className="text-[11px] font-semibold text-appText-primary dark:text-appText-dark-primary truncate group-hover:text-brand">
                        {friend.name}
                      </p>
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Right Column: Post List */}
          <div className="flex-1 min-w-0 space-y-4 w-full">
            {/* Create Post Card for Profile Owner */}
            {isMyProfile && (
              <CreatePostCard
                onPostCreated={(newPost) => setPosts((prev) => [newPost, ...prev])}
              />
            )}

            {postsLoading && posts.length === 0 ? (
              <div className="py-16 flex flex-col items-center justify-center text-appText-secondary bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl">
                <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
                <span className="text-xs">Đang tải bài viết...</span>
              </div>
            ) : posts.length === 0 ? (
              <div className="p-8 text-center bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl">
                <FileText className="w-10 h-10 text-appText-secondary/60 dark:text-appText-dark-secondary/50 mx-auto mb-2" />
                <p className="text-sm font-semibold text-appText-primary dark:text-appText-dark-primary">
                  Chưa có bài viết nào
                </p>
              </div>
            ) : (
              posts.map((post) => (
                <PostCard
                  key={post.id}
                  post={post}
                  onPostDeleted={(id) => setPosts((prev) => prev.filter((p) => p.id !== id))}
                  onPostHidden={(id) => setPosts((prev) => prev.filter((p) => p.id !== id))}
                />
              ))
            )}

            {postsCursor && (
              <div className="pt-2 text-center">
                <button
                  type="button"
                  disabled={postsLoading}
                  onClick={() => loadPosts(postsCursor)}
                  className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark bg-white dark:bg-surface-dark text-xs font-semibold text-appText-primary dark:text-appText-dark-primary hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition active:scale-95"
                >
                  {postsLoading ? "Đang tải thêm..." : "Xem thêm bài viết"}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 2. About Tab */}
      {activeTab === "about" && (
        <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8 space-y-4">
          <h2 className="text-base font-bold text-appText-primary dark:text-white mb-4">
            Thông tin giới thiệu
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {profile.about?.location && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <MapPin className="w-5 h-5 text-brand flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Nơi sống</span>
                  <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                    {profile.about.location}
                  </span>
                </div>
              </div>
            )}

            {profile.about?.hometown && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <Home className="w-5 h-5 text-emerald-500 flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Quê quán</span>
                  <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                    {profile.about.hometown}
                  </span>
                </div>
              </div>
            )}

            {profile.about?.workplace && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <Briefcase className="w-5 h-5 text-amber-500 flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Nơi làm việc</span>
                  <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                    {profile.about.workplace}
                  </span>
                </div>
              </div>
            )}

            {profile.about?.education && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <GraduationCap className="w-5 h-5 text-purple-500 flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Học vấn</span>
                  <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                    {profile.about.education}
                  </span>
                </div>
              </div>
            )}

            {profile.about?.website && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <Globe className="w-5 h-5 text-blue-500 flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Website</span>
                  <a
                    href={profile.about.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm font-medium text-brand dark:text-brand-light hover:underline truncate block"
                  >
                    {profile.about.website}
                  </a>
                </div>
              </div>
            )}

            {profile.about?.birthday && (
              <div className="flex items-center gap-3 p-3.5 rounded-xl bg-surface-muted dark:bg-surface-dark-muted/60">
                <Calendar className="w-5 h-5 text-rose-500 flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-xs text-appText-secondary block">Sinh nhật</span>
                  <span className="text-sm font-medium text-appText-primary dark:text-appText-dark-primary">
                    {profile.about.birthday}
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* 3. Photos Tab */}
      {activeTab === "photos" && (
        <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
          <h2 className="text-base font-bold text-appText-primary dark:text-white mb-4">
            Ảnh ({photos.length})
          </h2>

          {photosLoading && photos.length === 0 ? (
            <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tải ảnh...</span>
            </div>
          ) : photos.length === 0 ? (
            <div className="py-12 text-center text-appText-secondary">
              <ImageIcon className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-semibold">Chưa có ảnh nào được đăng</p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-3 sm:grid-cols-4 gap-2 sm:gap-3">
                {photos.map((photo, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => {
                      setSelectedPhotoIndex(idx);
                      setImageViewerOpen(true);
                    }}
                    className="relative aspect-square rounded-xl overflow-hidden group border border-appBorder-light dark:border-appBorder-dark cursor-pointer"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={photo.imageUrl}
                      alt=""
                      className="w-full h-full object-cover group-hover:scale-105 transition duration-200"
                    />
                  </button>
                ))}
              </div>

              {photosCursor && (
                <div className="pt-6 text-center">
                  <button
                    type="button"
                    disabled={photosLoading}
                    onClick={() => loadPhotos(photosCursor)}
                    className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark text-xs font-semibold hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                  >
                    {photosLoading ? "Đang tải..." : "Xem thêm ảnh"}
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* 4. Friends Tab */}
      {activeTab === "friends" && (
        <div className="bg-white dark:bg-surface-dark border border-appBorder-light dark:border-appBorder-dark rounded-2xl p-6 sm:p-8">
          <h2 className="text-base font-bold text-appText-primary dark:text-white mb-4">
            Bạn bè ({profile.friendsCount || friends.length})
          </h2>

          {friendsLoading && friends.length === 0 ? (
            <div className="py-16 flex flex-col items-center justify-center text-appText-secondary">
              <div className="w-7 h-7 border-2 border-brand border-t-transparent rounded-full animate-spin mb-2" />
              <span className="text-xs">Đang tải danh sách bạn bè...</span>
            </div>
          ) : friends.length === 0 ? (
            <div className="py-12 text-center text-appText-secondary">
              <Users className="w-10 h-10 mx-auto mb-2 opacity-50" />
              <p className="text-sm font-semibold">Chưa có bạn bè nào</p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {friends.map((friend) => (
                  <div
                    key={friend.id}
                    className="p-3.5 rounded-xl border border-appBorder-light dark:border-appBorder-dark hover:border-appBorder-light dark:hover:border-appBorder-dark flex items-center justify-between gap-3 transition"
                  >
                    <Link
                      href={`/profile/${friend.id}`}
                      className="flex items-center gap-3 min-w-0 flex-1 hover:opacity-80 transition"
                    >
                      <UserAvatar
                        name={friend.name}
                        imageUrl={friend.avatarUrl}
                        size="md"
                        isOnline={friend.isOnline ?? false}
                      />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-bold text-appText-primary dark:text-white truncate">
                          {friend.name}
                        </p>
                        <p className="text-xs text-appText-secondary truncate">
                          @{friend.username}
                        </p>
                      </div>
                    </Link>

                    <Link
                      href={`/messages?user=${friend.id}`}
                      className="p-2 rounded-lg bg-brand-soft dark:bg-brand/20 text-brand dark:text-brand-light hover:bg-brand/15 transition flex-shrink-0"
                      title="Nhắn tin"
                    >
                      <MessageCircle className="w-4 h-4" />
                    </Link>
                  </div>
                ))}
              </div>

              {friendsCursor && (
                <div className="pt-6 text-center">
                  <button
                    type="button"
                    disabled={friendsLoading}
                    onClick={() => loadFriends(friendsCursor)}
                    className="px-5 py-2 rounded-full border border-appBorder-light dark:border-appBorder-dark text-xs font-semibold hover:bg-surface-muted dark:hover:bg-surface-dark-muted transition"
                  >
                    {friendsLoading ? "Đang tải..." : "Xem thêm bạn bè"}
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Followers / Following List Modal */}
      {followModal.isOpen && targetId && (
        <FollowListModal
          userId={targetId}
          type={followModal.type}
          isOpen={followModal.isOpen}
          onClose={() => setFollowModal((prev) => ({ ...prev, isOpen: false }))}
        />
      )}

      {/* Report Modal */}
      {reportModalOpen && targetId && (
        <ReportModal
          isOpen={reportModalOpen}
          onClose={() => setReportModalOpen(false)}
          targetType="user"
          targetId={targetId}
          targetTitle={profile.name}
        />
      )}

      {/* View Note Modal */}
      {viewingNote && (
        <ViewNoteModal
          note={viewingNote}
          isOpen={Boolean(viewingNote)}
          onClose={() => setViewingNote(null)}
          onOpenConversation={(convId) => router.push(`/messages/${convId}`)}
        />
      )}

      {/* Lightbox Image Viewer */}
      {imageViewerOpen && photos.length > 0 && (
        <ImageViewerModal
          images={photos.map((p) => p.imageUrl)}
          initialIndex={selectedPhotoIndex}
          isOpen={imageViewerOpen}
          onClose={() => setImageViewerOpen(false)}
        />
      )}
    </div>
  );
}
