import React from "react";
import Image from "next/image";
import { User } from "lucide-react";

interface UserAvatarProps {
  src?: string | null;
  imageUrl?: string | null;
  name?: string;
  size?: "xs" | "sm" | "md" | "lg" | "xl" | "2xl";
  isOnline?: boolean;
  className?: string;
}

const sizeMap = {
  xs: { box: "w-7 h-7", icon: 14, badge: "w-2 h-2" },
  sm: { box: "w-9 h-9", icon: 18, badge: "w-2.5 h-2.5" },
  md: { box: "w-11 h-11", icon: 22, badge: "w-3 h-3" },
  lg: { box: "w-16 h-16", icon: 30, badge: "w-3.5 h-3.5" },
  xl: { box: "w-24 h-24", icon: 44, badge: "w-4 h-4" },
  "2xl": { box: "w-32 h-32 sm:w-36 sm:h-36", icon: 64, badge: "w-5 h-5" },
};

export function UserAvatar({
  src,
  imageUrl,
  name = "User",
  size = "md",
  isOnline = false,
  className = "",
}: UserAvatarProps) {
  const avatarSrc = src ?? imageUrl;
  const { box, icon, badge } = sizeMap[size];
  const [imageError, setImageError] = React.useState(false);

  const showImage = avatarSrc && !imageError && avatarSrc.trim() !== "";

  return (
    <div className={`relative inline-block flex-shrink-0 ${box} ${className}`}>
      <div className={`w-full h-full rounded-full overflow-hidden flex items-center justify-center bg-brand-soft text-brand dark:bg-surface-dark-muted dark:text-brand-soft`}>
        {showImage ? (
          <Image
            src={avatarSrc}
            alt={name}
            width={96}
            height={96}
            className="w-full h-full object-cover"
            onError={() => setImageError(true)}
            unoptimized={avatarSrc.startsWith("http://localhost") || avatarSrc.startsWith("http://127.0.0.1")}
          />
        ) : (
          <User size={icon} />
        )}
      </div>

      {isOnline && (
        <span
          className={`absolute bottom-0 right-0 ${badge} bg-success rounded-full ring-2 ring-white dark:ring-surface-dark`}
          title="Đang hoạt động"
        />
      )}
    </div>
  );
}
