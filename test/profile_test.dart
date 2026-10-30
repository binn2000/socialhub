import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/screens/edit_profile_screen.dart';
import 'package:flutter_learning/screens/story_viewer_screen.dart';

import 'test_helpers.dart';

final _nameField = find.widgetWithText(TextFormField, 'Tên');
final _bioField = find.widgetWithText(TextFormField, 'Tiểu sử');

Future<void> _openEditProfile(WidgetTester tester) async {
  await tapTab(tester, profileTab);
  await tester.tap(find.text('Edit Profile'));
  await tester.pumpAndSettle();
  expect(find.byType(EditProfileScreen), findsOneWidget);
}

Future<void> _saveProfile(WidgetTester tester) async {
  await tester.tap(find.text('Lưu'));
  await tester.pumpAndSettle();
}

void main() {
  const newName = 'Hùng Mới';
  const newBio = 'Flutter learner';
  // Text of the mock post authored by currentUser (post_4).
  final ownPostText = mockPosts
      .firstWhere((post) => post.author.id == currentUser.id)
      .content;

  testWidgets('profile shows the current user name and bio', (tester) async {
    await pumpSocialHub(tester);
    await tapTab(tester, profileTab);

    expect(find.text(currentUser.name), findsOneWidget);
    expect(find.text(currentUser.bio), findsOneWidget);
  });

  testWidgets('edit profile is pre-filled with the current values', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);

    expect(
      tester.widget<TextFormField>(_nameField).controller!.text,
      currentUser.name,
    );
    expect(
      tester.widget<TextFormField>(_bioField).controller!.text,
      currentUser.bio,
    );
  });

  testWidgets('saving a new name updates the profile', (tester) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);

    await tester.enterText(_nameField, newName);
    await _saveProfile(tester);

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text(newName), findsOneWidget);
    expect(find.text(currentUser.name), findsNothing);
  });

  testWidgets('saving a new bio updates the profile', (tester) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);

    await tester.enterText(_bioField, newBio);
    await _saveProfile(tester);

    expect(find.text(newBio), findsOneWidget);
    expect(find.text(currentUser.bio), findsNothing);
    expect(find.text(currentUser.name), findsOneWidget);
  });

  testWidgets('empty or whitespace-only name is rejected', (tester) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);

    for (final invalidName in ['', '   ']) {
      await tester.enterText(_nameField, invalidName);
      await _saveProfile(tester);

      expect(find.text('Tên không được để trống'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
    }

    // Going back without saving keeps the original name.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(currentUser.name), findsOneWidget);
  });

  testWidgets('bio may be empty', (tester) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);

    await tester.enterText(_bioField, '');
    await _saveProfile(tester);

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text(currentUser.bio), findsNothing);
    expect(find.text(currentUser.name), findsOneWidget);
  });

  testWidgets('updated profile is kept after navigating away and back', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);
    await tester.enterText(_nameField, newName);
    await tester.enterText(_bioField, newBio);
    await _saveProfile(tester);

    await tapTab(tester, homeTab);
    await tapTab(tester, friendsTab);
    await tapTab(tester, profileTab);

    expect(find.text(newName), findsOneWidget);
    expect(find.text(newBio), findsOneWidget);

    // Opening Edit Profile again starts from the saved values.
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_nameField).controller!.text, newName);
  });

  testWidgets('own posts keep the same author after a profile update', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);
    await tester.enterText(_nameField, newName);
    await _saveProfile(tester);

    // Profile still lists the post written before the rename.
    expect(find.text(ownPostText), findsOneWidget);

    // Home shows that post under the new name.
    await tapTab(tester, homeTab);
    await tester.scrollUntilVisible(
      find.text(ownPostText),
      300,
      scrollable: visibleVerticalScrollable,
    );
    expect(find.text(newName), findsOneWidget);
    expect(find.text(currentUser.name), findsNothing);
  });

  testWidgets('own story shows the new name after a profile update', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);
    await tester.enterText(_nameField, newName);
    await _saveProfile(tester);
    await tapTab(tester, homeTab);

    // Story tiles show the first word of the name.
    await tester.tap(find.text(newName.split(' ').first));
    await tester.pumpAndSettle();

    expect(find.byType(StoryViewerScreen), findsOneWidget);
    // The name appears in the header and in the large caption.
    expect(find.text(newName), findsNWidgets(2));
    expect(find.text(currentUser.name), findsNothing);
  });

  testWidgets('posts created after a profile update use the new name', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await _openEditProfile(tester);
    await tester.enterText(_nameField, newName);
    await _saveProfile(tester);

    await tapTab(tester, createTab);
    await tester.enterText(find.byType(TextField), 'Bài sau khi đổi tên');
    await tester.tap(find.text('Đăng'));
    await tester.pumpAndSettle();

    await tapTab(tester, profileTab);
    await tester.scrollUntilVisible(
      find.text('Bài sau khi đổi tên'),
      300,
      scrollable: visibleVerticalScrollable,
    );
    await tester.scrollUntilVisible(
      find.text(ownPostText),
      300,
      scrollable: visibleVerticalScrollable,
    );
  });
}
