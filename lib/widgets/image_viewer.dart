import 'dart:io';

import 'package:flutter/material.dart';

/// Shows one picture full screen, with pinch-to-zoom and a close button.
/// [source] is a web address or, for a picture still being sent, a file path.
Future<void> showImageViewer(BuildContext context, String source) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ImageViewer(source: source),
    ),
  );
}

class _ImageViewer extends StatelessWidget {
  final String source;

  const _ImageViewer({required this.source});

  @override
  Widget build(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined, color: Colors.white54);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
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
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Đóng ảnh',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
