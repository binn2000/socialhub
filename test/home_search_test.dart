import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/screens/home_screen.dart';

import 'test_helpers.dart';

// Mock posts in feed order:
//   post_1 Minh Ánh    "Ngày đẹp trời ... cà phê ..."
//   post_2 Duy Khang   "Mình vừa hoàn thành một prototype ..."
//   post_3 Quang Huy   "... #citylight #weekend"
//   post_4 Lê Anh Hùng "Mình đã hoàn thành một dự án thiết kế branding ..."
Post _post(String id) => mockPosts.firstWhere((post) => post.id == id);
final _minh = _post('post_1');
final _duy = _post('post_2');
final _quang = _post('post_3');
final _own = _post('post_4');

const _noResults = 'Không tìm thấy bài viết';
const _noPosts = 'Chưa có bài viết';

/// A tall screen so every Home post is built without scrolling.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSocialHub(tester);
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tìm kiếm bài viết'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await _openSearch(tester);
  await _type(tester, query);
}

void _expectShown(Iterable<Post> posts) {
  for (final post in posts) {
    expect(find.text(post.content), findsOneWidget, reason: post.id);
  }
}

void _expectHidden(Iterable<Post> posts) {
  for (final post in posts) {
    expect(find.text(post.content), findsNothing, reason: post.id);
  }
}

List<Post> _explorePosts(WidgetTester tester) => tester
    .widget<ExploreScreen>(find.byType(ExploreScreen, skipOffstage: false))
    .posts;

final _savedIcon = find.byIcon(Icons.bookmark_rounded);

