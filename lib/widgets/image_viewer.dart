import 'dart:io';

import 'package:flutter/material.dart';

/// Shows one picture full screen, with pinch-to-zoom and a close button.
/// [source] is a web address or, for a picture still being sent, a file path.
Future<void> showImageViewer(BuildContext context, String source) =>
    showImageGallery(context, [source]);

/// Shows the pictures of a post full screen, starting at [initialIndex]:
/// swipe to change picture, pinch to zoom.
Future<void> showImageGallery(
  BuildContext context,
  List<String> sources, [
  int initialIndex = 0,
]) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _ImageGallery(sources: sources, initialIndex: initialIndex),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _picture(String source) {
    const broken = Icon(Icons.broken_image_outlined, color: Colors.white54);
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: source.startsWith('http')
            ? Image.network(
                source,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => broken,
              )
            : Image.file(
                File(source),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => broken,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: sources.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => _picture(sources[index]),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                if (sources.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '${_index + 1}/${sources.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Đóng ảnh',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
