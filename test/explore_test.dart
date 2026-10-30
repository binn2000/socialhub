import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/screens/profile_screen.dart';
import 'package:flutter_learning/widgets/mock_image.dart';

import 'test_helpers.dart';

// Mock posts by likes: post_3 (892), post_4 (429), post_1 (254), post_2 (143).
Post _post(String id) => mockPosts.firstWhere((post) => post.id == id);

/// A tall screen so every Explore tile is built without scrolling.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpExplore(
  WidgetTester tester,
  List<Post> posts, {
  ThemeData? theme,
}) async {
  _useTallScreen(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: ExploreScreen(posts: posts),
    ),
  );
}

Future<void> _search(WidgetTester tester, String query) async {
  if (find.byTooltip('Tìm kiếm bài viết').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Tìm kiếm bài viết'));
    await tester.pump();
  }
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

Future<void> _selectFilter(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
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

/// Post ids in on-screen reading order (left to right, top to bottom).
List<String> _displayedOrder(WidgetTester tester, List<Post> posts) {
  Offset tileOf(Post post) => tester.getTopLeft(
    find
        .ancestor(of: find.text(post.content), matching: find.byType(InkWell))
        .first,
  );
  final shown = posts
      .where((post) => find.text(post.content).evaluate().isNotEmpty)
      .toList();
  shown.sort((a, b) {
    final pa = tileOf(a), pb = tileOf(b);
    return pa.dy != pb.dy ? pa.dy.compareTo(pb.dy) : pa.dx.compareTo(pb.dx);
  });
  return shown.map((post) => post.id).toList();
}

const _noResults = 'Không tìm thấy bài viết phù hợp';

void main() {
  group('Explore search', () {
    testWidgets('shows every current post exactly once', (tester) async {
      await _pumpExplore(tester, mockPosts);

      // findsOneWidget per post also catches posts being repeated.
      _expectShown(mockPosts);
    });

    testWidgets('empty search shows all posts', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, '   ');

      _expectShown(mockPosts);
    });

    testWidgets('search ignores letter case', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, 'CITYLIGHT');

      _expectShown([_post('post_3')]);
      _expectHidden([_post('post_1'), _post('post_2'), _post('post_4')]);
    });

    testWidgets('search matches part of the content', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, 'prototy');

      _expectShown([_post('post_2')]);
      _expectHidden([_post('post_1'), _post('post_3'), _post('post_4')]);
    });

    testWidgets('search also matches the author name', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, 'minh ánh');

      _expectShown([_post('post_1')]);
      _expectHidden([_post('post_2'), _post('post_3'), _post('post_4')]);
    });

    testWidgets('no match shows the empty state', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, 'không có bài nào như vậy');

      expect(find.text(_noResults), findsOneWidget);
      _expectHidden(mockPosts);
    });

    testWidgets('clear button restores all results', (tester) async {
      await _pumpExplore(tester, mockPosts);
      await _search(tester, 'zzz');

      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pump();

      expect(find.text(_noResults), findsNothing);
      _expectShown(mockPosts);
    });

    testWidgets('closing search restores all results', (tester) async {
      await _pumpExplore(tester, mockPosts);
      await _search(tester, 'citylight');

      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pump();

      expect(find.text('Khám phá'), findsOneWidget);
      _expectShown(mockPosts);
    });

    testWidgets('search does not modify the post list', (tester) async {
      final posts = List<Post>.from(mockPosts);
      final idsBefore = posts.map((post) => post.id).toList();
      await _pumpExplore(tester, posts);

      await _search(tester, 'citylight');
      await _selectFilter(tester, 'Đang thịnh hành');

      expect(posts.map((post) => post.id), idsBefore);
    });
  });

  group('Explore filters', () {
    testWidgets('"Dành cho bạn" keeps the feed order', (tester) async {
      await _pumpExplore(tester, mockPosts);

      expect(_displayedOrder(tester, mockPosts), [
        'post_1',
        'post_2',
        'post_3',
        'post_4',
      ]);
    });

    testWidgets('"Đang thịnh hành" orders posts by likes', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _selectFilter(tester, 'Đang thịnh hành');

      expect(_displayedOrder(tester, mockPosts), [
        'post_3',
        'post_4',
        'post_1',
        'post_2',
      ]);

      await _selectFilter(tester, 'Dành cho bạn');
      expect(_displayedOrder(tester, mockPosts).first, 'post_1');
    });

    testWidgets('filters combine with search', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _search(tester, 'mình');
      await _selectFilter(tester, 'Đang thịnh hành');

      // post_4 (429 likes) and post_2 (143 likes) both contain "Mình".
      expect(_displayedOrder(tester, mockPosts), ['post_4', 'post_2']);
    });

    testWidgets('"Video ngắn" shows an honest empty state', (tester) async {
      await _pumpExplore(tester, mockPosts);

      await _selectFilter(tester, 'Video ngắn');

      expect(find.text('Chưa có video ngắn'), findsOneWidget);
      _expectHidden(mockPosts);

      await _selectFilter(tester, 'Dành cho bạn');
      _expectShown(mockPosts);
    });

    testWidgets('filters expose their label and selected state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpExplore(tester, mockPosts);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Bộ lọc Dành cho bạn')),
        matchesSemantics(
          label: 'Bộ lọc Dành cho bạn',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );

      await _selectFilter(tester, 'Video ngắn');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bộ lọc Dành cho bạn')),
        matchesSemantics(
          label: 'Bộ lọc Dành cho bạn',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('Explore post tiles', () {
    testWidgets('image posts reuse PostMedia with their image identity', (
      tester,
    ) async {
      final post = Post(
        id: 'explore_image',
        author: currentUser,
        content: 'Ảnh hoàng hôn',
        imageUrl: 'assets/placeholder.png',
        imageId: 'mock_image_2',
        createdAt: 'Vừa xong',
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
      );
      await _pumpExplore(tester, [post]);

      final media = tester.widget<PostMedia>(find.byType(PostMedia));
      expect(media.post.imageId, 'mock_image_2');
      expect(media.post.imageUrl, 'assets/placeholder.png');
    });

    testWidgets('tapping a tile shows feeling, privacy and counts', (
      tester,
    ) async {
      final post = Post(
        id: 'explore_detail',
        author: mockUsers[2],
        content: 'Chi tiết bài viết',
        feeling: 'Hứng thú',
        privacy: 'Bạn bè',
        createdAt: '5 phút trước',
        likes: 3,
        comments: 2,
        shares: 1,
        isLiked: false,
      );
      await _pumpExplore(tester, [post]);

      await tester.tap(find.text('Chi tiết bài viết'));
      await tester.pumpAndSettle();

      expect(
        find.text('5 phút trước · đang hứng thú · Bạn bè'),
        findsOneWidget,
      );
      expect(
        find.text('3 lượt thích · 2 bình luận · 1 lượt chia sẻ'),
        findsOneWidget,
      );
    });

    testWidgets('tiles and search field have screen reader labels', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final post = _post('post_2');
      await _pumpExplore(tester, [post]);

      expect(
        find.bySemanticsLabel(
          'Bài viết của ${post.author.name}: ${post.content}, '
          '${post.likes} lượt thích, ${post.comments} bình luận',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Tìm kiếm bài viết'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Tìm kiếm bài viết theo nội dung')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('Explore empty list and themes', () {
    testWidgets('empty post list shows the empty state', (tester) async {
      await _pumpExplore(tester, const []);

      expect(find.text('Chưa có bài viết nào để khám phá'), findsOneWidget);

      // Searching and filtering an empty list does not crash.
      await _search(tester, 'abc');
      await _selectFilter(tester, 'Đang thịnh hành');
      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có bài viết nào để khám phá'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('renders in ${brightness.name} mode', (tester) async {
        await _pumpExplore(
          tester,
          mockPosts,
          theme: ThemeData(useMaterial3: true, brightness: brightness),
        );
        expect(tester.takeException(), isNull);

        await _search(tester, 'zzz');
        expect(find.text(_noResults), findsOneWidget);
        await _selectFilter(tester, 'Video ngắn');
        expect(find.text('Chưa có video ngắn'), findsOneWidget);

        final context = tester.element(find.byType(ExploreScreen));
        expect(Theme.of(context).brightness, brightness);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Explore in the app', () {
    testWidgets('a newly created post appears in Explore', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, createTab);
      await tester.enterText(find.byType(TextField), 'Bài mới cho Khám phá');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      await tapTab(tester, exploreTab);

      expect(find.text('Bài mới cho Khám phá'), findsOneWidget);
    });

    testWidgets('liking on Home is reflected in Explore', (tester) async {
      final post = _post('post_1'); // Liked, 254 likes.
      await pumpSocialHub(tester);

      await tester.ensureVisible(find.text('${post.likes}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${post.likes}'));
      await tester.pumpAndSettle();
      await tapTab(tester, exploreTab);

      expect(find.text('${post.likes - 1}'), findsOneWidget);
      expect(find.text('${post.likes}'), findsNothing);
    });

    // Home gets a filtered view (hidden posts removed), so compare Explore
    // with Profile, which also receives MainScreen's _posts directly.
    testWidgets('Explore uses the shared post list, not a copy', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await tapTab(tester, createTab);
      await tester.enterText(find.byType(TextField), 'Danh sách chung');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      final explorePosts = tester
          .widget<ExploreScreen>(
            find.byType(ExploreScreen, skipOffstage: false),
          )
          .posts;
      final profilePosts = tester
          .widget<ProfileScreen>(
            find.byType(ProfileScreen, skipOffstage: false),
          )
          .posts;

      expect(explorePosts, same(profilePosts));
      expect(explorePosts.first.content, 'Danh sách chung');
    });

    testWidgets('search is kept while switching tabs', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, exploreTab);
      await _search(tester, 'citylight');

      await tapTab(tester, homeTab);
      await tapTab(tester, exploreTab);

      _expectShown([_post('post_3')]);
      _expectHidden([_post('post_1')]);
    });
  });
}
