import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/screens/notifications_screen.dart';

import 'test_helpers.dart';

final _unreadMockCount = mockNotifications.where((n) => !n.isRead).length;

/// Each notification row exposes "Chưa đọc: ..." or "Đã đọc: ..." to
/// screen readers, which is how we check its read state.
final _unreadRows = find.bySemanticsLabel(RegExp(r'^Chưa đọc:'));
final _readRows = find.bySemanticsLabel(RegExp(r'^Đã đọc:'));

Finder _badgeWithCount(int count) =>
    find.descendant(of: find.byType(Badge), matching: find.text('$count'));

Future<void> _pumpNotifications(
  WidgetTester tester,
  List<SocialNotification> notifications, {
  ValueChanged<SocialNotification>? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationsScreen(
        notifications: notifications,
        onNotificationTap: onTap ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('NotificationsScreen', () {
    testWidgets('shows every mock notification', (tester) async {
      await _pumpNotifications(tester, mockNotifications);

      for (final notification in mockNotifications) {
        expect(
          find.textContaining(notification.description, findRichText: true),
          findsOneWidget,
        );
        expect(find.text(notification.time), findsOneWidget);
      }
    });

    testWidgets('unread and read notifications are marked differently', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpNotifications(tester, mockNotifications);

      expect(_unreadRows, findsNWidgets(_unreadMockCount));
      expect(
        _readRows,
        findsNWidgets(mockNotifications.length - _unreadMockCount),
      );
      semantics.dispose();
    });

    testWidgets('tapping a row reports only that notification', (tester) async {
      final tapped = <SocialNotification>[];
      await _pumpNotifications(tester, mockNotifications, onTap: tapped.add);

      final target = mockNotifications[1];
      await tester.tap(
        find.textContaining(target.description, findRichText: true),
      );

      expect(tapped.map((n) => n.id), [target.id]);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      await _pumpNotifications(tester, const []);

      expect(find.text('Không có thông báo'), findsOneWidget);
    });
  });

  group('Notifications in the app', () {
    testWidgets('badge shows the unread count', (tester) async {
      await pumpSocialHub(tester);

      expect(_badgeWithCount(_unreadMockCount), findsOneWidget);
    });

    testWidgets('opening Notifications marks all read and hides the badge', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSocialHub(tester);

      await tapTab(tester, notificationsTab);

      expect(find.widgetWithText(AppBar, 'Thông báo'), findsOneWidget);
      expect(_unreadRows, findsNothing);
      expect(_readRows, findsNWidgets(mockNotifications.length));
      expect(find.byType(Badge), findsNothing);

      // The badge stays hidden after leaving the tab.
      await tapTab(tester, homeTab);
      expect(find.byType(Badge), findsNothing);
      semantics.dispose();
    });

    testWidgets('opening the app does not change mockNotifications', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await tapTab(tester, notificationsTab);

      expect(
        mockNotifications.where((n) => !n.isRead),
        hasLength(_unreadMockCount),
      );
    });

    testWidgets('friend request notification opens Friends', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, notificationsTab);

      await tester.tap(
        find.textContaining('đã gửi lời mời kết bạn', findRichText: true),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Bạn bè'), findsOneWidget);
    });

    testWidgets('like notification opens Home', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, notificationsTab);

      await tester.tap(
        find.textContaining('đã thích bài viết của bạn', findRichText: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('SocialHub'), findsOneWidget);
    });
  });
}
