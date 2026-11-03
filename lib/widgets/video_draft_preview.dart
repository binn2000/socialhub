import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The video picked for a new post: its first frame with a play mark and a
/// close button to remove it, like the previews of picked photos. Where no
/// frame can be read it shows a dark box with a camera icon instead.
class VideoDraftPreview extends StatefulWidget {
  final String path;
  final VoidCallback onRemove;
  final double height;

  const VideoDraftPreview({
    super.key,
    required this.path,
    required this.onRemove,
    this.height = 220,
  });

  @override
  State<VideoDraftPreview> createState() => _VideoDraftPreviewState();
}

class _VideoDraftPreviewState extends State<VideoDraftPreview> {
  late final VideoPlayerController _controller;
  bool _hasFrame = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _controller
        .initialize()
        .then((_) async {
          // Some players draw nothing until they have moved, so step past 0.
          await _controller.seekTo(const Duration(milliseconds: 100));
          if (mounted) setState(() => _hasFrame = true);
        })
        .catchError((Object _) {
          // No frame to show; the placeholder stays.
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (_hasFrame)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: Icon(Icons.videocam_rounded, color: Colors.white54),
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
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                button: true,
                label: 'Bỏ video',
                child: InkWell(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