void main() {
  group('Search UI', () {
    testWidgets('search button opens a search field in the app bar', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _openSearch(tester);

      expect(find.widgetWithText(AppBar, 'SocialHub'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Đóng tìm kiếm'), findsOneWidget);
      // Stories and the composer make room for the results.
      expect(find.text('Thêm tin'), findsNothing);
      expect(find.text(composerHint), findsNothing);
    });

    testWidgets('empty query shows all visible posts', (tester) async {
      await _pumpApp(tester);

      await _openSearch(tester);

      _expectShown(mockPosts);
    });

    testWidgets('spaces-only query shows all visible posts', (tester) async {
      await _pumpApp(tester);

      await _search(tester, '    ');

      _expectShown(mockPosts);
      expect(find.text(_noResults), findsNothing);
    });

    testWidgets('closing search clears the query and restores Home', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _search(tester, 'citylight');

      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'SocialHub'), findsOneWidget);
      expect(find.text('Thêm tin'), findsOneWidget);
      _expectShown(mockPosts);

      // Opening search again starts with an empty field.
      await _openSearch(tester);
      expect(find.text('citylight'), findsNothing);
      _expectShown(mockPosts);
    });

    testWidgets('clear button restores all visible posts', (tester) async {
      await _pumpApp(tester);
      await _search(tester, 'zzz');

      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();

      expect(find.text(_noResults), findsNothing);
      _expectShown(mockPosts);
      // Search stays open after clearing.
      expect(find.byTooltip('Đóng tìm kiếm'), findsOneWidget);
    });
  });

  group('Search matching', () {
    testWidgets('ignores letter case', (tester) async {
      await _pumpApp(tester);

      await _search(tester, 'CITYLIGHT');

      _expectShown([_quang]);
      _expectHidden([_minh, _duy, _own]);
    });

    testWidgets('trims spaces around the query', (tester) async {
      await _pumpApp(tester);

      await _search(tester, '  MINH  ');

      _expectShown([_minh]);
      _expectHidden([_duy, _quang, _own]);
    });

    testWidgets('matches part of the content', (tester) async {
      await _pumpApp(tester);

      await _search(tester, 'prototy');

      _expectShown([_duy]);
      _expectHidden([_minh, _quang, _own]);
    });

    testWidgets('matches a word in several posts', (tester) async {
      await _pumpApp(tester);

      await _search(tester, 'mình');

      _expectShown([_duy, _own]);
      _expectHidden([_minh, _quang]);
    });

    testWidgets('matches the author name', (tester) async {
      await _pumpApp(tester);

      await _search(tester, 'duy kh');

      _expectShown([_duy]);
      _expectHidden([_minh, _quang, _own]);
    });

    testWidgets('no match shows the no-results message', (tester) async {
      await _pumpApp(tester);

      await _search(tester, 'không có bài nào như vậy');

      expect(find.text(_noResults), findsOneWidget);
      expect(find.text(_noPosts), findsNothing);
      _expectHidden(mockPosts);
    });

    testWidgets('newly created posts can be found', (tester) async {
      await _pumpApp(tester);
      await tapTab(tester, createTab);
      await tester.enterText(find.byType(TextField), 'Hello everyone');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      await _search(tester, 'hello');

      expect(find.text('Hello everyone'), findsOneWidget);
      _expectHidden(mockPosts);
    });
  });

  group('Hidden posts', () {
    testWidgets('hidden posts never appear in search results', (tester) async {
      await _pumpApp(tester);
      await hidePostFromMenu(tester, _minh);

      await _search(tester, 'minh');
      expect(find.text(_noResults), findsOneWidget);
      _expectHidden([_minh]);

      // An empty query shows only the posts that are still visible.
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      _expectShown([_duy, _quang, _own]);
      _expectHidden([_minh]);
    });

    testWidgets('hiding a search result removes it right away', (tester) async {
      await _pumpApp(tester);
      await _search(tester, 'mình');

      await hidePostFromMenu(tester, _duy);

      _expectHidden([_duy]);
      _expectShown([_own]);
      // The query is kept.
      expect(find.text('mình'), findsOneWidget);
    });

    testWidgets('Undo brings the hidden result back', (tester) async {
      await _pumpApp(tester);
      await _search(tester, 'mình');
      await hidePostFromMenu(tester, _duy);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      _expectShown([_duy, _own]);
    });
  });

  group('Saved posts', () {
    testWidgets('saved state stays visible in search results', (tester) async {
      await _pumpApp(tester);
      await savePostFromMenu(tester, _minh);

      await _search(tester, 'minh');

      expect(_savedIcon, findsOneWidget);
      await openPostMenu(tester, _minh);
      expect(find.text('Bỏ lưu bài viết'), findsOneWidget);
    });

    testWidgets('saving and unsaving from a result updates the feed', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _search(tester, 'citylight');

      await savePostFromMenu(tester, _quang);
      expect(_savedIcon, findsOneWidget);

      // The normal feed sees the same saved state.
      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pumpAndSettle();
      expect(_savedIcon, findsOneWidget);
      await openPostMenu(tester, _quang);
      expect(find.text('Bỏ lưu bài viết'), findsOneWidget);
      await closePostMenu(tester);

      // Unsave from a search result.
      await _search(tester, 'citylight');
      await openPostMenu(tester, _quang);
      await tapMenuItem(tester, 'Bỏ lưu bài viết');
      expect(_savedIcon, findsNothing);
    });
  });

  group('Interactions and shared state', () {
    testWidgets('liking a result updates the shared post', (tester) async {
      await _pumpApp(tester); // post_1 is liked with 254 likes.
      await _search(tester, 'minh');

      await tester.tap(find.text('${_minh.likes}'));
      await tester.pumpAndSettle();
      expect(find.text('${_minh.likes - 1}'), findsOneWidget);

      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pumpAndSettle();
      expect(find.text('${_minh.likes - 1}'), findsOneWidget);
      await tapTab(tester, exploreTab);
      expect(find.text('${_minh.likes - 1}'), findsOneWidget);
    });

    testWidgets('comment and share work from a result', (tester) async {
      await _pumpApp(tester);
      await _search(tester, 'minh');

      await tester.tap(find.byTooltip('Bình luận'));
      await tester.pumpAndSettle();
      expect(find.text('${_minh.comments} bình luận'), findsOneWidget);
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Chia sẻ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // Search is a view derived from the shared posts, never a new source.
    testWidgets('searching does not replace or change the shared posts', (
      tester,
    ) async {
      await _pumpApp(tester);
      final sharedBefore = _explorePosts(tester);
      final idsBefore = sharedBefore.map((post) => post.id).toList();

      await _search(tester, 'citylight');
      await _type(tester, 'minh');
      await _type(tester, 'zzz');

      // Same list object with the same posts in the same order.
      expect(_explorePosts(tester), same(sharedBefore));
      expect(sharedBefore.map((post) => post.id), idsBefore);
      expect(mockPosts.map((post) => post.id), idsBefore);

      // Home still receives every visible post; search only filters display.
      final homePosts = tester
          .widget<HomeScreen>(find.byType(HomeScreen))
          .posts;
      expect(homePosts.map((post) => post.id), idsBefore);

      // Other screens still show every post while Home is filtered.
      await tapTab(tester, exploreTab);
      _expectShown(mockPosts);
      await tapTab(tester, homeTab);
      expect(find.text(_noResults), findsOneWidget);
    });
  });

  group('Empty feed, accessibility and dark mode', () {
    testWidgets('an empty feed says there are no posts, even in search', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentUser: currentUser,
            posts: const [],
            stories: const [],
            savedPostIds: const {},
            onToggleLike: (_) {},
            onToggleSave: (_) {},
            onHidePost: (_) {},
            onUndoHidePost: (_) {},
            onOpenCreate: () {},
            onOpenStoryCreator: () {},
            onOpenMessages: () {},
            isDarkMode: false,
            onToggleTheme: () {},
          ),
        ),
      );
      expect(find.text(_noPosts), findsOneWidget);

      await _search(tester, 'abc');
      expect(find.text(_noPosts), findsOneWidget);
      expect(find.text(_noResults), findsNothing);
    });

    testWidgets('search controls expose meaningful semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpApp(tester);

      expect(
        tester.getSemantics(find.byTooltip('Tìm kiếm bài viết')),
        isSemantics(
          tooltip: 'Tìm kiếm bài viết',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await _search(tester, 'minh');
      expect(
        find.bySemanticsLabel(
          'Tìm kiếm bài viết trên bảng tin theo nội dung hoặc tác giả',
        ),
        findsOneWidget,
      );
      for (final tooltip in ['Xóa tìm kiếm', 'Đóng tìm kiếm']) {
        expect(
          tester.getSemantics(find.byTooltip(tooltip)),
          isSemantics(tooltip: tooltip, isButton: true, hasTapAction: true),
        );
      }
      semantics.dispose();
    });

    testWidgets('search works in dark mode', (tester) async {
      await _pumpApp(tester);
      await tester.tap(find.byTooltip('Chế độ tối'));
      await tester.pumpAndSettle();

      await _search(tester, 'minh');
      _expectShown([_minh]);
      await _type(tester, 'zzz');
      expect(find.text(_noResults), findsOneWidget);

      final home = tester.element(find.byType(HomeScreen));
      expect(Theme.of(home).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });
}
