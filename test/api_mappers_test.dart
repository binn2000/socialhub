import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/models/message.dart';
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

  test('a story keeps when it was posted', () {
    final story = storyFromJson({
      'id': 's1',
      'author': _author(),
      'text': 'Xin chào',
      'imageUrl': null,
      'background': 'mint',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': DateTime.now().toUtc().toIso8601String(),
      'isViewed': false,
    });

    expect(story.time, 'Vừa xong');
    expect(story.copyWith(isViewed: true).time, 'Vừa xong');
  });

  test('cover and About come from the profile json', () {
    final user = userFromJson({
      ..._author(),
      'bio': null,
      'coverUrl': 'http://localhost:8000/storage/covers/c.jpg',
      'about': {
        'location': 'Hà Nội',
        'hometown': null,
        'workplace': 'SocialHub',
        'education': null,
        'website': 'https://example.com',
        'birthday': '1998-05-17',
      },
    }, absoluteUrl: (url) => url.replaceFirst('localhost', '10.0.2.2'));

    expect(user.coverUrl, 'http://10.0.2.2:8000/storage/covers/c.jpg');
    expect(user.about.location, 'Hà Nội');
    expect(user.about.hometown, '');
    expect(user.about.birthdayLabel, '17/05/1998');
    expect(user.about.isEmpty, isFalse);
    expect(userFromJson(_author()).about.isEmpty, isTrue);
    expect(userFromJson(_author()).coverUrl, '');
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

  test('a post carries my reaction and how many people used each one', () {
    final post = postFromJson({
      'id': 'p1',
      'author': _author(),
      'content': 'Xin chào',
      'imageUrl': null,
      'privacy': 'public',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'likes': 3,
      'comments': 0,
      'shares': 0,
      'isLiked': true,
      'myReaction': 'love',
      'reactionCounts': {'love': 2, 'sad': 1},
    });

    expect(post.reaction, 'love');
    expect(post.reactionCounts, {'love': 2, 'sad': 1});

    final plain = postFromJson({
      'id': 'p2',
      'author': _author(),
      'content': 'Không ai thả',
      'imageUrl': null,
      'privacy': 'public',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'likes': 0,
      'comments': 0,
      'shares': 0,
      'isLiked': false,
      'myReaction': null,
      'reactionCounts': <String, dynamic>{},
    });
    expect(plain.reaction, isNull);
    expect(plain.reactionCounts, isEmpty);
  });

  test('a like notification says what the person reacted with', () {
    Map<String, dynamic> like(String? reaction) => {
      'id': 'n1',
      'type': 'like',
      'actor': _author(),
      'isRead': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'postId': 'p1',
      'reaction': reaction,
      'commentId': null,
      'friendRequestId': null,
      'relatedContent': null,
    };

    expect(
      notificationFromJson(like('love')).description,
      'đã bày tỏ cảm xúc ❤️ về bài viết của bạn',
    );
    expect(
      notificationFromJson(like('haha')).description,
      'đã bày tỏ cảm xúc 😆 về bài viết của bạn',
    );
    // A plain like, an unknown reaction and no reaction keep the old text.
    for (final plain in ['like', 'something_new', null]) {
      expect(
        notificationFromJson(like(plain)).description,
        'đã thích bài viết của bạn',
      );
    }
    expect(notificationFromJson(like('angry')).type, 'like');
  });

  test('a message carries reactions and the recalled flag', () {
    final message = messageFromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderId': 'u1',
      'text': 'Xin chào',
      'isRecalled': false,
      'reactions': {'😂': 2, '😡': 1},
      'myReaction': '😂',
      'attachments': <Object>[],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    expect(message.reactions, {'😂': 2, '😡': 1});
    expect(message.myReaction, '😂');
    expect(message.isRecalled, isFalse);

    final recalled = message.withState(const MessageState(isRecalled: true));
    expect(recalled.text, '');
    expect(recalled.attachments, isEmpty);

    // A server that does not know reactions yet still parses.
    final old = messageFromJson({
      'id': 'm2',
      'conversationId': 'c1',
      'senderId': 'u1',
      'text': 'Cũ',
      'attachments': <Object>[],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    expect(old.reactions, isEmpty);
    expect(old.myReaction, isNull);
  });

  test('a conversation whose last message was recalled says so', () {
    final conversation = conversationFromJson({
      'id': 'c1',
      'participant': _author(),
      'lastMessage': {
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'text': '',
        'isRecalled': true,
        'reactions': <String, dynamic>{},
        'myReaction': null,
        'attachments': <Object>[],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
      'unreadCount': 0,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    expect(conversation.lastMessage, 'Tin nhắn đã được thu hồi');
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

  test('a post carries its video, with absolute URLs once it is ready', () {
    final post = postFromJson({
      'id': 'p1',
      'author': _author(),
      'content': '',
      'imageUrl': null,
      'video': {
        'status': 'ready',
        'url': 'http://localhost:8000/storage/videos/a.mp4',
        'thumbnailUrl': 'http://localhost:8000/storage/videos/a.jpg',
        'durationSeconds': 75,
        'width': 720,
        'height': 1280,
      },
      'feeling': null,
      'privacy': 'public',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'likes': 0,
      'comments': 0,
      'shares': 0,
      'isLiked': false,
    }, absoluteUrl: (url) => url.replaceFirst('localhost', '10.0.2.2'));

    final video = post.video!;
    expect(video.isReady, isTrue);
    expect(video.url, 'http://10.0.2.2:8000/storage/videos/a.mp4');
    expect(video.durationLabel, '1:15');
    expect(post.hasMedia, isTrue);
    expect(post.imageUrl, isNull);
  });

  test('a message with an attachment keeps its numeric id as text', () {
    final message = messageFromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderId': 'u1',
      'text': '',
      'attachments': [
        {
          'id': 1,
          'type': 'image',
          'url': 'http://localhost:8000/storage/chat/a.png',
          'name': '01.png',
          'mimeType': 'image/png',
          'sizeBytes': 1776532,
          'width': 720,
          'height': 1280,
        },
      ],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    expect(message.attachments.single.id, '1');
    expect(message.attachments.single.width, 720);
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
