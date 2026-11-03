import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Why a picked video cannot be posted; [message] is shown to the user.
class VideoRejected implements Exception {
  final String message;

  const VideoRejected(this.message);
}

/// Shrinks a picked video so it fits what the server accepts (60 seconds,
/// 50 MB) and returns the path of the smaller file. A phone clip of a few
/// seconds is often far bigger than 50 MB, mostly because of the 4K or HEVC
/// recording, so it is re-encoded at 720p on the phone before uploading.
Future<String> compressVideoFile(String path) async {
  const maxSeconds = 60;
  const maxBytes = 50 * 1024 * 1024;

  final info = await VideoCompress.getMediaInfo(path);
  final seconds = (info.duration ?? 0) / 1000;
  if (seconds > maxSeconds + 0.5) {
    throw const VideoRejected('Video dài tối đa 60 giây');
  }

  final result = await VideoCompress.compressVideo(
    path,
    quality: VideoQuality.Res1280x720Quality,
  );
  final compressed = result?.path;
  if (compressed == null) {
    throw const VideoRejected('Không nén được video này');
  }

  final bytes = result?.filesize ?? await File(compressed).length();
  if (bytes > maxBytes) {
    throw const VideoRejected(
      'Video vẫn lớn hơn 50 MB sau khi nén, hãy chọn video ngắn hơn',
    );
  }
  return compressed;
}
