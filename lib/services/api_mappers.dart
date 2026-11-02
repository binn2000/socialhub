import 'package:flutter/material.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/friend_request.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/utils/time_ago.dart';

// Turns the API's JSON (docs/api/openapi.yaml) into the app's models, and
// translates the identifiers the API uses into the Vietnamese labels the UI
// shows.

typedef Json = Map<String, dynamic>;

const _privacyLabels = {
  'public': 'Công khai',
  'friends': 'Bạn bè',
  'only_me': 'Chỉ mình tôi',
};
const _feelingLabels = {
  'cheerful': 'Cảm thấy vui',
  'excited': 'Hứng thú',
  'happy': 'Hạnh phúc',
};

/// The story gradients of StoryCreatorScreen, in the same order as the API's
/// `background` values.
const storyBackgrounds = ['indigo', 'sunset', 'mint', 'berry'];
const _storyGradients = [
  [Color(0xFF5D6BFF), Color(0xFF9B8CFF)],
  [Color(0xFFFF7043), Color(0xFFFFC107)],
  [Color(0xFF00B894), Color(0xFF26C6DA)],
  [Color(0xFFE84393), Color(0xFF6C5CE7)],
];

const _accentColors = [
  Color(0xFF5D6BFF),
  Color(0xFF00B894),
  Color(0xFF6C5CE7),
  Color(0xFFFF7675),
  Color(0xFF2ECC71),
  Color(0xFFF39C12),
];

String privacyLabel(String? apiValue) =>
    _privacyLabels[apiValue] ?? _privacyLabels['public']!;

String? privacyValue(String? label) => _privacyLabels.entries
    .where((entry) => entry.value == label)
    .map((entry) => entry.key)
    .firstOrNull;

String? feelingLabel(String? apiValue) => _feelingLabels[apiValue];

String? feelingValue(String? label) => _feelingLabels.entries
    .where((entry) => entry.value == label)
    .map((entry) => entry.key)
    .firstOrNull;

List<Color> storyGradient(String? background) {
  final index = storyBackgrounds.indexOf(background ?? '');
  return _storyGradients[index == -1 ? 0 : index];
}

String storyBackgroundFor(List<Color> gradient) {
  final index = _storyGradients.indexWhere(
    (colors) => colors.first == gradient.first,
  );
  return storyBackgrounds[index == -1 ? 0 : index];
}

Color _accentFor(String id) =>
    _accentColors[id.codeUnits.fold<int>(0, (sum, c) => sum + c) %
        _accentColors.length];

String _urlOrEmpty(String? url, String Function(String)? absoluteUrl) =>
    url == null ? '' : (absoluteUrl == null ? url : absoluteUrl(url));

UserAbout _aboutFromJson(Json? json) {
  if (json == null) return UserAbout.empty;
  String text(String key) => (json[key] as String?) ?? '';
  return UserAbout(
    location: text('location'),
    hometown: text('hometown'),
    workplace: text('workplace'),
    education: text('education'),
    website: text('website'),
    birthday: text('birthday'),
  );
}

/// A UserSummary (or a UserListItem / UserProfile / Me, which extend it).
/// [absoluteUrl] makes the avatar URL loadable from this device.
UserModel userFromJson(Json json, {String Function(String)? absoluteUrl}) {
  final id = json['id'] as String;
  final avatarUrl = json['avatarUrl'] as String?;
  final isSelf = json['email'] != null; // only Me carries the email
  return UserModel(
    id: id,
    name: json['name'] as String,
    username: '@${json['username']}',
    avatarUrl: avatarUrl == null
        ? ''
        : (absoluteUrl == null ? avatarUrl : absoluteUrl(avatarUrl)),
    coverUrl: _urlOrEmpty(json['coverUrl'] as String?, absoluteUrl),
    bio: (json['bio'] as String?) ?? '',
    // The mock model used this number for the friends count on Profile.
    mutualFriends:
        (json['friendsCount'] ?? json['mutualFriendsCount'] ?? 0) as int,
    isFriend: isSelf || (json['friendship'] as Json?)?['status'] == 'friends',
    accentColor: _accentFor(id),
    emailVerified: (json['emailVerified'] as bool?) ?? true,
    about: _aboutFromJson(json['about'] as Json?),
    isOnline: (json['isOnline'] as bool?) ?? false,
    lastSeenAt: json['lastSeenAt'] != null
        ? timeAgo(json['lastSeenAt'] as String)
        : null,
    showOnlineStatus: (json['showOnlineStatus'] as bool?) ?? true,
    followersCount: (json['followersCount'] as int?) ?? 0,
    followingCount: (json['followingCount'] as int?) ?? 0,
    isFollowing: (json['isFollowing'] as bool?) ?? false,
    followsYou: (json['followsYou'] as bool?) ?? false,
  );
}

