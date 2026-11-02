import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/screens/chat_screen.dart';
import 'package:flutter_learning/screens/create_post_screen.dart';
import 'package:flutter_learning/screens/edit_profile_screen.dart';
import 'package:flutter_learning/screens/profile_screen.dart';
import 'package:flutter_learning/screens/user_profile_screen.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/follow_list_sheet.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

void main() {
  const dummyUser = UserModel(
    id: 'user_1',
    name: 'Long Nguyen',
    username: '@longnguyen',
    avatarUrl: 'https://example.com/avatar.jpg',
    coverUrl: '',
    bio: 'Mobile Developer',
    mutualFriends: 0,
    isFriend: false,
    accentColor: Color(0xFF3D4DD8),
    isOnline: true,
    showOnlineStatus: true,
    followersCount: 15,
    followingCount: 8,
    isFollowing: false,
    followsYou: true,
  );

  group('Feature 1: Multi-image carousel and creation', () {
    testWidgets(
      'PostMedia renders PageView and indicator when imageUrls has multiple items',
      (tester) async {
        const post = Post(
          id: 'p1',
          author: dummyUser,
          content: 'Post with multiple images',
          createdAt: '1h',
          imageUrl: 'img1.jpg',
          imageUrls: ['img1.jpg', 'img2.jpg', 'img3.jpg'],
          likes: 0,
          comments: 0,
          shares: 0,
          isLiked: false,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: PostMedia(post: post)),
          ),
        );

        expect(find.byType(PageView), findsOneWidget);
        expect(find.text('1/3'), findsOneWidget);
      },
    );

    test('Post model handles multiple imageUrls correctly', () {
      const post = Post(
        id: 'p1',
        author: dummyUser,
        content: 'Post with multiple images',
        createdAt: '1h',
        imageUrl: 'fallback.jpg',
        imageUrls: ['img1.jpg', 'img2.jpg'],
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
      );

      expect(post.allImages.length, 2);
      expect(post.allImages.first, 'img1.jpg');
    });

    testWidgets(
      'CreatePostScreen allows selecting photo and displays preview',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CreatePostScreen(
              currentUser: dummyUser,
              onPickPhoto: () async => '/path/photo1.jpg',
              onPostCreated: (_, _, _, _, _) {},
            ),
          ),
        );

        await tester.tap(find.text('Chọn ảnh'));
        await tester.pumpAndSettle();

        expect(find.text('Đổi ảnh'), findsOneWidget);
        expect(find.text('Xóa ảnh'), findsOneWidget);
      },
    );
  });

  group('Feature 2: Chat Attachments', () {
    testWidgets(
      'ChatScreen displays attachment button and preview bar when picking attachment',
      (tester) async {
        final conversation = Conversation(
          id: 'c1',
          user: dummyUser,
          lastMessage: 'Hi',
          time: 'now',
          unreadCount: 0,
          messages: const [
            ChatMessage(
              id: 'm1',
              senderId: 'user_1',
              text: 'Here is the report',
              time: '12:00',
              attachments: [
                ChatAttachment(
                  id: 'att1',
                  type: 'file',
                  url: 'https://example.com/report.pdf',
                  name: 'report.pdf',
                  mimeType: 'application/pdf',
                  sizeBytes: 2048,
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              conversations: [conversation],
              conversationId: 'c1',
              currentUser: dummyUser,
              onSendMessage: (_, {attachmentPaths}) {},
              onPickAttachment: () async => '/tmp/doc.pdf',
            ),
          ),
        );

        // File attachment bubble
        expect(find.text('report.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);

        // Attachment picker button (paperclip)
        expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);

        // Tap paperclip to trigger attachment
        await tester.tap(find.byIcon(Icons.attach_file_rounded));
        await tester.pumpAndSettle();

        // Preview item is shown
        expect(find.text('doc.pdf'), findsOneWidget);
      },
    );
  });

  group('Feature 3: Follow / Unfollow / Counts / List', () {
    testWidgets(
      'ProfileScreen displays follower count, following count and follows-you badge',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProfileScreen(posts: [], user: dummyUser),
            ),
          ),
        );

        expect(find.text('15 người theo dõi'), findsOneWidget);
        expect(find.text('8 đang theo dõi'), findsOneWidget);
        expect(find.text('Theo dõi bạn'), findsOneWidget);
      },
    );

    testWidgets('UserProfileScreen shows Follow button when not following', (
      tester,
    ) async {
      final targetProfile = UserProfile(
        user: dummyUser.copyWith(isFollowing: false),
        friendship: Friendship.none,
        posts: const [],
        followersCount: 15,
        followingCount: 8,
      );

      var followCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(
            user: dummyUser,
            load: () async => targetProfile,
            onFollow: (id) async => followCalled = true,
            onUnfollow: (id) async {},
            onSendRequest: (_) async {},
            onAccept: (_) async {},
            onDeleteRequest: (_) async {},
            onUnfriend: (_) async {},
            onMessage: (_) async {},
            onReport: (_, _) async {},
            onBlock: (_) async {},
            onUnblock: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Theo dõi'), findsOneWidget);
      await tester.tap(find.text('Theo dõi'));
      await tester.pump();
      expect(followCalled, isTrue);
    });

    testWidgets(
      'FollowListSheet displays followers with pagination and toggle',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showFollowListSheet(
                    context,
                    title: 'Người theo dõi',
                    loadUsers: (cursor) async =>
                        const UserPage(users: [dummyUser]),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Người theo dõi'), findsOneWidget);
        expect(find.text('Long Nguyen'), findsOneWidget);
      },
    );
  });

  group('Feature 4: Online presence and typing indicators', () {
    testWidgets('UserAvatar displays green dot when isOnline is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              imageUrl: 'https://example.com/avatar.jpg',
              isOnline: true,
            ),
          ),
        ),
      );

      final greenDot = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFF2F9E6E),
      );
      expect(greenDot, findsOneWidget);
    });

    testWidgets(
      'ChatScreen shows typing indicator when isPartnerTyping is true',
      (tester) async {
        final conversation = Conversation(
          id: 'c1',
          user: dummyUser,
          lastMessage: 'Hi',
          time: 'now',
          unreadCount: 0,
          messages: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              conversations: [conversation],
              conversationId: 'c1',
              currentUser: dummyUser,
              isPartnerTyping: true,
              onSendMessage: (_, {attachmentPaths}) {},
            ),
          ),
        );

        expect(find.text('Long Nguyen đang soạn tin...'), findsOneWidget);
      },
    );

    testWidgets('EditProfileScreen includes show online status switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: EditProfileScreen(user: dummyUser)),
      );

      expect(find.text('Hiện trạng thái online'), findsOneWidget);
      expect(
        find.text('Cho phép bạn bè nhìn thấy khi bạn đang hoạt động'),
        findsOneWidget,
      );
    });
  });
}
