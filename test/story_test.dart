import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/screens/home_screen.dart';
import 'package:flutter_learning/screens/story_creator_screen.dart';
import 'package:flutter_learning/screens/story_viewer_screen.dart';
import 'package:flutter_learning/widgets/story_item.dart';

import 'test_helpers.dart';

const _defaultStoryText = 'Cùng nhìn lại khoảnh khắc đẹp trong ngày hôm nay';

Future<void> _pumpViewer(
  WidgetTester tester,
  List<Story> stories, {
  int initialIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StoryViewerScreen(stories: stories, initialIndex: initialIndex),
    ),
  );
}

Future<void> _pumpHome(WidgetTester tester, List<Story> stories) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        currentUser: currentUser,
        posts: const [],
        stories: stories,
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
}

/// The name shown on screen for [story] (header + large caption).
Finder _storyAuthor(Story story) => find.text(story.user.name);

void main() {
  storyPhotoTests();

  group('StoryViewerScreen', () {
    testWidgets('empty story list shows a message instead of crashing', (
      tester,
    ) async {
      await _pumpViewer(tester, const [], initialIndex: 3);

      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có tin nào'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
    });

    testWidgets('shows the selected story', (tester) async {
      final story = mockStories[1];
      await _pumpViewer(tester, mockStories, initialIndex: 1);

      expect(_storyAuthor(story), findsNWidgets(2));
      expect(find.text(story.user.bio), findsOneWidget);
      expect(find.text(_defaultStoryText), findsOneWidget);
      expect(find.byTooltip('Đóng tin'), findsOneWidget);
    });

    testWidgets('out-of-range start index shows the nearest valid story', (
      tester,
    ) async {
      await _pumpViewer(tester, mockStories, initialIndex: 99);
      expect(_storyAuthor(mockStories.last), findsNWidgets(2));

      // Replace the tree so the viewer starts again with a new index.
      await tester.pumpWidget(const SizedBox());
      await _pumpViewer(tester, mockStories, initialIndex: -4);
      expect(_storyAuthor(mockStories.first), findsNWidgets(2));
    });

    testWidgets('swiping never goes past the first or last story', (
      tester,
    ) async {
      final lastIndex = mockStories.length - 1;
      await _pumpViewer(tester, mockStories, initialIndex: lastIndex);

      // Try to swipe forward past the last story.
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_storyAuthor(mockStories.last), findsNWidgets(2));

      // Swipe back one story.
      await tester.drag(find.byType(PageView), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(_storyAuthor(mockStories[lastIndex - 1]), findsNWidgets(2));
    });

    testWidgets('swiping back from the first story stays on it', (
      tester,
    ) async {
      await _pumpViewer(tester, mockStories);

      await tester.drag(find.byType(PageView), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_storyAuthor(mockStories.first), findsNWidgets(2));
    });
  });

  group('StoryCreatorScreen', () {
    testWidgets('background swatches expose a label and selected state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: StoryCreatorScreen(
            currentUser: currentUser,
            onStoryCreated: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Màu nền 1')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      await tester.tap(find.bySemanticsLabel('Màu nền 2'));
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Màu nền 2')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Màu nền 1')),
        isSemantics(isSelected: false),
      );
      semantics.dispose();
    });

    testWidgets('new story belongs to the current user', (tester) async {
      Story? created;
      await tester.pumpWidget(
        MaterialApp(
          home: StoryCreatorScreen(
            currentUser: currentUser,
            onStoryCreated: (story) => created = story,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '  Tin mới  ');
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.user.id, currentUser.id);
      expect(created!.text, 'Tin mới');
    });

    testWidgets('empty story text is not published', (tester) async {
      var createdCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StoryCreatorScreen(
            currentUser: currentUser,
            onStoryCreated: (_) => createdCount++,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(createdCount, 0);
      expect(find.byType(StoryCreatorScreen), findsOneWidget);
    });
  });

  group('Stories on Home', () {
    testWidgets('Add Story tile is shown even with no stories', (tester) async {
      await _pumpHome(tester, const []);

      expect(find.text('Thêm tin'), findsOneWidget);
      expect(find.byType(StoryItem), findsOneWidget);
    });

    testWidgets('Add Story tile is one extra item next to the stories', (
      tester,
    ) async {
      await _pumpHome(tester, mockStories);

      expect(find.text('Thêm tin'), findsOneWidget);
      expect(find.byType(StoryItem), findsNWidgets(mockStories.length + 1));
    });

    testWidgets('tapping a story tile opens that story', (tester) async {
      await pumpSocialHub(tester);
      final story = mockStories[1];

      await tester.tap(find.text(story.user.name.split(' ').first));
      await tester.pumpAndSettle();

      expect(find.byType(StoryViewerScreen), findsOneWidget);
      expect(_storyAuthor(story), findsNWidgets(2));
    });

    testWidgets('created story appears with the current user as author', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      final firstName = currentUser.name.split(' ').first;
      expect(find.text(firstName), findsOneWidget);

      await tester.tap(find.text('Thêm tin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tin của tôi');
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      // The new story is listed first among the current user's stories,
      // and the Add Story tile is still there exactly once.
      expect(find.text('Thêm tin'), findsOneWidget);
      expect(find.text(firstName), findsNWidgets(2));
      // The shared mock list itself is not modified.
      expect(mockStories.first.id, 'story_0');

      await tester.tap(find.text(firstName).first);
      await tester.pumpAndSettle();
      expect(find.text('Tin của tôi'), findsOneWidget);
      expect(find.text(currentUser.name), findsNWidgets(2));
    });
  });
}

void storyPhotoTests() {
  group('StoryCreatorScreen with a real photo picker', () {
    Future<List<Story>> pumpCreator(
      WidgetTester tester,
      Future<String?> Function()? pick,
    ) async {
      final created = <Story>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StoryCreatorScreen(
            currentUser: currentUser,
            onStoryCreated: created.add,
            onPickPhoto: pick,
          ),
        ),
      );
      return created;
    }

    testWidgets('without a picker there is no photo button', (tester) async {
      await pumpCreator(tester, null);

      expect(find.byTooltip('Chọn ảnh'), findsNothing);
    });

    testWidgets('a photo-only story is published with the file path', (
      tester,
    ) async {
      final file = File('${Directory.systemTemp.path}/story_test_photo.png')
        ..writeAsBytesSync(const [0]);
      addTearDown(file.deleteSync);
      final created = await pumpCreator(tester, () async => file.path);

      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();
      expect(created, isEmpty, reason: 'nothing to share yet');

      await tester.tap(find.byTooltip('Chọn ảnh'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Đổi ảnh'), findsOneWidget);
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(created, hasLength(1));
      expect(created.single.imageUrl, file.path);
      expect(created.single.text, isNull);
    });

    testWidgets('a removed photo leaves an empty story', (tester) async {
      final created = await pumpCreator(tester, () async => '/tmp/none.png');

      await tester.tap(find.byTooltip('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xóa ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(created, isEmpty);
    });

    testWidgets('text and photo can go together', (tester) async {
      final created = await pumpCreator(tester, () async => '/tmp/p.png');

      await tester.enterText(find.byType(TextField), 'Chiều nay');
      await tester.tap(find.byTooltip('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(created.single.text, 'Chiều nay');
      expect(created.single.imageUrl, '/tmp/p.png');
    });
  });
}
