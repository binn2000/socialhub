import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/services/api_mappers.dart';

Map<String, dynamic> _author({String? avatarUrl}) => {
  'id': 'u1',
  'name': 'Minh Ánh',
  'username': 'minh_anh',
  'avatarUrl': avatarUrl,
};

void main() {
  test('a user summary becomes a UserModel with an @username', () {
    final user = userFromJson(_author());

    expect(user.username, '@minh_anh');
    expect(user.avatarUrl, '');
    expect(user.isFriend, isFalse);
  });

  test('Me is the current user: friendsCount fills mutualFriends', () {
    final user = userFromJson({
      ..._author(),
      'email': 'a@b.vn',
      'bio': 'Hello',
      'friendsCount': 7,
    });

    expect(user.bio, 'Hello');
    expect(user.mutualFriends, 7);
    expect(user.isFriend, isTrue);
  });

  test('emailVerified defaults to true and follows Me', () {
    expect(userFromJson(_author()).emailVerified, isTrue);
    expect(
      userFromJson({
        ..._author(),
        'email': 'a@b.vn',
        'emailVerified': false,
      }).emailVerified,
      isFalse,
    );
  });

  test('a list item knows if the user is a friend', () {
    final user = userFromJson({
      ..._author(),
      'mutualFriendsCount': 3,
      'friendship': {'status': 'friends', 'requestId': null},
    });

    expect(user.isFriend, isTrue);
    expect(user.mutualFriends, 3);
  });

  test('avatar urls pass through the url rewriter', () {
    final user = userFromJson(
      _author(avatarUrl: 'http://localhost:8000/storage/a.png'),
      absoluteUrl: (url) => url.replaceFirst('localhost', '10.0.2.2'),
    );

    expect(user.avatarUrl, 'http://10.0.2.2:8000/storage/a.png');
  });

  test('a post gets Vietnamese labels for privacy and feeling', () {
    final post = postFromJson({
      'id': 'p1',
      'author': _author(),
      'content': 'Xin chào',
      'imageUrl': null,
      'feeling': 'excited',
      'privacy': 'only_me',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'likes': 4,
      'comments': 2,
      'shares': 1,
      'isLiked': true,
      'isSaved': false,
      'isHidden': false,
    });

    expect(post.feeling, 'Hứng thú');
    expect(post.privacy, 'Chỉ mình tôi');
    expect(post.createdAt, 'Vừa xong');
    expect(post.isLiked, isTrue);
    expect(post.imageUrl, isNull);
  });

  test('labels convert back to the identifiers the API expects', () {
    expect(privacyValue('Bạn bè'), 'friends');
    expect(privacyValue('unknown'), isNull);
    expect(feelingValue('Hạnh phúc'), 'happy');
    expect(feelingValue(null), isNull);
  });

  test('story backgrounds map to gradients and back', () {
    for (final background in storyBackgrounds) {
      expect(storyBackgroundFor(storyGradient(background)), background);
    }
    expect(storyGradient('nonsense').first, const Color(0xFF5D6BFF));
  });

  test('notifications get text, icon and kind from their type', () {
    Map<String, dynamic> json(String type) => {
      'id': 'n1',
      'type': type,
      'actor': _author(),
      'isRead': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'relatedContent': 'bài viết',
      'postId': type.startsWith('friend') ? null : 'p7',
    };

    final like = notificationFromJson(json('like'));
    expect(like.type, 'like');
    expect(like.description, 'đã thích bài viết của bạn');
    expect(like.relatedContent, 'bài viết');
    expect(like.postId, 'p7');
    expect(notificationFromJson(json('friend_request')).postId, isNull);
    expect(notificationFromJson(json('friend_request')).type, 'friend');
    expect(
      notificationFromJson(json('friend_accepted')).description,
      contains('chấp nhận'),
    );
  });

  test('a conversation carries the last message and unread count', () {
    final conversation = conversationFromJson({
      'id': 'c1',
      'participant': _author(),
      'lastMessage': {
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'text': 'Chào bạn!',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
      'unreadCount': 2,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    expect(conversation.lastMessage, 'Chào bạn!');
    expect(conversation.unreadCount, 2);
    expect(conversation.messages, isEmpty);
  });

  test('a comment keeps its post and a relative time', () {
    final comment = commentFromJson({
      'id': 'c1',
      'postId': 'p1',
      'author': _author(),
      'content': 'Hay quá!',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    expect(comment.postId, 'p1');
    expect(comment.author.name, 'Minh Ánh');
    expect(comment.time, 'Vừa xong');
  });

  test('a friend request has the sender', () {
    final request = friendRequestFromJson({
      'id': 'r1',
      'sender': _author(),
      'receiver': {..._author(), 'id': 'me'},
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    expect(request.id, 'r1');
    expect(request.sender.id, 'u1');
  });

  test('friendship statuses map to the enum', () {
    expect(friendshipFromJson('friends'), Friendship.friends);
    expect(friendshipFromJson('pending_outgoing'), Friendship.pendingOutgoing);
    expect(friendshipFromJson('pending_incoming'), Friendship.pendingIncoming);
    expect(friendshipFromJson('self'), Friendship.self);
    expect(friendshipFromJson('none'), Friendship.none);
    expect(friendshipFromJson(null), Friendship.none);
  });
}
