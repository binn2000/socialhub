import 'package:flutter/material.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/load_more_listener.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Filter pills on the Notifications screen (4.7).
enum NotificationFilter {
  all('Tất cả'),
  interactions('Tương tác'),
  friends('Kết bạn');

  final String label;
  const NotificationFilter(this.label);
}

class NotificationsScreen extends StatefulWidget {
  final List<SocialNotification> notifications;
  final ValueChanged<SocialNotification> onNotificationTap;

  /// Pull-to-refresh. When null (the mock app) the list does not refresh.
  final Future<void> Function()? onRefresh;

  /// Loads the next page when the list is scrolled near its end.
  final VoidCallback? onLoadMore;

  /// Explicitly marks all notifications as read.
  final VoidCallback? onMarkAllRead;

  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.onNotificationTap,
    this.onRefresh,
    this.onLoadMore,
    this.onMarkAllRead,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _filter = NotificationFilter.all;

  List<SocialNotification> get _visibleNotifications {
    switch (_filter) {
      case NotificationFilter.all:
        return widget.notifications;
      case NotificationFilter.interactions:
        return widget.notifications
            .where(
              (n) =>
                  n.type == 'like' || n.type == 'comment' || n.type == 'share',
            )
            .toList();
      case NotificationFilter.friends:
        return widget.notifications.where((n) => n.type == 'friend').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final visible = _visibleNotifications;
    final hasUnread = widget.notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: hasUnread ? (widget.onMarkAllRead ?? () {}) : null,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.notifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in NotificationFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(filter.label),
                            selected: _filter == filter,
                            showCheckmark: false,
                            selectedColor: palette.brand,
                            backgroundColor: palette.surface,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _filter == filter
                                  ? Colors.white
                                  : palette.textSecondary,
                            ),
                            side: BorderSide(
                              color: _filter == filter
                                  ? palette.brand
                                  : palette.border,
                            ),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _refreshable(
                visible.isEmpty
                    ? _empty(colorScheme)
                    : ListView.separated(
                        physics: widget.onRefresh == null
                            ? null
                            : const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = visible[index];
                          return Semantics(
                            button: true,
                            label:
                                '${notification.isRead ? 'Đã đọc' : 'Chưa đọc'}: ${notification.actor.name} ${notification.description}, ${notification.time}',
                            child: InkWell(
                              onTap: () =>
                                  widget.onNotificationTap(notification),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: HoverableCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                color: notification.isRead
                                    ? palette.surface
                                    : palette.brandSoft,
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      imageUrl: notification.actor.avatarUrl,
                                      radius: 26,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              text: notification.actor.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      ' ${notification.description}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (notification.relatedContent !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              notification.relatedContent!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.time,
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: notification.iconColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        notification.icon,
                                        color: notification.iconColor,
                                      ),
                                    ),
                                    if (!notification.isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme colorScheme) {
    final message = Center(
      child: Text(
        'Không có thông báo',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
    // A list that fills the screen, so pulling down still reaches the
    // refresh indicator when there is nothing to show.
    return widget.onRefresh == null
        ? message
        : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(hasScrollBody: false, child: message),
            ],
          );
  }

  Widget _refreshable(Widget child) {
    final refresh = widget.onRefresh;
    return LoadMoreListener(
      onLoadMore: widget.onLoadMore,
      child: refresh == null
          ? child
          : RefreshIndicator(onRefresh: refresh, child: child),
    );
  }
}
