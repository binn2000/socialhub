import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  /// Called once for each story the viewer shows (the first one and every
  /// story it moves to).
  final ValueChanged<Story>? onViewed;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    this.onViewed,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pageController;
  late final List<Story> _stories;
  late int _currentIndex;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _stories = widget.stories;
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
      if (mounted) widget.onViewed?.call(_stories[_currentIndex]);
    });
    _startAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
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
                                  'Just now',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 32,
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
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.favorite_border_rounded,
                                  color: Colors.white,
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
                        ],
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
