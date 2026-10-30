/// Short Vietnamese relative time for an ISO 8601 timestamp, the way the mock
/// data writes it ("15 phút trước", "Hôm qua").
String timeAgo(String isoTimestamp, {DateTime? now}) {
  final time = DateTime.tryParse(isoTimestamp)?.toLocal();
  if (time == null) return '';

  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
  if (difference.inHours < 24) return '${difference.inHours} giờ trước';
  if (difference.inDays == 1) return 'Hôm qua';
  if (difference.inDays < 7) return '${difference.inDays} ngày trước';

  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year}';
}
