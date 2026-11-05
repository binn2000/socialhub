import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/data/post_reactions.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/widgets/post_parts.dart';

void main() {
  final testPost = Post(
    id: 'post_1',
    author: currentUser,
    content: 'Hello world test post',
    createdAt: '1 giờ trước',
    likes: 10,
    comments: 2,
    shares: 1,
    isLiked: false,
  );

  group('PostReaction constants & helpers', () {
    test('contains standard 6 reactions', () {
      expect(kPostReactions.length, 6);
      final keys = kPostReactions.map((r) => r.key).toList();
      expect(keys, ['like', 'love', 'haha', 'wow', 'sad', 'angry']);
    });

    test('findPostReaction returns matching reaction', () {
      final love = findPostReaction('love');
      expect(love, isNotNull);
      expect(love!.label, 'Yêu thích');
      expect(love.emoji, '❤️');

      expect(findPostReaction('unknown'), isNull);
      expect(findPostReaction(null), isNull);
    });
  });

  group('PostActionBar multi-reaction widget tests', () {
    testWidgets('renders action bar with unliked state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostActionBar(post: testPost)),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets(
      'long press opens reactions capsule and selecting reaction works',
      (tester) async {
        PostReaction? selectedRx;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PostActionBar(
                post: testPost,
                onReactionSelected: (rx) {
                  selectedRx = rx;
                },
              ),
            ),
          ),
        );

        // Long press like button to open reactions capsule
        await tester.longPress(find.byIcon(Icons.favorite_border_rounded));
        await tester.pumpAndSettle();

        // Check that emojis from reactions capsule are displayed
        expect(find.text('👍'), findsOneWidget);
        expect(find.text('❤️'), findsOneWidget);
        expect(find.text('😆'), findsOneWidget);
        expect(find.text('😮'), findsOneWidget);
        expect(find.text('😢'), findsOneWidget);
        expect(find.text('😡'), findsOneWidget);

        // Tap 'Haha' reaction
        await tester.tap(find.text('😆'));
        await tester.pumpAndSettle();

        expect(selectedRx, isNotNull);
        expect(selectedRx!.key, 'haha');
        expect(selectedRx!.label, 'Haha');
      },
    );

    testWidgets(
      'the chosen reaction does not follow the widget to another post',
      (tester) async {
        Post liked(String id) => Post(
          id: id,
          author: currentUser,
          content: 'Bài $id',
          createdAt: '1 giờ trước',
          likes: 5,
          comments: 0,
          shares: 0,
          isLiked: true,
        );

        Widget bar(Post post) => MaterialApp(
          home: Scaffold(body: PostActionBar(post: post)),
        );

        await tester.pumpWidget(bar(liked('a')));
        await tester.longPress(find.byIcon(Icons.favorite_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('😆'));
        await tester.pumpAndSettle();
        expect(find.text('😆'), findsOneWidget); // shown on the like button

        // The same State is reused for another, also liked, post.
        await tester.pumpWidget(bar(liked('b')));
        expect(find.text('😆'), findsNothing);
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      },
    );

    testWidgets('the open reactions capsule goes away with the widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostActionBar(post: testPost)),
        ),
      );
      await tester.longPress(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.text('😆'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();
      expect(find.text('😆'), findsNothing);
    });
  });
}
