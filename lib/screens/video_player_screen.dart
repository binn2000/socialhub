import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays one post video full screen: tap to pause or resume.
class VideoPlayerScreen extends StatefulWidget {
  final String url;

  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
      ),
      body: Center(
        child: _failed
            ? const Text(
                'Không phát được video',
                style: TextStyle(color: Colors.white),
              )
            : !_ready
            ? const CircularProgressIndicator()
            : GestureDetector(
                onTap: _togglePlay,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => value.isPlaying
                          ? const SizedBox.shrink()
                          : const Positioned.fill(
                              child: Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 72,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
