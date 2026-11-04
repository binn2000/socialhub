import 'dart:io';

import 'package:flutter/material.dart';

/// Shows one picture full screen, with pinch-to-zoom, double-tap zoom,
/// swipe-down dismiss, and a frosted glass close button.
/// [source] is a web address or, for a picture still being sent, a file path.
Future<void> showImageViewer(BuildContext context, String source) =>
    showImageGallery(context, [source]);

/// Shows the pictures of a post full screen, starting at [initialIndex]:
/// - Swipe horizontally to change picture
/// - Pinch-to-zoom (up to 5x)
/// - Double-tap to quickly zoom in/out (2.5x)
/// - Swipe down to dismiss
/// - Single tap to toggle UI controls
/// - Bottom thumbnail strip to jump directly to any photo
Future<void> showImageGallery(
  BuildContext context,
  List<String> sources, [
  int initialIndex = 0,
]) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: _ImageGallery(sources: sources, initialIndex: initialIndex),
      ),
    ),
  );
}

class _ImageGallery extends StatefulWidget {
  final List<String> sources;
  final int initialIndex;

  const _ImageGallery({required this.sources, required this.initialIndex});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  bool _showControls = true;
  bool _isZoomed = false;
  double _dragOffset = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    final delta = details.primaryDelta ?? 0;
    if (_dragOffset > 0 || delta > 0) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, 450.0);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 100 || velocity > 750) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  double get _bgOpacity => (1.0 - (_dragOffset / 350.0)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _bgOpacity),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Image Viewer with swipe-down drag offset
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _controller,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: sources.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _ZoomablePicture(
                  source: sources[index],
                  onTap: _toggleControls,
                  onZoomChanged: (zoomed) => setState(() => _isZoomed = zoomed),
                ),
              ),
            ),

            // Top Header: Frosted Glass Close Button & Pill Badge Counter
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _TopBar(
                    currentIndex: _index,
                    totalCount: sources.length,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            // Bottom Thumbnails Bar (when multiple photos exist)
            if (sources.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _ThumbnailsBar(
                      sources: sources,
                      currentIndex: _index,
                      onSelect: (selectedIdx) {
                        _controller.animateToPage(
                          selectedIdx,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
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

class _ZoomablePicture extends StatefulWidget {
  final String source;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePicture({
    required this.source,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomablePicture> createState() => _ZoomablePictureState();
}

class _ZoomablePictureState extends State<_ZoomablePicture>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransform);
  }

  void _handleTransform() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > 1.05);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransform);
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;

    final targetMatrix = isZoomed
        ? Matrix4.identity()
        : _calculateZoomMatrix(_doubleTapDetails?.localPosition ?? Offset.zero);

    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animation!.addListener(() {
      _transformationController.value = _animation!.value;
    });

    _animController.forward(from: 0);
  }

  Matrix4 _calculateZoomMatrix(Offset position) {
    const zoomScale = 2.5;
    final x = -position.dx * (zoomScale - 1);
    final y = -position.dy * (zoomScale - 1);
    final zoomed = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(zoomScale, zoomScale, zoomScale, 1);
    return zoomed;
  }

  @override
  Widget build(BuildContext context) {
    const broken = Icon(
      Icons.broken_image_outlined,
      color: Colors.white54,
      size: 44,
    );

    final imageWidget = widget.source.startsWith('http')
        ? Image.network(
            widget.source,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white38,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => broken,
          )
        : Image.file(
            File(widget.source),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => broken,
          );

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(child: imageWidget),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;

  const _TopBar({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Frosted glass circular Close button
          Tooltip(
            message: 'Đóng ảnh',
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // Pill Badge Counter
          if (totalCount > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                '${currentIndex + 1} / $totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          // Sized box to balance symmetry on right side
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _ThumbnailsBar extends StatelessWidget {
  final List<String> sources;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _ThumbnailsBar({
    required this.sources,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 24,
        left: 16,
        right: 16,
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(sources.length, (i) {
              final isSelected = i == currentIndex;
              final src = sources[i];

              final thumbWidget = src.startsWith('http')
                  ? Image.network(
                      src,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Colors.white12),
                    )
                  : Image.file(
                      File(src),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Colors.white12),
                    );

              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 48 : 40,
                  height: isSelected ? 48 : 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white30,
                      width: isSelected ? 2.2 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.55,
                      child: thumbWidget,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
