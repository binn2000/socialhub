/// One YouTube search result (`GET /videos/search`). Only the id is used to
/// play it, with YouTube's own embedded player.
class YoutubeVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String? thumbnailUrl;
  final int? durationSeconds;

  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  /// A YouTube video id is exactly 11 URL-safe characters.
  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static bool isValidId(String id) => _idPattern.hasMatch(id);

  /// 3723 -> "1:02:03", 75 -> "1:15"; empty when unknown.
  String get durationLabel {
    final total = durationSeconds;
    if (total == null || total < 0) return '';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}
