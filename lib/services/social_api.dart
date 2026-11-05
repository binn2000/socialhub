import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/friend_request.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_note.dart';
import 'package:flutter_learning/models/user_profile.dart';

/// An error answered by the API (`{message, code, errors?}`), or a network
/// failure when [statusCode] is null.
class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final Map<String, List<String>> errors;

  const ApiException({
    this.statusCode,
    required this.code,
    required this.message,
    this.errors = const {},
  });

  bool get isUnauthenticated => statusCode == 401;

  /// The first field error if there is one, otherwise the general message.
  String get displayMessage {
    for (final messages in errors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// One page of posts plus where to continue.
class PostPage {
  final List<Post> posts;
  final String? nextCursor;
  final Set<String> savedPostIds;
  final Set<String> hiddenPostIds;

  const PostPage({
    required this.posts,
    this.nextCursor,
    this.savedPostIds = const {},
    this.hiddenPostIds = const {},
  });
}

/// What polling an open chat returns: new messages and whether the other
/// person is typing right now.
class MessagePoll {
  final List<ChatMessage> messages;
  final bool otherTyping;

  /// Reactions and recalls on messages that were already known.
  final Map<String, MessageState> states;

  /// The other person's delivered and read markers and the pinned message, when
  /// the server said them ([hasChatMeta]; the pin can be null on purpose).
  final bool hasChatMeta;
  final String? partnerDeliveredId;
  final String? partnerReadId;
  final ChatMessage? pinnedMessage;

  /// The shared bubble theme id, when the server said it.
  final String? theme;
  final String? quickReaction;

  const MessagePoll({
    this.messages = const [],
    this.otherTyping = false,
    this.states = const {},
    this.hasChatMeta = false,
    this.partnerDeliveredId,
    this.partnerReadId,
    this.pinnedMessage,
    this.theme,
    this.quickReaction,
  });
}

/// One page of the pictures or files shared in a conversation.
class MediaPage {
  final List<ChatAttachment> items;
  final String? nextCursor;

  const MediaPage({this.items = const [], this.nextCursor});
}

class NotificationPage {
  final List<SocialNotification> notifications;
  final String? nextCursor;

  const NotificationPage({required this.notifications, this.nextCursor});
}

/// One page of users (search or the plain list).
class UserPage {
  final List<UserModel> users;

  /// Users on this page the current user already sent a request to.
  final Set<String> pendingIds;
  final String? nextCursor;

  const UserPage({
    required this.users,
    this.pendingIds = const {},
    this.nextCursor,
  });
}

/// One photo of a profile's "Ảnh" tab (a post can have several).
class ProfilePhoto {
  final String postId;
  final String imageUrl;

  const ProfilePhoto({required this.postId, required this.imageUrl});
}

class PhotoPage {
  final List<ProfilePhoto> photos;
  final String? nextCursor;

  const PhotoPage({required this.photos, this.nextCursor});
}

/// Everything MainScreen shows, loaded in one go.
class AppSnapshot {
  final List<Post> posts;

  /// Posts that belong on Home. `null` means every post (the mock data has
  /// no separate Explore list); with the server, Home shows only the feed.
  final Set<String>? feedPostIds;
  final Set<String> savedPostIds;
  final Set<String> hiddenPostIds;
  final List<Story> stories;
  final List<UserModel> users;

  /// Users the current user already sent a friend request to.
  final Set<String> pendingFriendIds;
  final List<Conversation> conversations;
  final List<SocialNotification> notifications;

  /// Friend requests waiting for the current user's answer.
  final List<FriendRequest> friendRequests;

  /// Where to continue each list (null = no more, or the mock).
  final String? feedCursor;
  final String? exploreCursor;
  final String? notificationsCursor;
  final String? usersCursor;

  /// Unread notifications on the server, which can be more than the loaded
  /// page holds. Null on the mock (the app counts the loaded ones).
  final int? unreadNotificationCount;

  const AppSnapshot({
    required this.posts,
    this.feedPostIds,
    this.savedPostIds = const {},
    this.hiddenPostIds = const {},
    required this.stories,
    required this.users,
    this.pendingFriendIds = const {},
    required this.conversations,
    required this.notifications,
    this.friendRequests = const [],
    this.feedCursor,
    this.exploreCursor,
    this.notificationsCursor,
    this.usersCursor,
    this.unreadNotificationCount,
  });
}

/// Everything the app asks of a backend. [MockSocialApi] keeps the app working
/// offline with the seed data; [HttpSocialApi] talks to the Laravel API
/// described in docs/api/openapi.yaml.
abstract class SocialApi {
  /// True when data comes from a server (sign-in, loading and errors apply).
  bool get isRemote;

  /// Data and user that are available right away, without sign-in. Only the
  /// mock has them; a remote API returns null and is loaded with [load].
  AppSnapshot? get seed => null;
  UserModel? get seedUser => null;

  /// The user of a saved session, or null when nobody is signed in.
  Future<UserModel?> restoreSession();
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<void> logout();

  /// Registers this phone's push token for the signed-in user.
  Future<void> registerDevice(String token, String platform);

  /// Stops pushes to this phone (call before signing out).
  Future<void> unregisterDevice(String token);

  /// Sends a 6-digit code to the signed-in user's email.
  Future<void> requestEmailVerification();

  /// Confirms the email with the code from the mail.
  Future<void> verifyEmail(String code);

  /// Mails a reset code. The answer is the same for unknown addresses.
  Future<void> requestPasswordReset(String email);

  /// Sets a new password with the mailed code; every session is signed out.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  });

  /// Deletes the signed-in account after re-checking its password.
  Future<void> deleteAccount(String password);

  Future<AppSnapshot> load(UserModel me);

  /// The next pages of the lists [load] started (server only).
  Future<PostPage> loadMoreFeed(String cursor);
  Future<PostPage> loadMoreExplore(String cursor);

  /// A page of one feed tab: `friends`, `following` or `popular` (the plain
  /// feed is [load] and [loadMoreFeed]). [cursor] is null for the first page.
  Future<PostPage> loadFeedFilter(String filter, {String? cursor});
  Future<NotificationPage> loadMoreNotifications(String cursor);

  /// A page of notifications of one [category] (`interactions` or
  /// `friends`); [cursor] is null for the first page.
  Future<NotificationPage> loadNotificationCategory(
    String category, {
    String? cursor,
  });

  /// Users matching [query] (name or username); an empty query lists everyone.
  Future<UserPage> searchUsers({String query = '', String? cursor});

  /// Each create call takes the object the app already built locally and
  /// returns the stored version (with the server's id and time).
  Future<Post> createPost(Post draft);
  Future<Story> createStory(Story draft);

  /// Deletes one of the current user's own stories.
  Future<void> deleteStory(String storyId);

  /// Changes who can see one of my stories. [privacy] is the API value
  /// (`public`, `friends`, `only_me`).
  Future<void> updateStoryPrivacy(String storyId, String privacy);

  /// The stories of one person that the current user may open (from their
  /// profile).
  Future<List<Story>> loadUserStories(String userId);

  /// The current user's note and their friends' notes, mine first.
  Future<List<UserNote>> loadNotes();

  /// Shares [text] (and optionally a song) as the current user's note,
  /// replacing the old one. The text may be empty when there is a song.
  /// [privacy] is the API value; null keeps the old note's (friends if new).
  Future<UserNote> setNote(String text, {MusicTrack? track, String? privacy});

  /// Songs matching [query] from Apple Music, each with a 30-second preview.
  Future<List<MusicTrack>> searchMusic(String query);

  Future<void> deleteNote();
  Future<ChatMessage> sendMessage(
    String conversationId,
    ChatMessage draft, {
    List<String>? attachmentPaths,
  });

  Future<void> deletePost(String postId);

  /// Changes who can see one of our own posts. [privacy] is the API value
  /// (`public`, `friends`, `only_me`).
  Future<void> updatePostPrivacy(String postId, String privacy);

  /// Reports a post, comment or user ([targetType] is `post`, `comment` or
  /// `user`). Reporting the same target again is accepted.
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  });

  /// Blocking also ends any friendship; both people vanish from each other.
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<List<UserModel>> loadBlockedUsers();

  /// One post, for opening it from a notification.
  Future<Post> loadPost(String postId);

  Future<void> markStoryViewed(String storyId);

  /// The posts the current user saved, most recently saved first.
  Future<List<Post>> loadSavedPosts();

  Future<void> setLiked(String postId, bool liked, {String? reaction});
  Future<void> setSaved(String postId, bool saved);
  Future<void> setHidden(String postId, bool hidden);
  Future<void> sendFriendRequest(String userId);

  /// Accepts a request sent to us and returns the new friend.
  Future<UserModel> acceptFriendRequest(String requestId);

  /// Declines a request sent to us, or cancels one we sent.
  Future<void> deleteFriendRequest(String requestId);
  Future<void> unfriend(String userId);

  Future<List<Comment>> loadComments(String postId);
  Future<({Comment comment, int commentsCount})> addComment(
    String postId,
    String text,
  );
  Future<void> deleteComment(String commentId);

  /// Records that the current user shared a post ([target] is `link` or
  /// `message`) and returns the post's share count.
  Future<int> sharePost(String postId, String target);

  Future<UserProfile> loadProfile(String userId);

  /// The messages of a conversation, oldest first, or null to keep the ones
  /// the app already has.
  Future<List<ChatMessage>?> loadMessages(String conversationId);

  /// Messages newer than [afterMessageId] (oldest first), for polling an open
  /// chat. With no id, the latest messages.
  Future<MessagePoll> loadNewMessages(
    String conversationId, {
    String? afterMessageId,
  });

  /// Sets my reaction on a message (null takes it back); answers the message.
  /// The mock app has no reactions on the server and does nothing.
  Future<ChatMessage?> reactToMessage(
    String conversationId,
    String messageId,
    String? emoji,
  ) async => null;

  /// Pins a message for both people (null from the mock app) or removes the pin.
  Future<ChatMessage?> pinMessage(
    String conversationId,
    String messageId,
  ) async => null;

  Future<void> unpinMessage(String conversationId) async {}

  /// Chooses the bubble theme for both people (server only).
  Future<void> setConversationTheme(
    String conversationId,
    String theme,
  ) async {}

  /// Chooses the emoji of the quick send button for both people (server only).
  Future<void> setQuickReaction(String conversationId, String emoji) async {}

  /// Every picture ([images] true) or document of a conversation, newest first,
  /// paged (server only; the mock app has no such list).
  Future<MediaPage> loadConversationMedia(
    String conversationId, {
    required bool images,
    String? cursor,
  }) async => const MediaPage();

  /// "Thu hồi": takes my message back for both people.
  Future<ChatMessage?> recallMessage(
    String conversationId,
    String messageId,
  ) async => null;

  /// "Xóa ở phía tôi": hides a message from me only.
  Future<void> hideMessage(String conversationId, String messageId) async {}

  /// The conversation list again (without messages), for polling the
  /// Messages screen.
  Future<List<Conversation>> loadConversations();

  /// Conversations whose other person's name or username contains [query]
  /// (without messages), including old ones that were not loaded.
  Future<List<Conversation>> searchConversations(String query);

  /// The conversation with a friend: the existing one, or a new empty one.
  Future<Conversation> startConversation(UserModel friend);
  Future<void> markConversationRead(String conversationId);
  Future<void> markAllNotificationsRead();

  Future<UserModel> updateProfile(UserModel user);
  Future<UserModel> uploadAvatar(String filePath);

  /// Uploads the profile cover image and returns the updated user.
  Future<UserModel> uploadCover(String filePath);

  /// The photos of a user's posts, newest first, for the profile "Ảnh" tab.
  Future<PhotoPage> loadUserPhotos(String userId, {String? cursor});

  /// The friends of a user, for the profile "Bạn bè" tab.
  Future<UserPage> loadUserFriends(String userId, {String? cursor});

  /// People the user may know, most friends in common first.
  Future<UserPage> loadSuggestions({String? cursor});

  /// Follow & Unfollow.
  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);
  Future<UserPage> loadFollowers(String userId, {String? cursor});
  Future<UserPage> loadFollowing(String userId, {String? cursor});

  /// Presence & Typing.
  Future<void> sendPresence();
  Future<void> sendTyping(String conversationId);
  Future<void> stopTyping(String conversationId);
  Future<UserModel> setShowOnlineStatus(bool show);
}
