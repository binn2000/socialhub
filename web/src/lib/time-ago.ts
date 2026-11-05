/**
 * Formats an ISO 8601 timestamp to short Vietnamese relative time,
 * matching lib/utils/time_ago.dart in the Flutter app.
 */
export function timeAgo(isoTimestamp: string, now: Date = new Date()): string {
  if (!isoTimestamp) return "";

  const time = new Date(isoTimestamp);
  if (isNaN(time.getTime())) return "";

  const diffMs = now.getTime() - time.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHours = Math.floor(diffMin / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMin < 1) return "Vừa xong";
  if (diffMin < 60) return `${diffMin} phút trước`;
  if (diffHours < 24) return `${diffHours} giờ trước`;
  if (diffDays === 1) return "Hôm qua";
  if (diffDays < 7) return `${diffDays} ngày trước`;

  const two = (n: number) => n.toString().padStart(2, "0");
  return `${two(time.getDate())}/${two(time.getMonth() + 1)}/${time.getFullYear()}`;
}
