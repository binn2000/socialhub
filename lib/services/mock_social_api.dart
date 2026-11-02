import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_note.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/services/social_api.dart';

/// The offline backend: the seed data from mock_data.dart, no sign-in, and
/// every change simply succeeds (MainScreen already holds the new state).
class MockSocialApi extends SocialApi {
  @override
  bool get isRemote => false;

  // MainScreen copies these lists once, so the mock*/seed lists are never
  // changed.
  @override
  AppSnapshot get seed => AppSnapshot(
    posts: List<Post>.from(mockPosts),
    stories: List<Story>.from(mockStories),
    users: List<UserModel>.from(mockUsers),
    conversations: List.of(mockConversations),
    notifications: List.of(mockNotifications),
  );

  @override
  UserModel get seedUser => currentUser;

  @override
  Future<UserModel?> restoreSession() async => currentUser;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async => currentUser;

  @override
  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async => currentUser;

  @override
  Future<void> logout() async {}

  @override
  Future<void> registerDevice(String token, String platform) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  // The offline app has no email, password or account to manage.
  @override
  Future<void> requestEmailVerification() async {}

  @override
  Future<void> verifyEmail(String code) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {}

  @override
  Future<void> deleteAccount(String password) async {}

  @override
  Future<AppSnapshot> load(UserModel me) async => seed;

  // The mock loads everything at once; there is never a next page.
  @override
  Future<PostPage> loadMoreFeed(String cursor) async =>
      const PostPage(posts: []);

  @override
  Future<PostPage> loadMoreExplore(String cursor) async =>
      const PostPage(posts: []);

  @override
  Future<NotificationPage> loadNotificationCategory(
    String category, {
    String? cursor,
  }) async => const NotificationPage(notifications: []);

  @override
  Future<List<Conversation>> searchConversations(String query) async =>
      const [];

  @override
  Future<void> deleteStory(String storyId) async {}

  @override
  Future<void> updateStoryPrivacy(String storyId, String privacy) async {}

  @override
  Future<List<Story>> loadUserStories(String userId) async => const [];

  // Notes need a server; the mock app does not show them.
  @override
  Future<List<UserNote>> loadNotes() async => const [];

  @override
  Future<UserNote> setNote(
    String text, {
    MusicTrack? track,
    String? privacy,
  }) async => UserNote(user: currentUser, text: text, track: track);

  @override
  Future<List<MusicTrack>> searchMusic(String query) async => const [];

  @override
  Future<void> deleteNote() async {}

  @override
  Future<NotificationPage> loadMoreNotifications(String cursor) async =>
      const NotificationPage(notifications: []);

  @override
  Future<UserPage> searchUsers({String query = '', String? cursor}) async {
    final needle = query.trim().toLowerCase();
    return UserPage(
      users: [
        for (final user in mockUsers)
          if (user.id != currentUser.id &&
              user.name.toLowerCase().contains(needle))
            user,
      ],
    );
  }

  @override
  Future<Post> createPost(Post draft) async => draft;

  @override
  Future<Story> createStory(Story draft) async => draft;

  @override
  Future<ChatMessage> sendMessage(
    String conversationId,
    ChatMessage draft, {
    List<String>? attachmentPaths,
  }) async => draft;

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<Post> loadPost(String postId) async =>
      mockPosts.firstWhere((post) => post.id == postId);

  @override
  Future<void> markStoryViewed(String storyId) async {}

  // The mock app lists saved posts from the ids it keeps itself.
  @override
  Future<List<Post>> loadSavedPosts() async => const [];

  @override
  Future<void> setLiked(String postId, bool liked) async {}

  @override
  Future<void> setSaved(String postId, bool saved) async {}

  @override
  Future<void> setHidden(String postId, bool hidden) async {}

  @override
  Future<void> sendFriendRequest(String userId) async {}

  @override
  Future<UserModel> acceptFriendRequest(String requestId) async => currentUser;

  @override
  Future<void> deleteFriendRequest(String requestId) async {}

  @override
  Future<void> unfriend(String userId) async {}

  // The mock app keeps its session-only comment and share behaviour in the
  // UI, so these are only here to satisfy the interface.
  @override
  Future<List<Comment>> loadComments(String postId) async => const [];

  @override
  Future<({Comment comment, int commentsCount})> addComment(
    String postId,
    String text,
  ) async => (
    comment: Comment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      author: currentUser,
      content: text,
      time: 'Vừa xong',
    ),
    commentsCount: 1,
  );

  @override
  Future<void> deleteComment(String commentId) async {}

  @override
  Future<int> sharePost(String postId, String target) async => 0;

  @override
  Future<UserProfile> loadProfile(String userId) async {
    final user = mockUsers.firstWhere((user) => user.id == userId);
    return UserProfile(
      user: user,
      friendship: user.id == currentUser.id
          ? Friendship.self
          : user.isFriend
          ? Friendship.friends
          : Friendship.none,
      posts: mockPosts.where((post) => post.author.id == userId).toList(),
    );
  }

  @override
  Future<List<ChatMessage>?> loadMessages(String conversationId) async => null;

  // The mock has nobody else sending messages, so there is nothing new.
  @override
  Future<MessagePoll> loadNewMessages(
    String conversationId, {
    String? afterMessageId,
  }) async => const MessagePoll();

  @override
  Future<PostPage> loadFeedFilter(String filter, {String? cursor}) async =>
      const PostPage(posts: []);

  @override
  Future<List<Conversation>> loadConversations() async =>
      List.of(mockConversations);

  @override
  Future<Conversation> startConversation(UserModel friend) async =>
      Conversation(
        id: 'conversation_${friend.id}',
        user: friend,
        lastMessage: '',
        time: '',
        unreadCount: 0,
        messages: const [],
      );

  // Reporting, blocking and post privacy need a server.
  @override
  Future<void> updatePostPrivacy(String postId, String privacy) async {}

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {}

  @override
  Future<void> blockUser(String userId) async {}

  @override
  Future<void> unblockUser(String userId) async {}

  @override
  Future<List<UserModel>> loadBlockedUsers() async => const [];

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<UserModel> updateProfile(UserModel user) async => user;

  @override
  Future<UserModel> uploadAvatar(String filePath) async => currentUser;

  // Covers, photo and friend lists of other people and suggestions need a server.
  @override
  Future<UserModel> uploadCover(String filePath) async => currentUser;

  @override
  Future<PhotoPage> loadUserPhotos(String userId, {String? cursor}) async =>
      const PhotoPage(photos: []);

  @override
  Future<UserPage> loadUserFriends(String userId, {String? cursor}) async =>
      const UserPage(users: []);

  @override
  Future<UserPage> loadSuggestions({String? cursor}) async =>
      const UserPage(users: []);

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<void> unfollowUser(String userId) async {}

  @override
  Future<UserPage> loadFollowers(String userId, {String? cursor}) async =>
      const UserPage(users: []);

  @override
  Future<UserPage> loadFollowing(String userId, {String? cursor}) async =>
      const UserPage(users: []);

  @override
  Future<void> sendPresence() async {}

  @override
  Future<void> sendTyping(String conversationId) async {}

  @override
  Future<void> stopTyping(String conversationId) async {}

  @override
  Future<UserModel> setShowOnlineStatus(bool show) async =>
      currentUser.copyWith(showOnlineStatus: show);
}