Post postFromJson(Json json, {String Function(String)? absoluteUrl}) {
  final imageUrl = json['imageUrl'] as String?;
  final rawUrls = json['imageUrls'] as List<dynamic>?;
  final imageUrls = rawUrls != null
      ? [
          for (final u in rawUrls)
            if (u is String) (absoluteUrl == null ? u : absoluteUrl(u)),
        ]
      : const <String>[];
  return Post(
    id: json['id'] as String,
    author: userFromJson(json['author'] as Json, absoluteUrl: absoluteUrl),
    content: json['content'] as String,
    imageUrl: imageUrl == null
        ? null
        : (absoluteUrl == null ? imageUrl : absoluteUrl(imageUrl)),
    imageUrls: imageUrls,
    feeling: feelingLabel(json['feeling'] as String?),
    privacy: privacyLabel(json['privacy'] as String?),
    createdAt: timeAgo(json['createdAt'] as String),
    likes: json['likes'] as int,
    comments: json['comments'] as int,
    shares: json['shares'] as int,
    isLiked: json['isLiked'] as bool,
  );
}

Story storyFromJson(Json json, {String Function(String)? absoluteUrl}) {
  final imageUrl = json['imageUrl'] as String?;
  return Story(
    id: json['id'] as String,
    user: userFromJson(json['author'] as Json, absoluteUrl: absoluteUrl),
    imageUrl: imageUrl == null
        ? null
        : (absoluteUrl == null ? imageUrl : absoluteUrl(imageUrl)),
    text: json['text'] as String?,
    isViewed: json['isViewed'] as bool,
    gradientColors: storyGradient(json['background'] as String?),
  );
}

ChatAttachment attachmentFromJson(
  Json json, {
  String Function(String)? absoluteUrl,
}) {
  final url = json['url'] as String;
  return ChatAttachment(
    id: json['id'] as String,
    type: json['type'] as String,
    url: absoluteUrl == null ? url : absoluteUrl(url),
    name: json['name'] as String,
    mimeType: json['mimeType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    width: json['width'] as int?,
    height: json['height'] as int?,
  );
}

ChatMessage messageFromJson(Json json, {String Function(String)? absoluteUrl}) {
  final rawAttachments = json['attachments'] as List<dynamic>?;
  return ChatMessage(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
    time: timeAgo(json['createdAt'] as String),
    attachments: rawAttachments != null
        ? [
            for (final a in rawAttachments)
              if (a is Json) attachmentFromJson(a, absoluteUrl: absoluteUrl),
          ]
        : const [],
  );
}

/// A conversation without its messages (they are loaded when it is opened).
Conversation conversationFromJson(
  Json json, {
  String Function(String)? absoluteUrl,
}) {
  final last = json['lastMessage'] as Json?;
  return Conversation(
    id: json['id'] as String,
    user: userFromJson(json['participant'] as Json, absoluteUrl: absoluteUrl),
    lastMessage: (last?['text'] as String?) ?? '',
    time: timeAgo((last?['createdAt'] ?? json['updatedAt']) as String),
    unreadCount: json['unreadCount'] as int,
    messages: const [],
  );
}

SocialNotification notificationFromJson(
  Json json, {
  String Function(String)? absoluteUrl,
}) {
  final type = json['type'] as String;
  // The app has one 'friend' kind for both friend notifications.
  final (kind, description, icon, color) = switch (type) {
    'like' => (
      'like',
      'đã thích bài viết của bạn',
      Icons.favorite_rounded,
      const Color(0xFFE91E63),
    ),
    'comment' => (
      'comment',
      'đã bình luận trong bài viết của bạn',
      Icons.chat_bubble_rounded,
      const Color(0xFF5D6BFF),
    ),
    'share' => (
      'share',
      'đã chia sẻ bài viết của bạn',
      Icons.share_rounded,
      const Color(0xFF6C5CE7),
    ),
    'friend_accepted' => (
      'friend',
      'đã chấp nhận lời mời kết bạn của bạn',
      Icons.person_add_alt_rounded,
      const Color(0xFF2ECC71),
    ),
    'follow' => (
      'friend',
      'đã bắt đầu theo dõi bạn',
      Icons.person_add_alt_rounded,
      const Color(0xFF2ECC71),
    ),
    _ => (
      'friend',
      'đã gửi lời mời kết bạn',
      Icons.person_add_alt_rounded,
      const Color(0xFF2ECC71),
    ),
  };

  return SocialNotification(
    id: json['id'] as String,
    actor: userFromJson(json['actor'] as Json, absoluteUrl: absoluteUrl),
    description: description,
    time: timeAgo(json['createdAt'] as String),
    type: kind,
    icon: icon,
    iconColor: color,
    isRead: json['isRead'] as bool,
    relatedContent: json['relatedContent'] as String?,
    postId: json['postId'] as String?,
  );
}

Comment commentFromJson(Json json, {String Function(String)? absoluteUrl}) =>
    Comment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      author: userFromJson(json['author'] as Json, absoluteUrl: absoluteUrl),
      content: json['content'] as String,
      time: timeAgo(json['createdAt'] as String),
    );

FriendRequest friendRequestFromJson(
  Json json, {
  String Function(String)? absoluteUrl,
}) => FriendRequest(
  id: json['id'] as String,
  sender: userFromJson(json['sender'] as Json, absoluteUrl: absoluteUrl),
  time: timeAgo(json['createdAt'] as String),
);

Friendship friendshipFromJson(String? status) => switch (status) {
  'friends' => Friendship.friends,
  'pending_outgoing' => Friendship.pendingOutgoing,
  'pending_incoming' => Friendship.pendingIncoming,
  'self' => Friendship.self,
  _ => Friendship.none,
};
