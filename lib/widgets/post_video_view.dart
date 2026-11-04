import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post_video.dart';
import 'package:flutter_learning/screens/video_player_screen.dart';

/// The video of a post in a feed: the still with a play button once the server
/// has converted it, a short message before that (or when that failed).
class PostVideoView extends StatelessWidget {
  final PostVideo video;

  /// Tapping plays the video. Off where a parent already handles the tap
  /// (the Explore grid opens the post instead).
  final bool playable;

  const PostVideoView({super.key, required this.video, this.playable = true});

  @override
  Widget build(BuildContext context) {
    final ratio = (video.width != null && video.height != null)
        ? (video.width! / video.height!).clamp(0.625, 1.8)
        : 16 / 9;

    return AspectRatio(
      aspectRatio: ratio,
      child: Container(
        color: Colors.black,
        child: video.isReady ? _ready(context) : _notReady(),
      ),
    );
  }

  Widget _notReady() {
    final failed = video.isFailed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (failed)
            const Icon(Icons.error_outline_rounded, color: Colors.white70)
          else
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            failed ? 'Không xử lý được video' : 'Đang xử lý video...',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _ready(BuildContext context) {
    final label = video.durationLabel;
    final content = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (video.thumbnailUrl != null)
          Image.network(
            video.thumbnailUrl!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox(),
          ),
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        if (label != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
    if (!playable) return content;
    return Semantics(
      button: true,
      label: 'Phát video',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: video.url!)),
        ),
        child: content,
      ),
    );
  }
}
