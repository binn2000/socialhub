import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/youtube_video.dart';
import 'package:flutter_learning/services/social_api.dart';

/// The "Video" tab of Explore: a search box and the YouTube results (the
/// popular videos while the box is empty). Tapping a video calls [onPlay].
class YoutubeVideosView extends StatefulWidget {
  final Future<VideoPage> Function(String query, String? cursor) search;
  final ValueChanged<YoutubeVideo> onPlay;

  const YoutubeVideosView({
    super.key,
    required this.search,
    required this.onPlay,
  });

  @override
  State<YoutubeVideosView> createState() => _YoutubeVideosViewState();
}

class _YoutubeVideosViewState extends State<YoutubeVideosView> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<YoutubeVideo> _videos = [];
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  // Answers can arrive out of order while typing: only the newest counts.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({String? cursor}) async {
    final id = ++_requestId;
    setState(() {
      if (cursor == null) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final page = await widget.search(_controller.text, cursor);
      if (!mounted || id != _requestId) return;
      setState(() {
        _videos = cursor == null ? page.videos : [..._videos, ...page.videos];
        _next = page.nextCursor;
      });
    } on ApiException catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = error.code == 'video_unavailable'
            ? 'Hiện chưa tìm được video (YouTube chưa sẵn sàng hoặc đã hết hạn mức hôm nay). Thử lại sau nhé.'
            : error.displayMessage;
      });
    }
    if (mounted && id == _requestId) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    // 600 ms: a YouTube search costs 100 of the 10,000 free daily units.
    _debounce = Timer(const Duration(milliseconds: 600), _load);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm video trên YouTube...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy video nào.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (_next != null && !_loadingMore && n.metrics.extentAfter < 300) {
          _load(cursor: _next);
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _videos.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _videos.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _VideoCard(
            video: _videos[index],
            onTap: () => widget.onPlay(_videos[index]),
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final YoutubeVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = video.durationLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          button: true,
          label: 'Phát video ${video.title}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: video.thumbnailUrl == null
                            ? null
                            : Image.network(
                                video.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(),
                              ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 52,
                          color: Colors.white70,
                        ),
                      ),
                      if (duration.isNotEmpty)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                video.channelTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
