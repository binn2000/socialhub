import 'package:flutter/widgets.dart';

/// Calls [onLoadMore] when the vertical list below is scrolled close to its
/// end. The caller decides whether there is more and avoids overlapping loads.
/// Does nothing when [onLoadMore] is null (the mock app).
class LoadMoreListener extends StatefulWidget {
  final VoidCallback? onLoadMore;
  final Widget child;

  const LoadMoreListener({super.key, this.onLoadMore, required this.child});

  @override
  State<LoadMoreListener> createState() => _LoadMoreListenerState();
}

class _LoadMoreListenerState extends State<LoadMoreListener> {
  bool _triggeredInCurrentGesture = false;

  @override
  Widget build(BuildContext context) {
    final onLoadMore = widget.onLoadMore;
    if (onLoadMore == null) return widget.child;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical ||
            notification.depth != 0) {
          return false;
        }
        if (notification is ScrollStartNotification) {
          _triggeredInCurrentGesture = false;
          return false;
        }
        final nearEnd = notification.metrics.extentAfter < 400;
        if (!nearEnd) {
          _triggeredInCurrentGesture = false;
          return false;
        }
        if (!_triggeredInCurrentGesture &&
            (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification)) {
          _triggeredInCurrentGesture = true;
          onLoadMore();
        }
        return false;
      },
      child: widget.child,
    );
  }
}
