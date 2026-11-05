import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/widgets/privacy_sheet.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  /// Called once for each story the viewer shows (the first one and every
  /// story it moves to).
  final ValueChanged<Story>? onViewed;

  /// Deleting is offered for stories written by [currentUserId]; it closes
  /// the viewer. Both are null on the mock app.
  final String? currentUserId;
  final ValueChanged<Story>? onDelete;

  /// Changes who can see one of my stories (server only).
  final void Function(Story story, String privacy)? onChangePrivacy;

  /// Reaction callback when quick emoji reaction is tapped.
  final void Function(Story story, String emoji)? onReact;

  /// Plays the song of the story on show. Stories without a song are silent.
  final AudioPreview audio;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    this.onViewed,
    this.currentUserId,
    this.onDelete,
    this.onChangePrivacy,
    this.onReact,
    this.audio = const NoAudioPreview(),
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pageController;
  late final List<Story> _stories;
  late int _currentIndex;
  Timer? _autoAdvanceTimer;
  bool _muted = false;

  String? _floatingEmoji;
  Timer? _floatingTimer;

  static const _quickEmojis = ['❤️', '🔥', '😂', '😮', '😢', '👏', '😍'];

  void _reactWithEmoji(Story story, String emoji) {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _floatingEmoji = emoji;
    });
    _floatingTimer?.cancel();
    _floatingTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _floatingEmoji = null);
    });

    widget.onReact?.call(story, emoji);

    _startAutoAdvance();
  }

  /// Plays the song of the story on show, or silences the last one.
  void _syncAudio() {
    final track = _stories.isEmpty ? null : _stories[_currentIndex].track;
    if (track == null || _muted) {
      widget.audio.stop();
    } else {
      playPreview(context, widget.audio, track.previewUrl, loop: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _stories = List.of(widget.stories);
    if (_stories.isEmpty) {
      _currentIndex = 0;
      _pageController = PageController();
      return;
    }
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    // After the first frame: the callback may call setState on a screen
    // behind this one, which is not allowed while this one is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onViewed?.call(_stories[_currentIndex]);
      _syncAudio();
    });
    _startAutoAdvance();
  }

  @override
  void dispose() {
    widget.audio.stop();
    _autoAdvanceTimer?.cancel();
    _floatingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final nextIndex = _currentIndex + 1;
      if (nextIndex < _stories.length) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _changePrivacy(Story story) async {
    // The next story must not slide in behind the sheet.
    _autoAdvanceTimer?.cancel();
    final label = await showPrivacySheet(context, current: story.privacy);
    if (!mounted) return;
    if (label != null) {
      widget.onChangePrivacy!(story, label);
      final index = _stories.indexWhere((s) => s.id == story.id);
      if (index != -1) {
        setState(() => _stories[index] = story.copyWith(privacy: label));
      }
    }
    _startAutoAdvance();
  }

  Future<void> _confirmDelete(Story story) async {
    // The next story must not slide in behind the dialog.
    _autoAdvanceTimer?.cancel();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tin này?'),
        content: const Text('Tin sẽ bị xóa khỏi tài khoản của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _startAutoAdvance();
      return;
    }
    widget.onDelete!(story);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  color: Colors.white70,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có tin nào',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _stories.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                widget.onViewed?.call(_stories[index]);
                _syncAudio();
                _startAutoAdvance();
              },
              itemBuilder: (context, index) {
                final story = _stories[index];
                final hasImage =
                    story.imageUrl != null && story.imageUrl!.isNotEmpty;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: _StoryMedia(story: story, hasImage: hasImage),
                    ),
                    Positioned(
                      top: 24,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: List.generate(
                          _stories.length,
                          (progressIndex) => Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: progressIndex <= _currentIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 44,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          UserAvatar(
                            imageUrl: story.user.avatarUrl,
                            radius: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  story.user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  story.user.id == widget.currentUserId &&
                                          widget.onChangePrivacy != null
                                      ? '${story.time} · ${story.privacy}'
                                      : story.time,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onChangePrivacy != null &&
                              story.user.id == widget.currentUserId)
                            IconButton(
                              onPressed: () => _changePrivacy(story),
                              tooltip: 'Đổi quyền riêng tư của tin',
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          if (story.track != null)
                            IconButton(
                              onPressed: () {
                                setState(() => _muted = !_muted);
                                _syncAudio();
                              },
                              tooltip: _muted ? 'Bật nhạc' : 'Tắt nhạc',
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                              ),
                            ),
                          if (widget.onDelete != null &&
                              story.user.id == widget.currentUserId)
                            IconButton(
                              onPressed: () => _confirmDelete(story),
                              tooltip: 'Xóa tin',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Đóng tin',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_floatingEmoji != null)
                      Center(
                        child: Text(
                          _floatingEmoji!,
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom:
                          (widget.onReact != null &&
                              story.user.id != widget.currentUserId)
                          ? 78
                          : 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (story.user.bio.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                story.user.bio,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  story.user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.text ??
                                'Cùng nhìn lại khoảnh khắc đẹp trong ngày hôm nay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                            ),
                          ),
                          if (story.track != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${story.track!.title} · ${story.track!.artist}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.onReact != null &&
                        story.user.id != widget.currentUserId)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              for (final emoji in _quickEmojis)
                                InkWell(
                                  onTap: () => _reactWithEmoji(story, emoji),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMedia extends StatelessWidget {
  final Story story;
  final bool hasImage;

  const _StoryMedia({required this.story, required this.hasImage});

  @override
  Widget build(BuildContext context) {
    final canLoadAsset = canLoadAssetImage(story.imageUrl);
    final fallback = Container(
      color: Colors.black.withValues(alpha: hasImage ? 0.08 : 0.18),
      child: Center(
        child: Icon(
          hasImage ? Icons.auto_awesome_rounded : Icons.camera_alt_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: story.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: isLocalPhoto(story.imageUrl)
          ? Image.file(
              File(story.imageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : isNetworkImage(story.imageUrl)
          ? Image.network(
              story.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : canLoadAsset
          ? Image.asset(
              story.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : fallback,
    );
  }
}
