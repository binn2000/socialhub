import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/screens/home_screen.dart';

import 'test_helpers.dart';

// Home feed order: post_1 (Minh Ánh), post_2, post_3, post_4 (current user).
Post _post(String id) => mockPosts.firstWhere((post) => post.id == id);

/// Checks a post is (or is not) in the Home feed, scrolling if needed.
Future<void> _expectInHomeFeed(WidgetTester tester, Post post) async {
  await tester.scrollUntilVisible(
    find.text(post.content),
    300,
    scrollable: visibleVerticalScrollable,
  );
}

List<Post> _homePosts(WidgetTester tester) => tester
    .widget<HomeScreen>(find.byType(HomeScreen, skipOffstage: false))
    .posts;

final _savedIcon = find.byIcon(Icons.bookmark_rounded);

void main() {
  final first = _post('post_1');
  final second = _post('post_2');

  group('Save', () {
    testWidgets('posts start unsaved', (tester) async {
      await pumpSocialHub(tester);
      expect(_savedIcon, findsNothing);

      await openPostMenu(tester, first);

      expect(find.text('Lưu bài viết'), findsOneWidget);
      expect(find.text('Bỏ lưu bài viết'), findsNothing);
    });

    testWidgets('saving marks the post as saved', (tester) async {
      await pumpSocialHub(tester);

      await savePostFromMenu(tester, first);

      expect(
        find.text('Đã lưu bài viết của ${first.author.name} trong phiên này'),
        findsOneWidget,
      );
      expect(_savedIcon, findsOneWidget);
      expect(find.byTooltip('Tùy chọn bài viết (đã lưu)'), findsOneWidget);

      await openPostMenu(tester, first);
      expect(find.text('Bỏ lưu bài viết'), findsOneWidget);
    });

    testWidgets('saving again removes the saved state', (tester) async {
      await pumpSocialHub(tester);
      await savePostFromMenu(tester, first);

      await openPostMenu(tester, first);
      await tapMenuItem(tester, 'Bỏ lưu bài viết');

      expect(
        find.text('Đã bỏ lưu bài viết của ${first.author.name}'),
        findsOneWidget,
      );
      expect(_savedIcon, findsNothing);
      await openPostMenu(tester, first);
      expect(find.text('Lưu bài viết'), findsOneWidget);
    });

    testWidgets('saved state survives switching tabs', (tester) async {
      await pumpSocialHub(tester);
      await savePostFromMenu(tester, first);

      await tapTab(tester, exploreTab);
      await tapTab(tester, profileTab);
      await tapTab(tester, homeTab);

      expect(_savedIcon, findsOneWidget);
      await openPostMenu(tester, first);
      expect(find.text('Bỏ lưu bài viết'), findsOneWidget);
    });

    testWidgets('saving one post does not save another', (tester) async {
      await pumpSocialHub(tester);
      await savePostFromMenu(tester, first);

      await openPostMenu(tester, second);

      expect(find.text('Lưu bài viết'), findsOneWidget);
      expect(find.text('Bỏ lưu bài viết'), findsNothing);
    });

    testWidgets('saving does not change the post data', (tester) async {
      await pumpSocialHub(tester);
      final before = _homePosts(tester).first;

      await savePostFromMenu(tester, first);

      expect(_homePosts(tester).first, same(before));
    });
  });

  group('Hide', () {
    testWidgets('hiding removes the post from Home right away', (tester) async {
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, first);

      expect(find.text(first.content), findsNothing);
      expect(
        find.text('Đã ẩn bài viết của ${first.author.name} khỏi bảng tin'),
        findsOneWidget,
      );
      expect(find.text('Hoàn tác'), findsOneWidget);
    });

    testWidgets('other posts stay in Home', (tester) async {
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, first);

      for (final post in mockPosts.skip(1)) {
        await _expectInHomeFeed(tester, post);
      }
      expect(_homePosts(tester).map((post) => post.id), [
        'post_2',
        'post_3',
        'post_4',
      ]);
    });

    testWidgets('hiding one post does not hide another', (tester) async {
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, second);

      expect(find.text(second.content), findsNothing);
      expect(_homePosts(tester).map((post) => post.id), [
        'post_1',
        'post_3',
        'post_4',
      ]);
      // post_1 is above the second post, so scroll back up to it.
      await tester.scrollUntilVisible(
        find.text(first.content),
        -300,
        scrollable: visibleVerticalScrollable,
      );
    });

    testWidgets('hidden post stays in the shared post list', (tester) async {
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, first);

      // Explore still receives every post and shows the hidden one.
      final explorePosts = tester
          .widget<ExploreScreen>(
            find.byType(ExploreScreen, skipOffstage: false),
          )
          .posts;
      expect(explorePosts.map((post) => post.id), contains(first.id));
      await tapTab(tester, exploreTab);
      expect(find.text(first.content), findsOneWidget);
    });

    testWidgets('hiding your own post keeps it on Profile', (tester) async {
      final ownPost = _post('post_4');
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, ownPost);
      await tapTab(tester, profileTab);

      await tester.scrollUntilVisible(
        find.text(ownPost.content),
        300,
        scrollable: visibleVerticalScrollable,
      );
    });

    testWidgets('hiding does not change mockPosts', (tester) async {
      final idsBefore = mockPosts.map((post) => post.id).toList();
      await pumpSocialHub(tester);

      await hidePostFromMenu(tester, first);
      await hidePostFromMenu(tester, second);

      expect(mockPosts.map((post) => post.id), idsBefore);
    });

    testWidgets('Undo brings the post back in its place', (tester) async {
      await pumpSocialHub(tester);
      await hidePostFromMenu(tester, first);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      expect(find.text(first.content), findsOneWidget);
      expect(_homePosts(tester).first.id, first.id);
    });

    testWidgets('hide confirmation closes by itself', (tester) async {
      await pumpSocialHub(tester);
      await hidePostFromMenu(tester, first);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Hoàn tác'), findsNothing);
      expect(find.text(first.content), findsNothing);
    });
  });

  group('Accessibility', () {
    testWidgets('save action has a label and a toggled state', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSocialHub(tester);
      final name = first.author.name;

      await openPostMenu(tester, first);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lưu bài viết của $name')),
        matchesSemantics(
          label: 'Lưu bài viết của $name',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      await tapMenuItem(tester, 'Lưu bài viết');
      await openPostMenu(tester, first);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bỏ lưu bài viết của $name')),
        matchesSemantics(
          label: 'Bỏ lưu bài viết của $name',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      await closePostMenu(tester);
      semantics.dispose();
    });

    testWidgets('hide action has a meaningful label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSocialHub(tester);
      final label = 'Ẩn bài viết của ${first.author.name} khỏi bảng tin';

      await openPostMenu(tester, first);

      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  });

  testWidgets('menu and confirmations work in dark mode', (tester) async {
    await pumpSocialHub(tester);
    await tester.tap(find.byTooltip('Chế độ tối'));
    await tester.pumpAndSettle();

    await openPostMenu(tester, first);
    final sheetContext = tester.element(find.text('Lưu bài viết'));
    expect(Theme.of(sheetContext).brightness, Brightness.dark);
    await tapMenuItem(tester, 'Lưu bài viết');
    await hidePostFromMenu(tester, first);

    expect(tester.takeException(), isNull);
    expect(find.text(first.content), findsNothing);
  });
}
