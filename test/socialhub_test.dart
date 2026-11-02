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
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';
import 'package:flutter_learning/widgets/mock_image.dart';

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

  group('Modern Premium additions (4.2 - 4.7)', () {
    testWidgets('Home feed filter tabs filter posts by category', (
      tester,
    ) async {
      await pumpSocialHub(tester);

      expect(find.text('Dành cho bạn'), findsOneWidget);
      expect(find.text('Đang theo dõi'), findsOneWidget);
      expect(find.text('Đa phương tiện'), findsOneWidget);

      await tester.tap(find.text('Đa phương tiện'));
      await tester.pumpAndSettle();
      expect(find.text(mockPosts.first.content), findsOneWidget);
    });

    testWidgets('Video PostMedia renders play button and duration badge', (
      tester,
    ) async {
      final videoPost = Post(
        id: 'video_1',
        author: currentUser,
        content: 'Video demo',
        imageUrl: 'assets/placeholder.png',
        createdAt: 'Vừa xong',
        likes: 10,
        comments: 2,
        shares: 1,
        isLiked: false,
        isVideo: true,
        videoDuration: '1:24',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostMedia(post: videoPost)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('1:24'), findsOneWidget);
    });

    testWidgets(
      'Profile tabs switch between Bài viết, Giới thiệu, Ảnh, Bạn bè',
      (tester) async {
        await pumpSocialHub(tester);
        await tapTab(tester, profileTab);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Giới thiệu'));
        await tester.pumpAndSettle();
        expect(find.text('Thông tin cá nhân'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Ảnh'));
        await tester.pumpAndSettle();
        expect(find.byType(PostMedia), findsWidgets);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Bạn bè'));
        await tester.pumpAndSettle();
        expect(find.text('Minh Ánh'), findsOneWidget);
      },
    );

    testWidgets('Friends category filter separates friends and suggestions', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await tapTab(tester, friendsTab);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Người bạn có thể biết'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bảo Trâm'), findsOneWidget);
      expect(find.text('Minh Ánh'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Danh sách bạn bè'));
      await tester.pumpAndSettle();
      expect(find.text('Minh Ánh'), findsOneWidget);
      expect(find.text('Bảo Trâm'), findsNothing);
    });

    testWidgets('Desktop Messenger renders 2-column sidebar + chat view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpSocialHub(tester);
      await openMessagesFromHome(tester);

      // Both the conversation list and the embedded ChatScreen are on screen.
      expect(find.byType(MessagesScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('Notifications filter chips filter by type', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, notificationsTab);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Kết bạn'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('đã gửi lời mời kết bạn', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('đã thích bài viết của bạn', findRichText: true),
        findsNothing,
      );
    });
  });
}
