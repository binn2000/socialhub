import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/widgets/mock_image.dart';

void main() {
  test('mock image choices have stable unique identities', () {
    final ids = mockImageChoices.map((choice) => choice.id).toSet();

    expect(ids.length, mockImageChoices.length);
    expect(ids, containsAll(['mock_image_1', 'mock_image_2', 'mock_image_3']));
    expect(
      mockImageColors('mock_image_1'),
      isNot(equals(mockImageColors('mock_image_2'))),
    );
  });

  test('only real bundled assets are loaded, not the 1x1 placeholder', () {
    expect(canLoadAssetImage('assets/photo.png'), isTrue);
    expect(canLoadAssetImage('assets/placeholder.png'), isFalse);
    expect(canLoadAssetImage('https://example.com/a.png'), isFalse);
    expect(canLoadAssetImage(null), isFalse);
  });

  testWidgets('posts without image identity render safely', (tester) async {
    final post = Post(
      id: 'post_without_image',
      author: currentUser,
      content: 'Text only',
      createdAt: 'Vừa xong',
      likes: 0,
      comments: 0,
      shares: 0,
      isLiked: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PostMedia(post: post)),
      ),
    );

    expect(find.byType(PostMedia), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });
}
