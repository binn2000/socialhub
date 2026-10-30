import 'package:flutter/widgets.dart';

/// Calls [onLoadMore] when the vertical list below is scrolled close to its
/// end. The caller decides whether there is more and avoids overlapping loads.
/// Does nothing when [onLoadMore] is null (the mock app).
class LoadMoreListener extends StatelessWidget {
  final VoidCallback? onLoadMore;
  final Widget child;

  const LoadMoreListener({super.key, this.onLoadMore, required this.child});

  @override
  Widget build(BuildContext context) {
    final onLoadMore = this.onLoadMore;
    if (onLoadMore == null) return child;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final nearEnd =
            notification.metrics.axis == Axis.vertical &&
            notification.depth == 0 &&
            notification.metrics.extentAfter < 400;
        if (nearEnd &&
            (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification)) {
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}
