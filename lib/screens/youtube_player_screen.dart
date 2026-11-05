import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/models/youtube_video.dart';
import 'package:flutter_learning/widgets/youtube_videos_view.dart'
    show showYoutubeVideoShareSheet;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Plays a YouTube video with YouTube's own embedded player (nothing is
/// downloaded), along with channel info, quick actions, and an "Up Next"
/// playlist queue.
class YoutubePlayerScreen extends StatefulWidget {
  final YoutubeVideo video;
  final List<YoutubeVideo> relatedVideos;
  final VoidCallback? onOpenMessages;

  const YoutubePlayerScreen({
    super.key,
    required this.video,
    this.relatedVideos = const [],
    this.onOpenMessages,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final YoutubePlayerController _controller;
  late YoutubeVideo _currentVideo;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _currentVideo.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  List<YoutubeVideo> get _playlist {
    if (widget.relatedVideos.isEmpty) return [_currentVideo];
    final hasCurrent = widget.relatedVideos.any(
      (v) => v.id == _currentVideo.id,
    );
    return hasCurrent
        ? widget.relatedVideos
        : [_currentVideo, ...widget.relatedVideos];
  }

  int get _currentIndex =>
      _playlist.indexWhere((v) => v.id == _currentVideo.id);

  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext =>
      _currentIndex >= 0 && _currentIndex < _playlist.length - 1;

  void _switchVideo(YoutubeVideo next) {
    if (next.id == _currentVideo.id) return;
    setState(() {
      _currentVideo = next;
    });
    _controller.loadVideoById(videoId: next.id);
  }

  Future<void> _copyLink() async {
    final url = 'https://www.youtube.com/watch?v=${_currentVideo.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép liên kết video vào bộ nhớ tạm'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final playlist = _playlist;
    final channelInitial = _currentVideo.channelTitle.trim().isEmpty
        ? 'Y'
        : _currentVideo.channelTitle.trim().characters.first.toUpperCase();

    return YoutubePlayerControllerProvider(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentVideo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              onPressed: () => showYoutubeVideoShareSheet(
                context,
                video: _currentVideo,
                onOpenMessages: widget.onOpenMessages == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onOpenMessages!();
                      },
              ),
              tooltip: 'Chia sẻ video',
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            YoutubePlayer(controller: _controller),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentVideo.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                              child: Text(
                                channelInitial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentVideo.channelTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_currentVideo.durationLabel.isNotEmpty)
                                    Text(
                                      'Thời lượng: ${_currentVideo.durationLabel}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => showYoutubeVideoShareSheet(
                                  context,
                                  video: _currentVideo,
                                  onOpenMessages: widget.onOpenMessages == null
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          widget.onOpenMessages!();
                                        },
                                ),
                                icon: const Icon(Icons.send_rounded, size: 17),
                                label: const Text('Gửi bạn bè'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _copyLink,
                                icon: const Icon(Icons.link_rounded, size: 17),
                                label: const Text('Sao chép link'),
                              ),
                              if (playlist.length > 1) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _hasPrev
                                      ? () => _switchVideo(
                                          playlist[_currentIndex - 1],
                                        )
                                      : null,
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Trước'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _hasNext
                                      ? () => _switchVideo(
                                          playlist[_currentIndex + 1],
                                        )
                                      : null,
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Tiếp theo'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (playlist.length > 1) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_play_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Danh sách phát tiếp theo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${playlist.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < playlist.length; i++)
                      _UpNextTile(
                        video: playlist[i],
                        index: i + 1,
                        isPlaying: playlist[i].id == _currentVideo.id,
                        onTap: () => _switchVideo(playlist[i]),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpNextTile extends StatelessWidget {
  final YoutubeVideo video;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _UpNextTile({
    required this.video,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = video.durationLabel;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isPlaying
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: isPlaying
                  ? Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    )
                  : Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 112,
                height: 63,
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
                    if (duration.isNotEmpty)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPlaying
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    video.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
