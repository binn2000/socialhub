import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_learning/widgets/image_viewer.dart';
import 'package:flutter_learning/widgets/post_video_view.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

class MockImageChoice {
  final String id;
  final String label;
  final String assetPath;

  const MockImageChoice({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

const mockImageChoices = [
  MockImageChoice(
    id: 'mock_image_1',
    label: 'Sắc tím sáng tạo',
    assetPath: 'assets/placeholder.png',
  ),
  MockImageChoice(
    id: 'mock_image_2',
    label: 'Hoàng hôn ấm áp',
    assetPath: 'assets/placeholder.png',
  ),
  MockImageChoice(
    id: 'mock_image_3',
    label: 'Thành phố xanh',
    assetPath: 'assets/placeholder.png',
  ),
];

/// Whether [path] points at a real bundled image that is worth loading.
///
/// The mock data points every image at `assets/placeholder.png`, a 1x1 pixel
/// file, so that path (and anything outside `assets/`) shows the calm
/// fallback instead.
bool canLoadAssetImage(String? path) {
  return path != null &&
      path.startsWith('assets/') &&
      path != 'assets/placeholder.png';
}

/// Whether [url] is a photo served by the backend (as opposed to a bundled asset).
bool isNetworkImage(String? url) =>
    url != null && (url.startsWith('http://') || url.startsWith('https://'));

/// Whether [path] is a photo picked on this device: a file path, as opposed
/// to a bundled asset or a URL from the server.
bool isLocalPhoto(String? path) =>
    path != null &&
    path.isNotEmpty &&
    !path.startsWith('assets/') &&
    !isNetworkImage(path);

/// Returns a [background, foreground] pair of calm, flat tones for a mock image.
List<Color> mockImageColors(String? imageId) {
  switch (imageId) {
    case 'mock_image_1':
      return mutedMediaTones[0];
    case 'mock_image_2':
      return mutedMediaTones[1];
    case 'mock_image_3':
      return mutedMediaTones[2];
    default:
      return mutedMediaTones[0];
  }
}

class MockImagePreview extends StatelessWidget {
  final MockImageChoice image;
  final double size;

  const MockImagePreview({super.key, required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final canLoadAsset = canLoadAssetImage(image.assetPath);
    final fallback = _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size == double.infinity ? double.infinity : size,
        height: size == double.infinity ? 220 : size,
        child: canLoadAsset
            ? Image.asset(
                image.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _fallback() {
    final tones = mockImageColors(image.id);
    return Container(
      color: tones.first,
      child: Center(
        child: Icon(Icons.auto_awesome_rounded, color: tones.last, size: 38),
      ),
    );
  }
}

class PostMedia extends StatelessWidget {
  final Post post;

  /// Whether a tap opens the media: a server video plays, a server picture
  /// opens full screen ([PostVideoView], [showImageGallery]).
  final bool playable;

  const PostMedia({super.key, required this.post, this.playable = true});

  @override
  Widget build(BuildContext context) {
    final video = post.video;
    if (video != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: PostVideoView(video: video, playable: playable),
      );
    }
    final images = post.allImages;
    final fallback = _fallback(post);

    if (images.length > 1) {
      return _MultiImageCarousel(
        post: post,
        images: images,
        fallback: fallback,
        openable: playable,
      );
    }

    final imageUrl = post.imageUrl;
    final canLoadAsset = canLoadAssetImage(imageUrl);
    final isVideo = post.isVideo || (imageUrl?.endsWith('.mp4') ?? false);

    // A real picture is shown whole (portrait ones too) and opens full screen.
    final media = isLocalPhoto(imageUrl) || isNetworkImage(imageUrl)
        ? _WholePicture(
            url: imageUrl!,
            fallback: fallback,
            onTap: playable
                ? () => showImageGallery(context, [imageUrl])
                : null,
          )
        : _buildSingleImage(imageUrl, fallback, canLoadAsset);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: isVideo
          ? Stack(
              alignment: Alignment.center,
              children: [
                media,
                Container(
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
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      post.videoDuration ?? '0:45',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : media,
    );
  }

  static Widget _buildSingleImage(
    String? imageUrl,
    Widget fallback,
    bool canLoadAsset,
  ) {
    return isLocalPhoto(imageUrl)
        ? Image.file(
            File(imageUrl!),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : isNetworkImage(imageUrl)
        ? Image.network(
            imageUrl!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : canLoadAsset
        ? Image.asset(
            imageUrl!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : fallback;
  }

  Widget _fallback(Post post) {
    final tones = post.imageId == null
        ? _legacyColors(post.id)
        : mockImageColors(post.imageId);
    return Container(
      width: double.infinity,
      height: 220,
      color: tones.first,
      child: Center(
        child: Icon(Icons.auto_awesome_rounded, color: tones.last, size: 46),
      ),
    );
  }

  List<Color> _legacyColors(String key) {
    final index = key.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return mutedMediaTones[index % mutedMediaTones.length];
  }
}

/// Carousel view for posts with multiple images.
class _MultiImageCarousel extends StatefulWidget {
  final Post post;
  final List<String> images;
  final Widget fallback;
  final bool openable;

  const _MultiImageCarousel({
    required this.post,
    required this.images,
    required this.fallback,
    required this.openable,
  });

  @override
  State<_MultiImageCarousel> createState() => _MultiImageCarouselState();
}

class _MultiImageCarouselState extends State<_MultiImageCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: 360,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final url = images[index];
                final real = isLocalPhoto(url) || isNetworkImage(url);
                return real
                    ? _WholePicture(
                        url: url,
                        fallback: widget.fallback,
                        fillHeight: true,
                        onTap: widget.openable
                            ? () => showImageGallery(context, images, index)
                            : null,
                      )
                    : PostMedia._buildSingleImage(
                        url,
                        widget.fallback,
                        canLoadAssetImage(url),
                      );
              },
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${_currentIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(images.length, (index) {
                final isSelected = index == _currentIndex;
                return AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// A picture shown whole: the full width when it is wide, the full height
/// (up to [maxHeight]) when it is tall, never cropped. [fillHeight] is for a
/// page of the carousel, which has a fixed height.
class _WholePicture extends StatelessWidget {
  final String url;
  final Widget fallback;
  final VoidCallback? onTap;
  final bool fillHeight;

  static const double maxHeight = 520;

  const _WholePicture({
    required this.url,
    required this.fallback,
    this.onTap,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = isLocalPhoto(url)
        ? Image.file(
            File(url),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    final box = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: fillHeight
          ? SizedBox.expand(child: image)
          : ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 160,
                maxHeight: maxHeight,
              ),
              child: SizedBox(width: double.infinity, child: image),
            ),
    );
    return onTap == null
        ? box
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: box,
          );
  }
}
