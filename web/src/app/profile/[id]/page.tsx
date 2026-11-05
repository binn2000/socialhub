"use client";

import { useParams } from "next/navigation";
import { ProfileView } from "@/components/profile/ProfileView";

export default function UserProfilePage() {
  const params = useParams();
  const userId = params.id as string;

  return <ProfileView userId={userId} />;
}
