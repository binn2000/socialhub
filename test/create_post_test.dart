import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/screens/create_post_screen.dart';

import 'test_helpers.dart';

/// What CreatePostScreen passed to onPostCreated.
class _SubmittedPost {
  final String text;
  final String feeling;
  final String privacy;
  final String? imageUrl;
  final String? imageId;

  _SubmittedPost(
    this.text,
    this.feeling,
    this.privacy,
    this.imageUrl,
    this.imageId,
  );
}

/// Shows CreatePostScreen on its own and records every submitted post.
Future<List<_SubmittedPost>> _pumpCreatePost(WidgetTester tester) async {
  final submitted = <_SubmittedPost>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CreatePostScreen(
        currentUser: currentUser,
        onPostCreated: (text, feeling, privacy, imageUrl, imageId) {
          submitted.add(
            _SubmittedPost(text, feeling, privacy, imageUrl, imageId),
          );
        },
      ),
    ),
  );
  return submitted;
}

Future<void> _selectImage(WidgetTester tester, String label) async {
  await tester.tap(find.text('Chọn ảnh mock'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownValue(
  WidgetTester tester, {
  required String from,
  required String to,
}) async {
  await tester.ensureVisible(find.text(from));
  await tester.tap(find.text(from));
  await tester.pumpAndSettle();
  // The opened menu shows every option; tap the one in the menu.
  await tester.tap(find.text(to).last);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('Đăng'));
  await tester.pump();
}

const _validationMessage = 'Hãy thêm nội dung hoặc chọn một ảnh';

void main() {
  photoPickerTests();

  group('CreatePostScreen', () {
    testWidgets('empty post cannot be submitted', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await _submit(tester);

      expect(submitted, isEmpty);
      expect(find.text(_validationMessage), findsOneWidget);
    });

    testWidgets('whitespace-only text without image cannot be submitted', (
      tester,
    ) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), '   \n  ');
      await _submit(tester);

      expect(submitted, isEmpty);
      expect(find.text(_validationMessage), findsOneWidget);
    });

    testWidgets('text-only post is submitted with trimmed text', (
      tester,
    ) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), '  Xin chào  ');
      await _submit(tester);

      expect(submitted, hasLength(1));
      expect(submitted.single.text, 'Xin chào');
      expect(submitted.single.imageId, isNull);
      expect(submitted.single.imageUrl, isNull);
    });

    testWidgets('image-only post is submitted with empty text', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await _selectImage(tester, 'Thành phố xanh');
      await _submit(tester);

      expect(submitted, hasLength(1));
      expect(submitted.single.text, isEmpty);
      expect(submitted.single.imageId, 'mock_image_3');
    });

    testWidgets('text + image post keeps both', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), 'Ảnh đẹp');
      await _selectImage(tester, 'Sắc tím sáng tạo');
      await _submit(tester);

      expect(submitted.single.text, 'Ảnh đẹp');
      expect(submitted.single.imageId, 'mock_image_1');
      expect(submitted.single.imageUrl, 'assets/placeholder.png');
    });

    testWidgets('removing the image clears the image identity', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), 'Chỉ còn chữ');
      await _selectImage(tester, 'Hoàng hôn ấm áp');
      // With an image selected the button offers to change it.
      await tester.tap(find.text('Đổi ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa ảnh đã chọn'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ảnh mock'), findsOneWidget);
      expect(find.text('Chọn video'), findsNothing); // server only
      await _submit(tester);

      expect(submitted.single.text, 'Chỉ còn chữ');
      expect(submitted.single.imageId, isNull);
      expect(submitted.single.imageUrl, isNull);
    });

    testWidgets('selected feeling and privacy are submitted', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), 'Cuối tuần');
      await _selectDropdownValue(tester, from: 'Cảm thấy vui', to: 'Hứng thú');
      await _selectDropdownValue(tester, from: 'Công khai', to: 'Bạn bè');
      await _submit(tester);

      expect(submitted.single.feeling, 'Hứng thú');
      expect(submitted.single.privacy, 'Bạn bè');
    });

    testWidgets('default feeling and privacy are submitted', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), 'Mặc định');
      await _submit(tester);

      expect(submitted.single.feeling, 'Cảm thấy vui');
      expect(submitted.single.privacy, 'Công khai');
    });

    testWidgets('form is cleared after a successful post', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), 'Bài đầu tiên');
      await _selectImage(tester, 'Thành phố xanh');
      await _selectDropdownValue(tester, from: 'Cảm thấy vui', to: 'Hứng thú');
      await _selectDropdownValue(tester, from: 'Công khai', to: 'Bạn bè');
      await _submit(tester);

      expect(submitted, hasLength(1));
      // Text, image, feeling and privacy are back to their defaults.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Chọn ảnh mock'), findsOneWidget);
      expect(find.text('Cảm thấy vui'), findsWidgets);
      expect(find.text('Công khai'), findsWidgets);

      // Pressing Đăng again does not post the old content a second time.
      await _submit(tester);
      expect(submitted, hasLength(1));
      expect(find.text(_validationMessage), findsOneWidget);
    });

    testWidgets('a rejected post keeps what the user typed', (tester) async {
      final submitted = await _pumpCreatePost(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await _submit(tester);

      expect(submitted, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '   ',
      );
    });
  });

  group('Created post in the app', () {
    testWidgets('new post appears first in Home with feeling and privacy', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await tapTab(tester, createTab);

      await tester.enterText(find.byType(TextField), 'Bài viết mới');
      await _selectDropdownValue(tester, from: 'Cảm thấy vui', to: 'Hạnh phúc');
      await _selectDropdownValue(tester, from: 'Công khai', to: 'Chỉ mình tôi');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      // Posting returns to Home.
      expect(find.text('SocialHub'), findsOneWidget);
      expect(find.text('Bài viết mới'), findsOneWidget);
      expect(find.text('đang hạnh phúc · Chỉ mình tôi'), findsOneWidget);

      final newPostTop = tester.getTopLeft(find.text('Bài viết mới')).dy;
      final firstMockPostTop = tester
          .getTopLeft(find.text(mockPosts.first.content))
          .dy;
      expect(newPostTop, lessThan(firstMockPostTop));
    });

    testWidgets('new post by current user appears in Profile', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, createTab);

      await tester.enterText(find.byType(TextField), 'Bài của tôi');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();
      await tapTab(tester, profileTab);

      await tester.scrollUntilVisible(
        find.text('Bài của tôi'),
        300,
        scrollable: visibleVerticalScrollable,
      );
    });

    testWidgets('creating a post leaves existing posts unchanged', (
      tester,
    ) async {
      final originalCount = mockPosts.length;
      final firstPost = mockPosts.first;

      await pumpSocialHub(tester);
      await tapTab(tester, createTab);
      await tester.enterText(find.byType(TextField), 'Thêm một bài');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      // The shared mock list is not modified.
      expect(mockPosts, hasLength(originalCount));

      // The first mock post still shows its author, text and counts.
      expect(find.text(firstPost.content), findsOneWidget);
      expect(find.text(firstPost.author.name), findsOneWidget);
      expect(find.text('${firstPost.likes}'), findsOneWidget);
      expect(find.text('${firstPost.comments}'), findsOneWidget);
    });

    testWidgets('returning to Create Post shows an empty form', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, createTab);
      await tester.enterText(find.byType(TextField), 'Chỉ đăng một lần');
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      await tapTab(tester, createTab);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      // Pressing Đăng on the empty form is rejected, so no duplicate is added.
      await tester.tap(find.text('Đăng'));
      await tester.pump();
      expect(find.text(_validationMessage), findsOneWidget);

      await tapTab(tester, homeTab);
      await tester.scrollUntilVisible(
        find.text('Chỉ đăng một lần'),
        300,
        scrollable: visibleVerticalScrollable,
      );
      expect(find.text('Chỉ đăng một lần'), findsOneWidget);
    });
  });
}

