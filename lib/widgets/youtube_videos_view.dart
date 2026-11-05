import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/models/youtube_video.dart';
import 'package:flutter_learning/services/social_api.dart';

class _VideoCategory {
  final String id;
  final String label;
  final String query;

  const _VideoCategory(this.id, this.label, this.query);
}

// The same topics and search words as the web (`YOUTUBE_CATEGORIES`): the server
// caches an answer by its words, so both apps share one YouTube search (100 of
// the 10,000 free daily units) instead of paying twice.
const List<_VideoCategory> _kCategories = [
  _VideoCategory('all', '🔥 Nổi bật', ''),
  _VideoCategory('music', '🎵 Âm nhạc', 'nhạc việt mới nhất'),
  _VideoCategory('gaming', '🎮 Gaming', 'gaming việt nam'),
  _VideoCategory('movies', '🎬 Phim & Trailer', 'review phim trailer'),
  _VideoCategory('sports', '⚽ Thể thao', 'bóng đá thể thao'),
  _VideoCategory('tech', '💻 Công nghệ', 'đánh giá công nghệ'),
  _VideoCategory('food', '🍜 Ẩm thực', 'ẩm thực đường phố'),
  _VideoCategory('comedy', '😂 Giải trí', 'hài kịch giải trí'),
  _VideoCategory('study', '📚 Học tập', 'kiến thức thú vị'),
];

/// Bottom sheet to share or copy a YouTube video link.
void showYoutubeVideoShareSheet(
  BuildContext context, {
  required YoutubeVideo video,
  VoidCallback? onOpenMessages,
}) {
  final url = 'https://www.youtube.com/watch?v=${video.id}';
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.ondemand_video_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Sao chép liên kết video'),
            subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              Navigator.pop(sheetContext);
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép liên kết video vào bộ nhớ tạm'),
                  ),
                );
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: const Text('Gửi cho bạn bè qua tin nhắn'),
            subtitle: const Text(
              'Sao chép kèm tiêu đề và mở danh sách trò chuyện',
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              final text = '🎬 ${video.title} (${video.channelTitle})\n$url';
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã chép tin nhắn video — hãy dán gửi cho bạn bè!',
                    ),
                  ),
                );
              onOpenMessages?.call();
            },
          ),
        ],
      ),
    ),
  );
}

/// The "Video" tab of Explore: a search box, category chips, and the YouTube
/// results (the popular videos while the box is empty). Tapping a video calls
/// [onPlay] (and [onPlayWithPlaylist] when provided).
class YoutubeVideosView extends StatefulWidget {
  final Future<VideoPage> Function(String query, String? cursor) search;
  final ValueChanged<YoutubeVideo> onPlay;
  final void Function(YoutubeVideo video, List<YoutubeVideo> playlist)?
  onPlayWithPlaylist;
  final VoidCallback? onOpenMessages;

  const YoutubeVideosView({
    super.key,
    required this.search,
    required this.onPlay,
    this.onPlayWithPlaylist,
    this.onOpenMessages,
  });

  @override
  State<YoutubeVideosView> createState() => _YoutubeVideosViewState();
}

class _YoutubeVideosViewState extends State<YoutubeVideosView> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _selectedCategory = 'all';
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

  String get _effectiveQuery {
    final typed = _controller.text.trim();
    if (typed.isNotEmpty) return typed;
    final cat = _kCategories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => _kCategories.first,
    );
    return cat.query;
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
      final page = await widget.search(_effectiveQuery, cursor);
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

  void _onChanged(String text) {
    if (text.trim().isNotEmpty && _selectedCategory != 'all') {
      _selectedCategory = 'all';
    }
    setState(() {});
    _debounce?.cancel();
    // 600 ms: a YouTube search costs 100 of the 10,000 free daily units.
    _debounce = Timer(const Duration(milliseconds: 600), _load);
  }

  void _selectCategory(_VideoCategory cat) {
    if (_selectedCategory == cat.id && _controller.text.isEmpty) return;
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _selectedCategory = cat.id;
    });
    _load();
  }

  void _handlePlay(YoutubeVideo video) {
    if (widget.onPlayWithPlaylist != null) {
      widget.onPlayWithPlaylist!(
        video,
        List<YoutubeVideo>.unmodifiable(_videos),
      );
    } else {
      widget.onPlay(video);
    }
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (var i = 0; i < _kCategories.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _CategoryChip(
                  label: _kCategories[i].label,
                  selected:
                      _controller.text.trim().isEmpty &&
                      _selectedCategory == _kCategories[i].id,
                  onTap: () => _selectCategory(_kCategories[i]),
                ),
              ],
            ],
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
          final video = _videos[index];
          return _VideoCard(
            video: video,
            onTap: () => _handlePlay(video),
            onShare: () => showYoutubeVideoShareSheet(
              context,
              video: video,
              onOpenMessages: widget.onOpenMessages,
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final YoutubeVideo video;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = video.durationLabel;
    final channelInitial = video.channelTitle.trim().isEmpty
        ? 'Y'
        : video.channelTitle.trim().characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
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
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: Text(
                      channelInitial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                  IconButton(
                    onPressed: onShare,
                    tooltip: 'Chia sẻ video',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.share_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
