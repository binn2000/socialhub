import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/screens/chat_screen.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/screens/friends_screen.dart';
import 'package:flutter_learning/screens/home_screen.dart';
import 'package:flutter_learning/screens/messages_screen.dart';
import 'package:flutter_learning/screens/notifications_screen.dart';
import 'package:flutter_learning/screens/profile_screen.dart';
import 'package:flutter_learning/screens/create_post_screen.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('SocialHub app starts on Home with bottom navigation', (
    tester,
  ) async {
    await pumpSocialHub(tester);

    expect(find.text('SocialHub'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SocialBottomNav), findsOneWidget);
  });

  testWidgets('Home tap targets are announced as labelled buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpSocialHub(tester);

    for (final label in [
      'Tạo bài viết mới',
      'Thêm tin mới',
      'Xem tin của ${mockStories[1].user.name}',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    expect(
      tester.getSemantics(find.byTooltip('Tin nhắn')),
      isSemantics(tooltip: 'Tin nhắn', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  group('Home post interactions', () {
    // The first post in the feed: liked, 254 likes, 38 comments, 12 shares.
    final firstPost = mockPosts.first;
    final likes = '${firstPost.likes}';
    final comments = '${firstPost.comments}';
    final shares = '${firstPost.shares}';

    // The action row sits below the fold on the 800x600 test screen.
    Future<void> scrollToFirstPostActions(WidgetTester tester) async {
      await tester.ensureVisible(find.text(likes));
      await tester.pumpAndSettle();
    }

    testWidgets('like button toggles the like state and count', (tester) async {
      await pumpSocialHub(tester);
      expect(firstPost.isLiked, isTrue);
      await scrollToFirstPostActions(tester);

      await tester.tap(find.text(likes));
      await tester.pumpAndSettle();
      expect(find.text('${firstPost.likes - 1}'), findsOneWidget);
      expect(find.byTooltip('Thích bài viết'), findsWidgets);

      await tester.tap(find.text('${firstPost.likes - 1}'));
      await tester.pumpAndSettle();
      expect(find.text(likes), findsOneWidget);
    });

    testWidgets('comment sheet opens and sends without crashing', (
      tester,
    ) async {
      await pumpSocialHub(tester);

      await scrollToFirstPostActions(tester);
      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      expect(find.text('$comments bình luận'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hay quá');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Bình luận đã được thêm trong phiên này'),
        findsOneWidget,
      );
      // Comments are a mock interaction: the count does not change.
      expect(find.text(comments), findsOneWidget);
    });

    testWidgets('share sheet opens and copies link without crashing', (
      tester,
    ) async {
      await pumpSocialHub(tester);

      await scrollToFirstPostActions(tester);
      await tester.tap(find.byTooltip('Chia sẻ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Đã chuẩn bị liên kết bài viết của ${firstPost.author.name}'),
        findsOneWidget,
      );
      // Shares are a mock interaction: the count does not change.
      expect(find.text(shares), findsOneWidget);
    });

    testWidgets('actions are compact icons with counts', (tester) async {
      await pumpSocialHub(tester);

      final firstPostCard = find
          .ancestor(
            of: find.text(firstPost.content),
            matching: find.byType(Column),
          )
          .first;
      Finder inFirstPost(Finder finder) =>
          find.descendant(of: firstPostCard, matching: finder);

      expect(inFirstPost(find.byIcon(Icons.favorite_rounded)), findsOneWidget);
      expect(
        inFirstPost(find.byIcon(Icons.chat_bubble_outline_rounded)),
        findsOneWidget,
      );
      expect(inFirstPost(find.byIcon(Icons.share_outlined)), findsOneWidget);
      expect(inFirstPost(find.text(likes)), findsOneWidget);
      expect(inFirstPost(find.text(comments)), findsOneWidget);
      expect(inFirstPost(find.text(shares)), findsOneWidget);
    });
  });

  group('Dark mode smoke tests', () {
    Future<void> switchToDarkMode(WidgetTester tester) async {
      await pumpSocialHub(tester);
      await tester.tap(find.byTooltip('Chế độ tối'));
      await tester.pumpAndSettle();
    }

    void expectDarkScreen(WidgetTester tester, Type screenType) {
      final screen = find.byType(screenType);
      expect(screen, findsOneWidget);
      expect(Theme.of(tester.element(screen)).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    }

    testWidgets('main tabs render in dark mode', (tester) async {
      await switchToDarkMode(tester);
      expectDarkScreen(tester, HomeScreen);
      expect(find.byTooltip('Chế độ sáng'), findsOneWidget);

      await tapTab(tester, exploreTab);
      expectDarkScreen(tester, ExploreScreen);

      await tapTab(tester, friendsTab);
      expectDarkScreen(tester, FriendsScreen);

      await tapTab(tester, notificationsTab);
      expectDarkScreen(tester, NotificationsScreen);

      await tapTab(tester, profileTab);
      expectDarkScreen(tester, ProfileScreen);
    });

    testWidgets('Create Post with an image renders in dark mode', (
      tester,
    ) async {
      await switchToDarkMode(tester);
      await tapTab(tester, createTab);

      await tester.enterText(find.byType(TextField), 'Dark mode');
      await tester.tap(find.text('Chọn ảnh mock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành phố xanh'));
      await tester.pumpAndSettle();

      expectDarkScreen(tester, CreatePostScreen);
    });

    testWidgets('Messages and Chat render in dark mode', (tester) async {
      await switchToDarkMode(tester);

      await openMessagesFromHome(tester);
      expectDarkScreen(tester, MessagesScreen);

      await tester.tap(find.text('Minh Ánh'));
      await tester.pumpAndSettle();
      expectDarkScreen(tester, ChatScreen);
    });

    testWidgets('theme can be switched back to light', (tester) async {
      await switchToDarkMode(tester);

      await tester.tap(find.byTooltip('Chế độ sáng'));
      await tester.pumpAndSettle();

      final home = tester.element(find.byType(HomeScreen));
      expect(Theme.of(home).brightness, Brightness.light);
    });
  });
}