/// A real (tiny) file, so the picked path points at something that exists.
String _photoFile() {
  final file = File('${Directory.systemTemp.path}/create_post_test_photo.png')
    ..writeAsBytesSync(base64Decode(_onePixelPng));
  addTearDown(() => file.deleteSync());
  return file.path;
}

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<List<_SubmittedPost>> _pumpCreatePostWithPhotoPicker(
  WidgetTester tester,
  Future<String?> Function() pick,
) async {
  final submitted = <_SubmittedPost>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CreatePostScreen(
        currentUser: currentUser,
        onPickPhoto: pick,
        onPostCreated: (text, feeling, privacy, imageUrl, imageId) {
          submitted.add(
            _SubmittedPost(text, feeling, privacy, imageUrl, imageId),
          );
        },
      ),
    ),
  );
  return submitted;
}

void photoPickerTests() {
  group('CreatePostScreen with a real photo picker', () {
    testWidgets('offers "Chọn ảnh" instead of the mock images', (tester) async {
      await _pumpCreatePostWithPhotoPicker(tester, () async => null);

      expect(find.text('Chọn ảnh'), findsOneWidget);
      expect(find.text('Chọn ảnh mock'), findsNothing);
    });

    testWidgets('a photo-only post is submitted with the file path', (
      tester,
    ) async {
      final path = _photoFile();
      final submitted = await _pumpCreatePostWithPhotoPicker(
        tester,
        () async => path,
      );

      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi ảnh'), findsOneWidget);
      await _submit(tester);

      expect(submitted, hasLength(1));
      expect(submitted.single.text, isEmpty);
      expect(submitted.single.imageUrl, path);
      expect(submitted.single.imageId, isNull);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final submitted = await _pumpCreatePostWithPhotoPicker(
        tester,
        () async => null,
      );

      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await _submit(tester);

      expect(submitted, isEmpty);
      expect(find.text(_validationMessage), findsOneWidget);
    });

    testWidgets('a removed photo is not submitted', (tester) async {
      final path = _photoFile();
      final submitted = await _pumpCreatePostWithPhotoPicker(
        tester,
        () async => path,
      );

      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa ảnh'));
      await tester.pumpAndSettle();
      await _submit(tester);

      expect(submitted, isEmpty);
      expect(find.text('Chọn ảnh'), findsOneWidget);
    });

    testWidgets('the form is empty again after posting', (tester) async {
      final path = _photoFile();
      await _pumpCreatePostWithPhotoPicker(tester, () async => path);

      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await _submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Chọn ảnh'), findsOneWidget);
      expect(find.text('Đổi ảnh'), findsNothing);
    });
  });
}
