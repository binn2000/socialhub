/// The video of a post. [url] and [thumbnailUrl] exist only once the server has
/// converted the upload ([status] `ready`); a draft that is still on its way
/// carries the picked file in [localPath].
class PostVideo {
  final String status;
  final String? url;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? width;
  final int? height;
  final String? localPath;

  const PostVideo({
    required this.status,
    this.url,
    this.thumbnailUrl,
    this.durationSeconds,
    this.width,
    this.height,
    this.localPath,
  });

  /// A video picked on the phone, not sent yet.
  const PostVideo.draft(String path)
    : this(status: 'processing', localPath: path);

  bool get isReady => status == 'ready' && url != null;
  bool get isFailed => status == 'failed';
  bool get isProcessing => !isReady && !isFailed;

  /// "0:45" style label, or null when the length is not known.
  String? get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null) return null;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
