import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/main.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/friend_request.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/services/push_service.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/comments_sheet.dart';
import 'package:flutter_learning/widgets/story_item.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

import 'test_helpers.dart';

const _me = UserModel(
  id: 'me',
  name: 'Minh Ánh',
  username: '@minh_anh',
  avatarUrl: '',
  coverUrl: '',
  bio: 'Designer',
  mutualFriends: 1,
  isFriend: true,
  accentColor: Color(0xFF5D6BFF),
);
const _lan = UserModel(
  id: 'lan',
  name: 'Lan Hương',
  username: '@lan',
  avatarUrl: '',
  coverUrl: '',
  bio: '',
  mutualFriends: 0,
  isFriend: true,
  accentColor: Color(0xFF00B894),
);
const _khang = UserModel(
  id: 'khang',
  name: 'Duy Khang',
  username: '@khang',
  avatarUrl: '',
  coverUrl: '',
  bio: '',
  mutualFriends: 0,
  isFriend: false,
  accentColor: Color(0xFF6C5CE7),
);

Post _post(
  String id,
  String content, {
  String privacy = 'Công khai',
  int comments = 0,
}) => Post(
  id: id,
  author: _lan,
  content: content,
  privacy: privacy,
  createdAt: '1 giờ trước',
  likes: 3,
  comments: comments,
  shares: 0,
  isLiked: false,
);

/// A server stand-in: records what the app asks for and can be told to fail.
class _FakeRemoteApi extends SocialApi {
  UserModel? sessionUser;
  ApiException? loginError;
  ApiException? loadError;
  ApiException? likeError;
  final loginCalls = <String>[];
  final likes = <String, bool>{};
  final createdPosts = <Post>[];
  final createdStories = <Story>[];
  final friendRequests = <String>[];
  var logouts = 0;

  _FakeRemoteApi({this.sessionUser});

  @override
  bool get isRemote => true;

  @override
  Future<UserModel?> restoreSession() async => sessionUser;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    loginCalls.add('$email|$password');
    if (loginError != null) throw loginError!;
    return _me;
  }

  @override
  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async => _me;

  @override
  Future<void> logout() async => logouts++;

  UserModel? meOverride;
  final reports = <String>[];
  final blocked = <String>[];
  final unblocked = <String>[];
  final privacyChanges = <String>[];
  ApiException? moderationError;
  List<UserModel> blockedUsers = [];

  @override
  Future<void> updatePostPrivacy(String postId, String privacy) async {
    if (moderationError != null) throw moderationError!;
    privacyChanges.add('$postId:$privacy');
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    if (moderationError != null) throw moderationError!;
    reports.add('$targetType:$targetId:$reason:${details ?? ''}');
  }

  @override
  Future<void> blockUser(String userId) async {
    if (moderationError != null) throw moderationError!;
    blocked.add(userId);
  }

  @override
  Future<void> unblockUser(String userId) async => unblocked.add(userId);

  @override
  Future<List<UserModel>> loadBlockedUsers() async => blockedUsers;

  final devices = <String>[];
  final postsLoaded = <String>[];

  @override
  Future<void> registerDevice(String token, String platform) async =>
      devices.add('+$token|$platform');

  @override
  Future<void> unregisterDevice(String token) async => devices.add('-$token');
  String? feedCursor, exploreCursor, notificationsCursor, usersCursor;
  var feedPages = <PostPage>[];
  var explorePages = <PostPage>[];
  var notificationPages = <NotificationPage>[];
  var userPages = <UserPage>[];
  final searches = <String>[];
  Map<String, UserPage> searchResults = {};
  final moreCalls = <String>[];
  ApiException? moreError;

  @override
  Future<PostPage> loadMoreFeed(String cursor) async {
    moreCalls.add('feed:$cursor');
    if (moreError != null) throw moreError!;
    return feedPages.removeAt(0);
  }

  @override
  Future<PostPage> loadMoreExplore(String cursor) async {
    moreCalls.add('explore:$cursor');
    return explorePages.removeAt(0);
  }

  @override
  Future<NotificationPage> loadMoreNotifications(String cursor) async {
    moreCalls.add('notifications:$cursor');
    return notificationPages.removeAt(0);
  }

  @override
  Future<UserPage> searchUsers({String query = '', String? cursor}) async {
    searches.add('$query|${cursor ?? ''}');
    if (query.isEmpty) return userPages.removeAt(0);
    return searchResults[query] ?? const UserPage(users: []);
  }

  final startedWith = <String>[];
  ApiException? startError;

  @override
  Future<Conversation> startConversation(UserModel friend) async {
    startedWith.add(friend.id);
    if (startError != null) throw startError!;
    return Conversation(
      id: 'conv_${friend.id}',
      user: friend,
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );
  }

  ApiException? accountError;
  final accountCalls = <String>[];

  @override
  Future<void> requestEmailVerification() async =>
      accountCalls.add('request-verification');

  @override
  Future<void> verifyEmail(String code) async {
    accountCalls.add('verify:$code');
    if (accountError != null) throw accountError!;
  }

  @override
  Future<void> requestPasswordReset(String email) async =>
      accountCalls.add('forgot:$email');

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    accountCalls.add('reset:$email|$code|$password');
    if (accountError != null) throw accountError!;
  }

  @override
  Future<void> deleteAccount(String password) async {
    accountCalls.add('delete:$password');
    if (accountError != null) throw accountError!;
  }

  @override
  Future<AppSnapshot> load(UserModel me) async {
    loadCalls++;
    if (loadCalls > 1 && loadFailure != null) throw loadFailure!;
    if (loadError != null) throw loadError!;
    return AppSnapshot(
      posts: [
        _post(
          'p1',
          'Bài trên bảng tin',
          comments: commentsByPost['p1']?.length ?? 0,
        ),
        _post('p2', 'Bài chỉ có trong Explore'),
        _post('p3', 'Bài chỉ bạn bè', privacy: 'Bạn bè'),
        ...extraPosts,
      ].where((p) => !blocked.contains(p.author.id)).toList(),
      feedPostIds: {'p1', 'p3', ...extraPosts.map((p) => p.id)},
      stories: stories,
      users: [me, _lan, _khang],
      conversations: List.of(conversations),
      notifications: notifications,
      friendRequests: incomingRequests,
      feedCursor: feedCursor,
      exploreCursor: exploreCursor,
      notificationsCursor: notificationsCursor,
      usersCursor: usersCursor,
    );
  }

  @override
  Future<Post> createPost(Post draft) async {
    createdPosts.add(draft);
    return Post(
      id: 'server_${draft.id}',
      author: draft.author,
      content: draft.content,
      privacy: draft.privacy,
      createdAt: 'Vừa xong',
      likes: 0,
      comments: 0,
      shares: 0,
      isLiked: false,
    );
  }

  @override
  Future<Story> createStory(Story draft) async {
    createdStories.add(draft);
    return draft;
  }

  @override
  Future<ChatMessage> sendMessage(
    String c,
    ChatMessage draft, {
    List<String>? attachmentPaths,
  }) async {
    final completer = sendCompleter;
    if (completer != null) return completer.future;
    return ChatMessage(
      id: 'srv_${draft.id}',
      senderId: draft.senderId,
      text: draft.text,
      time: 'Vừa xong',
      attachments: draft.attachments,
    );
  }

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
  Future<UserModel> setShowOnlineStatus(bool enabled) async => _me;

  @override
  Future<void> setLiked(String postId, bool liked) async {
    if (likeError != null) throw likeError!;
    likes[postId] = liked;
  }

  @override
  Future<void> deletePost(String postId) async {
    if (deleteError != null) throw deleteError!;
    deletedPosts.add(postId);
  }

  @override
  Future<Post> loadPost(String postId) async {
    postsLoaded.add(postId);
    if (postLoadError != null) throw postLoadError!;
    return [..._allPosts, ...extraPosts].firstWhere((p) => p.id == postId);
  }

  @override
  Future<void> markStoryViewed(String storyId) async =>
      storiesViewed.add(storyId);

  List<Post> get _allPosts => [
    _post('p1', 'Bài trên bảng tin'),
    _post('p2', 'Bài chỉ có trong Explore'),
    _post('p3', 'Bài chỉ bạn bè', privacy: 'Bạn bè'),
  ];

  @override
  Future<List<Post>> loadSavedPosts() async {
    savedLoads++;
    if (savedError != null) throw savedError!;
    return List.of(savedOnServer);
  }

  @override
  Future<void> setSaved(String postId, bool saved) async {
    if (saveError != null) throw saveError!;
    savedCalls.add('$postId:$saved');
  }

  @override
  Future<void> setHidden(String postId, bool hidden) async {}

  @override
  Future<void> sendFriendRequest(String userId) async =>
      friendRequests.add(userId);

  // --- friend requests, comments, shares, profiles ---
  List<FriendRequest> incomingRequests = [];
  final acceptedRequests = <String>[];
  final deletedRequests = <String>[];
  final unfriended = <String>[];
  final commentsByPost = <String, List<Comment>>{};
  final sharedPosts = <String>[];
  ApiException? commentError;
  List<Post> savedOnServer = [];
  ApiException? savedError;
  var savedLoads = 0;
  ApiException? saveError;
  final savedCalls = <String>[];
  // Chat and polling
  List<Conversation> conversations = [];
  final chatHistory = <String, List<ChatMessage>>{};
  final newMessages = <String, List<ChatMessage>>{};
  final pollCalls = <String>[];
  final readConversations = <String>[];
  Completer<ChatMessage>? sendCompleter;
  var loadCalls = 0;
  var conversationListCalls = 0;
  ApiException? loadFailure;
  ApiException? deleteError;
  ApiException? postLoadError;
  final deletedPosts = <String>[];
  final storiesViewed = <String>[];
  final extraPosts = <Post>[];
  List<Story> stories = const [];
  List<SocialNotification> notifications = const [];
  ApiException? profileError;
  UserProfile? profileToShow;
  final profilesLoaded = <String>[];

  @override
  Future<UserModel> acceptFriendRequest(String requestId) async {
    acceptedRequests.add(requestId);
    final request = incomingRequests.firstWhere((r) => r.id == requestId);
    return request.sender;
  }

  @override
  Future<void> deleteFriendRequest(String requestId) async =>
      deletedRequests.add(requestId);

  @override
  Future<void> unfriend(String userId) async => unfriended.add(userId);

  @override
  Future<List<Comment>> loadComments(String postId) async {
    if (commentError != null) throw commentError!;
    return List.of(commentsByPost[postId] ?? const []);
  }

  @override
  Future<({Comment comment, int commentsCount})> addComment(
    String postId,
    String text,
  ) async {
    if (commentError != null) throw commentError!;
    final list = commentsByPost.putIfAbsent(postId, () => []);
    final comment = Comment(
      id: 'c${list.length + 1}',
      postId: postId,
      author: _me,
      content: text,
      time: 'Vừa xong',
    );
    list.insert(0, comment);
    return (comment: comment, commentsCount: list.length);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final list in commentsByPost.values) {
      list.removeWhere((c) => c.id == commentId);
    }
  }

  @override
  Future<int> sharePost(String postId, String target) async {
    sharedPosts.add('$postId:$target');
    return sharedPosts.length;
  }

  @override
  Future<UserProfile> loadProfile(String userId) async {
    profilesLoaded.add(userId);
    if (profileError != null) throw profileError!;
    return profileToShow ??
        UserProfile(
          user: userId == _lan.id ? _lan : _khang,
          friendship: Friendship.none,
          posts: const [],
        );
  }

  @override
  Future<List<ChatMessage>?> loadMessages(String id) async =>
      chatHistory[id] == null ? null : List.of(chatHistory[id]!);

  @override
  Future<MessagePoll> loadNewMessages(
    String conversationId, {
    String? afterMessageId,
  }) async {
    pollCalls.add('$conversationId after $afterMessageId');
    return MessagePoll(
      messages: List.of(newMessages[conversationId] ?? const []),
      otherTyping: partnerTyping,
    );
  }

  /// What the next poll says about the other person typing.
  var partnerTyping = false;

  var followingPages = <PostPage>[];
  final feedFilterCalls = <String>[];

  @override
  Future<PostPage> loadFeedFilter(String filter, {String? cursor}) async {
    feedFilterCalls.add('$filter:${cursor ?? ''}');
    if (listError != null) throw listError!;
    return followingPages[cursor == null ? 0 : int.parse(cursor.substring(1))];
  }

  @override
  Future<List<Conversation>> loadConversations() async {
    conversationListCalls++;
    return List.of(conversations);
  }

  @override
  Future<void> markConversationRead(String id) async =>
      readConversations.add(id);

  @override
  Future<void> markAllNotificationsRead() async {}

  final updatedProfiles = <UserModel>[];

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    updatedProfiles.add(user);
    return user;
  }

  @override
  Future<UserModel> uploadAvatar(String filePath) async => _me;

  final coverUploads = <String>[];

  @override
  Future<UserModel> uploadCover(String filePath) async {
    coverUploads.add(filePath);
    return _me.copyWith(coverUrl: 'https://cdn.example/cover.jpg');
  }

  // Pages the profile tabs and suggestions get; a page's nextCursor names the next one.
  var photoPages = <PhotoPage>[];
  var friendPages = <UserPage>[];
  var suggestionPages = <UserPage>[];
  ApiException? listError;
  final listCalls = <String>[];

  T _page<T>(List<T> pages, String? cursor) {
    if (listError != null) throw listError!;
    return pages[cursor == null ? 0 : int.parse(cursor.substring(1))];
  }

  @override
  Future<PhotoPage> loadUserPhotos(String userId, {String? cursor}) async {
    listCalls.add('photos:$userId:${cursor ?? ''}');
    return _page(photoPages, cursor);
  }

  @override
  Future<UserPage> loadUserFriends(String userId, {String? cursor}) async {
    listCalls.add('friends:$userId:${cursor ?? ''}');
    return _page(friendPages, cursor);
  }

  @override
  Future<UserPage> loadSuggestions({String? cursor}) async {
    listCalls.add('suggestions:${cursor ?? ''}');
    return _page(suggestionPages, cursor);
  }
}

/// A push service the test drives by hand.
class _FakePush implements PushService {
  _FakePush({this.startToken = 'tok-1'});

  final String? startToken;
  final refreshed = StreamController<String>.broadcast();
  final inForeground = StreamController<PushMessage>.broadcast();
  final tapped = StreamController<PushMessage>.broadcast();
  PushMessage? launch;
  var stops = 0;
  String? _token;

  @override
  Future<String?> start() async => _token = startToken;

  @override
  String? get token => _token;

  @override
  Stream<String> get tokenRefreshed => refreshed.stream;

  @override
  Stream<PushMessage> get foreground => inForeground.stream;

  @override
  Stream<PushMessage> get opened => tapped.stream;

  @override
  Future<PushMessage?> launchMessage() async => launch;

  @override
  Future<void> stop() async {
    stops++;
    _token = null;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRemoteApi api, {
  Future<String?> Function()? pickPhoto,
  PushService? push,
}) async {
  await tester.pumpWidget(
    SocialHubApp(
      api: api,
      pickPhoto: pickPhoto ?? () async => null,
      push: push,
    ),
  );
  await tester.pumpAndSettle();
}

UserModel _stranger(String id, String name) => UserModel(
  id: id,
  name: name,
  username: '@$id',
  avatarUrl: '',
  coverUrl: '',
  bio: '',
  mutualFriends: 0,
  isFriend: false,
  accentColor: const Color(0xFF6C5CE7),
);

Post _mine(String id, String content) => Post(
  id: id,
  author: _me,
  content: content,
  privacy: 'Công khai',
  createdAt: '1 giờ trước',
  likes: 0,
  comments: 0,
  shares: 0,
  isLiked: false,
);

SocialNotification _notification({
  required String id,
  required String type,
  required UserModel actor,
  String? postId,
}) => SocialNotification(
  id: id,
  actor: actor,
  description: type == 'friend'
      ? 'đã gửi lời mời kết bạn'
      : 'đã thích bài viết của bạn',
  time: '2 phút trước',
  type: type,
  icon: Icons.favorite_rounded,
  iconColor: Colors.pink,
  isRead: false,
  postId: postId,
);

Story _story(String id, UserModel user, {bool viewed = false}) => Story(
  id: id,
  user: user,
  text: 'Tin $id',
  isViewed: viewed,
  gradientColors: const [Color(0xFF5D6BFF), Color(0xFF9B8CFF)],
);

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'minh@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Mật khẩu'),
    'secret-pass',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
  await tester.pumpAndSettle();
}

void main() {
  group('sign in', () {
    testWidgets('without a saved session the sign-in form is shown', (
      tester,
    ) async {
      await _pump(tester, _FakeRemoteApi());

      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a saved session goes straight to the app', (tester) async {
      await _pump(tester, _FakeRemoteApi(sessionUser: _me));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);
    });

    testWidgets('signing in loads the app', (tester) async {
      final api = _FakeRemoteApi();
      await _pump(tester, api);

      await _signIn(tester);

      expect(api.loginCalls, ['minh@example.com|secret-pass']);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a wrong password shows the server message', (tester) async {
      final api = _FakeRemoteApi()
        ..loginError = const ApiException(
          statusCode: 422,
          code: 'invalid_credentials',
          message: 'Email hoặc mật khẩu không đúng',
        );
      await _pump(tester, api);

      await _signIn(tester);

      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('empty fields are not sent', (tester) async {
      final api = _FakeRemoteApi();
      await _pump(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(api.loginCalls, isEmpty);
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
    });

    testWidgets('the register form checks the password length', (tester) async {
      final api = _FakeRemoteApi();
      await _pump(tester, api);

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'short',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
      expect(find.text('Từ 3 đến 30 ký tự: chữ, số hoặc _'), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('Home shows the feed and Explore only public posts', (
      tester,
    ) async {
      await _pump(tester, _FakeRemoteApi(sessionUser: _me));

      expect(find.text('Bài trên bảng tin'), findsOneWidget);
      expect(find.text('Bài chỉ bạn bè'), findsOneWidget);
      expect(find.text('Bài chỉ có trong Explore'), findsNothing);

      await tapTab(tester, exploreTab);

      expect(find.textContaining('Bài chỉ có trong Explore'), findsWidgets);
      expect(find.textContaining('Bài chỉ bạn bè'), findsNothing);
    });

    testWidgets('Create Post picks a real photo and sends its path', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api, pickPhoto: () async => '/photos/holiday.jpg');

      await tapTab(tester, createTab);
      expect(find.text('Chọn ảnh mock'), findsNothing);
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      expect(api.createdPosts.single.imageUrl, '/photos/holiday.jpg');
      expect(api.createdPosts.single.content, isEmpty);
    });

    testWidgets('a story with a photo is sent with its path', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api, pickPhoto: () async => '/photos/story.jpg');

      await tester.tap(find.text('Thêm tin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chia sẻ'));
      await tester.pumpAndSettle();

      expect(api.createdStories.single.imageUrl, '/photos/story.jpg');
    });

    testWidgets('a picker that fails shows a message', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(
        tester,
        api,
        pickPhoto: () async =>
            throw PlatformException(code: 'photo_access_denied'),
      );

      await tapTab(tester, createTab);
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không thể mở thư viện ảnh'), findsOneWidget);
      expect(api.createdPosts, isEmpty);
    });

    testWidgets('liking is sent to the server', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Thích bài viết').first);
      await tester.pumpAndSettle();

      expect(api.likes, {'p1': true});
      expect(find.byTooltip('Bỏ thích'), findsOneWidget);
    });

    testWidgets('a rejected like is undone and explained', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..likeError = const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy bài viết',
        );
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Thích bài viết').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bỏ thích'), findsNothing);
      expect(find.text('Không tìm thấy bài viết'), findsOneWidget);
    });

    testWidgets(
      'a created post is shown at once and swapped for the stored one',
      (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await _pump(tester, api);

        await tapTab(tester, createTab);
        await tester.enterText(find.byType(TextField), 'Bài mới từ app');
        await tester.tap(find.text('Đăng'));
        await tester.pumpAndSettle();

        expect(api.createdPosts.single.content, 'Bài mới từ app');
        expect(find.text('Bài mới từ app'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets('a friend request is sent once and stays pending', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tapTab(tester, friendsTab);
      await tester.tap(find.text('Thêm bạn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đang chờ'));
      await tester.pumpAndSettle();

      expect(api.friendRequests, ['khang']);
      expect(find.text('Đang chờ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsWidgets); // Lan, already a friend
    });
  });

  group('leaving', () {
    testWidgets('the Profile button signs out', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tapTab(tester, profileTab);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();

      expect(api.logouts, 1);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    });

    testWidgets('an expired session sends the user back to sign-in', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..loadError = const ApiException(
          statusCode: 401,
          code: 'unauthenticated',
          message: 'Unauthenticated.',
        );
      await _pump(tester, api);

      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..loadError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);

      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      api.loadError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Bài trên bảng tin'), findsOneWidget);
    });
  });

  testWidgets('the mock app has no sign-in and no logout button', (
    tester,
  ) async {
    await pumpSocialHub(tester);
    await tapTab(tester, profileTab);

    expect(find.text('Đăng xuất'), findsNothing);
    expect(find.text(currentUser.name), findsWidgets);
  });

  group('friend requests', () {
    FriendRequest request() =>
        const FriendRequest(id: 'r1', sender: _khang, time: '5 phút trước');

    testWidgets('incoming requests are listed above the users', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..incomingRequests = [request()];
      await _pump(tester, api);

      await tapTab(tester, friendsTab);

      expect(find.text('Lời mời kết bạn (1)'), findsOneWidget);
      expect(find.text('5 phút trước'), findsOneWidget);
      // The person who asked is answered above, not offered "Thêm bạn".
      expect(find.text('Thêm bạn'), findsNothing);
    });

    testWidgets('accepting makes them a friend', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..incomingRequests = [request()];
      await _pump(tester, api);

      await tapTab(tester, friendsTab);
      await tester.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
      await tester.pumpAndSettle();

      expect(api.acceptedRequests, ['r1']);
      expect(find.text('Lời mời kết bạn (1)'), findsNothing);
      // Duy Khang is now in the list with "Bạn bè", like Lan.
      expect(find.text('Bạn bè'), findsNWidgets(2));
    });

    testWidgets('declining removes the request', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..incomingRequests = [request()];
      await _pump(tester, api);

      await tapTab(tester, friendsTab);
      await tester.tap(find.byTooltip('Từ chối'));
      await tester.pumpAndSettle();

      expect(api.deletedRequests, ['r1']);
      expect(find.text('Lời mời kết bạn (1)'), findsNothing);
      expect(find.text('Thêm bạn'), findsOneWidget); // back to a normal user
    });
  });

  group('comments', () {
    Comment comment(String id, String text, UserModel author) => Comment(
      id: id,
      postId: 'p1',
      author: author,
      content: text,
      time: '1 giờ trước',
    );

    testWidgets('the sheet lists the post comments', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..commentsByPost['p1'] = [comment('c1', 'Bài hay quá', _khang)];
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();

      expect(find.text('Bài hay quá'), findsOneWidget);
      expect(find.text('Duy Khang'), findsOneWidget);
    });

    testWidgets('adding a comment shows it and updates the card count', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có bình luận nào'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cảm ơn bạn');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      expect(find.text('Cảm ơn bạn'), findsOneWidget);
      expect(find.text('1 bình luận'), findsOneWidget);

      // Close the sheet: the card behind it now says 1 comment.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Bình luận, 1 bình luận'), findsOneWidget);
    });

    testWidgets('an empty comment is not sent', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      expect(api.commentsByPost, isEmpty);
    });

    testWidgets('a failed comment keeps the text and shows the reason', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      api.commentError = const ApiException(
        statusCode: 429,
        code: 'too_many_requests',
        message: 'Bạn bình luận quá nhanh',
      );
      await tester.enterText(find.byType(TextField), 'Thử lại sau');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn bình luận quá nhanh'), findsOneWidget);
      expect(find.text('Thử lại sau'), findsOneWidget);
    });

    testWidgets(
      'only my own comments and comments on my posts can be deleted',
      (tester) async {
        // p1 is Lan's post, so I may delete only my comment.
        final api = _FakeRemoteApi(sessionUser: _me)
          ..commentsByPost['p1'] = [
            comment('c1', 'của Khang', _khang),
            comment('c2', 'của tôi', _me),
          ];
        await _pump(tester, api);

        await tester.tap(find.byTooltip('Bình luận').first);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Xóa bình luận'), findsOneWidget);

        await tester.tap(find.byTooltip('Xóa bình luận'));
        await tester.pumpAndSettle();

        expect(find.text('của tôi'), findsNothing);
        expect(find.text('của Khang'), findsOneWidget);
        expect(find.text('1 bình luận'), findsOneWidget);
      },
    );
  });

  group('sharing', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              _clipboard = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      _clipboard = null;
    });

    testWidgets('copying the link records a share and updates the count', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Chia sẻ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();

      expect(api.sharedPosts, ['p1:link']);
      expect(_clipboard, 'socialhub://posts/p1');
      expect(
        find.text('Đã sao chép liên kết bài viết của Lan Hương'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Chia sẻ, 1 lượt chia sẻ'), findsOneWidget);
    });

    testWidgets('sending in a message records a share and opens Messages', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Chia sẻ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi trong tin nhắn'));
      await tester.pumpAndSettle();

      expect(api.sharedPosts, ['p1:message']);
      expect(find.text('Messages'), findsOneWidget);
    });
  });

  group('other profiles', () {
    UserProfile profile(
      UserModel user,
      Friendship friendship, {
      String? requestId,
    }) => UserProfile(
      user: user,
      friendship: friendship,
      requestId: requestId,
      posts: [_post('p9', 'Bài của ${user.name}')],
    );

    Future<void> openLanProfile(WidgetTester tester) async {
      await tester.tap(find.text('Lan Hương').first);
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a post author opens their profile with their posts', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = profile(_lan, Friendship.friends);
      await _pump(tester, api);

      await openLanProfile(tester);

      expect(api.profilesLoaded, ['lan']);
      expect(find.text('Bài của Lan Hương'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Bạn bè'), findsOneWidget);
    });

    testWidgets('a stranger gets "Thêm bạn", then "Hủy lời mời"', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = profile(_khang, Friendship.none);
      await _pump(tester, api);
      await openLanProfile(tester);

      api.profileToShow = profile(
        _khang,
        Friendship.pendingOutgoing,
        requestId: 'r5',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm bạn'));
      await tester.pumpAndSettle();

      expect(api.friendRequests, ['khang']);
      expect(find.text('Hủy lời mời'), findsOneWidget);

      api.profileToShow = profile(_khang, Friendship.none);
      await tester.tap(find.text('Hủy lời mời'));
      await tester.pumpAndSettle();

      expect(api.deletedRequests, ['r5']);
      expect(find.widgetWithText(FilledButton, 'Thêm bạn'), findsOneWidget);
    });

    testWidgets('a person who asked us can be accepted or declined', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..incomingRequests = [
          const FriendRequest(id: 'r8', sender: _lan, time: '1 giờ trước'),
        ]
        ..profileToShow = profile(
          _lan,
          Friendship.pendingIncoming,
          requestId: 'r8',
        );
      await _pump(tester, api);
      await openLanProfile(tester);

      api.profileToShow = profile(_lan, Friendship.friends);
      await tester.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
      await tester.pumpAndSettle();

      expect(api.acceptedRequests, ['r8']);
      expect(find.widgetWithText(OutlinedButton, 'Bạn bè'), findsOneWidget);
    });

    testWidgets('unfriending asks first', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = profile(_lan, Friendship.friends);
      await _pump(tester, api);
      await openLanProfile(tester);

      api.profileToShow = profile(_lan, Friendship.none);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Bạn bè'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy kết bạn với Lan Hương?'), findsOneWidget);
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(api.unfriended, isEmpty);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bạn bè'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();

      expect(api.unfriended, ['lan']);
      expect(find.widgetWithText(FilledButton, 'Thêm bạn'), findsOneWidget);
    });

    testWidgets('a profile that fails to load offers a retry', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      api.profileError = const ApiException(
        statusCode: 404,
        code: 'not_found',
        message: 'Không tìm thấy người dùng',
      );

      await openLanProfile(tester);
      expect(find.text('Không tìm thấy người dùng'), findsOneWidget);

      api.profileError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lan Hương'), findsWidgets);
      expect(find.text('Không tìm thấy người dùng'), findsNothing);
    });

    testWidgets('your own name opens your Profile tab, not a copy', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..commentsByPost['p1'] = [
          Comment(
            id: 'c1',
            postId: 'p1',
            author: _me,
            content: 'tôi viết',
            time: '1 phút trước',
          ),
        ];
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(CommentsSheet),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(api.profilesLoaded, isEmpty);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });

  group('deleting my own post', () {
    Future<void> openMenuOf(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        300,
        scrollable: visibleVerticalScrollable,
      );
      final card = find
          .ancestor(of: find.text(text), matching: find.byType(Column))
          .first;
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.more_horiz_rounded),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('only my posts offer "Xóa bài viết"', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'));
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      expect(find.text('Xóa bài viết'), findsNothing);
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      await openMenuOf(tester, 'Bài của tôi');
      expect(find.text('Xóa bài viết'), findsOneWidget);
    });

    testWidgets('confirming deletes the post', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'));
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Xóa bài viết'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa bài viết này?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(api.deletedPosts, ['m1']);
      expect(find.text('Bài của tôi'), findsNothing);
      expect(find.text('Đã xóa bài viết'), findsOneWidget);
    });

    testWidgets('cancelling keeps the post', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'));
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Xóa bài viết'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(api.deletedPosts, isEmpty);
      expect(find.text('Bài của tôi'), findsOneWidget);
    });

    testWidgets('a refused delete brings the post back', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'))
        ..deleteError = const ApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'Không được phép xóa',
        );
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Xóa bài viết'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Bài của tôi'), findsOneWidget);
      expect(find.text('Không được phép xóa'), findsOneWidget);
    });

    testWidgets('the mock app has no delete item', (tester) async {
      await pumpSocialHub(tester);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Xóa bài viết'), findsNothing);
      expect(find.text('Lưu bài viết'), findsOneWidget);
    });
  });

  group('opening things from notifications', () {
    Future<void> openNotifications(WidgetTester tester) =>
        tapTab(tester, notificationsTab);

    testWidgets('a like opens the post', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài được thích'))
        ..notifications = [
          _notification(id: 'n1', type: 'like', actor: _khang, postId: 'm1'),
        ];
      await _pump(tester, api);

      await openNotifications(tester);
      await tester.tap(find.textContaining('Duy Khang'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Bài viết'), findsOneWidget);
      expect(find.text('Bài được thích'), findsWidgets);
      expect(find.byTooltip('Xóa bài viết'), findsOneWidget); // it is my post
    });

    testWidgets('the opened post can be liked and commented on', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài được thích'))
        ..notifications = [
          _notification(id: 'n1', type: 'like', actor: _khang, postId: 'm1'),
        ];
      await _pump(tester, api);

      await openNotifications(tester);
      await tester.tap(find.textContaining('Duy Khang'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thích bài viết'));
      await tester.pumpAndSettle();

      expect(api.likes, {'m1': true});
      expect(find.byTooltip('Bỏ thích'), findsOneWidget);

      await tester.tap(find.byTooltip('Bình luận'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cảm ơn');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();
      expect(find.text('Cảm ơn'), findsOneWidget);
    });

    testWidgets('deleting from the opened post closes it and removes it', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài được thích'))
        ..notifications = [
          _notification(id: 'n1', type: 'like', actor: _khang, postId: 'm1'),
        ];
      await _pump(tester, api);

      await openNotifications(tester);
      await tester.tap(find.textContaining('Duy Khang'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xóa bài viết'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(api.deletedPosts, ['m1']);
      expect(find.widgetWithText(AppBar, 'Bài viết'), findsNothing);
      // Its notification went with it.
      expect(find.textContaining('Duy Khang'), findsNothing);
      await tapTab(tester, homeTab);
      expect(find.text('Bài được thích'), findsNothing);
    });

    testWidgets('a post that is gone shows the reason and can be retried', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài được thích'))
        ..postLoadError = const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy bài viết',
        )
        ..notifications = [
          _notification(id: 'n1', type: 'like', actor: _khang, postId: 'm1'),
        ];
      await _pump(tester, api);

      await openNotifications(tester);
      await tester.tap(find.textContaining('Duy Khang'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy bài viết'), findsOneWidget);

      api.postLoadError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Bài được thích'), findsWidgets);
    });

    testWidgets('a friend request notification opens the person', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..notifications = [
          _notification(id: 'n2', type: 'friend', actor: _khang),
        ]
        ..profileToShow = UserProfile(
          user: _khang,
          friendship: Friendship.pendingIncoming,
          requestId: 'r3',
          posts: const [],
        );
      await _pump(tester, api);

      await openNotifications(tester);
      await tester.tap(find.textContaining('Duy Khang'));
      await tester.pumpAndSettle();

      expect(api.profilesLoaded, ['khang']);
      expect(find.widgetWithText(FilledButton, 'Chấp nhận'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Từ chối'), findsOneWidget);
    });

    testWidgets('the mock app still goes to the Friends tab', (tester) async {
      await pumpSocialHub(tester);

      await tapTab(tester, notificationsTab);
      await tester.tap(find.textContaining('đã gửi lời mời kết bạn'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Friends'), findsOneWidget);
    });
  });

  group('seen stories', () {
    testWidgets('opening someone else\'s story reports it once', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..stories = [_story('s1', _lan)];
      await _pump(tester, api);

      await tester.tap(find.byType(StoryItem).at(1));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(api.storiesViewed, ['s1']);
    });

    testWidgets('a seen story gets a grey ring', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..stories = [_story('s1', _lan), _story('s2', _khang, viewed: true)];
      await _pump(tester, api);

      List<Color>? ring(int index) => tester
          .widget<UserAvatar>(
            find.descendant(
              of: find.byType(StoryItem).at(index),
              matching: find.byType(UserAvatar),
            ),
          )
          .borderColors;

      expect(ring(1), _story('s1', _lan).gradientColors); // unseen: its colours
      expect(ring(2)!.first, ring(2)!.last); // seen: one grey colour

      await tester.tap(find.byType(StoryItem).at(1));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(ring(1)!.first, ring(1)!.last); // now seen too
    });

    testWidgets('moving to the next story reports that one too', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..stories = [_story('s1', _lan), _story('s2', _khang)];
      await _pump(tester, api);

      await tester.tap(find.byType(StoryItem).at(1));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(api.storiesViewed, ['s1', 's2']);
    });

    testWidgets('my own and already seen stories are not reported', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..stories = [_story('mine', _me), _story('old', _lan, viewed: true)];
      await _pump(tester, api);

      for (final index in [1, 2]) {
        await tester.tap(find.byType(StoryItem).at(index));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
      }

      expect(api.storiesViewed, isEmpty);
    });

    testWidgets('a story seen twice is sent only once', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..stories = [_story('s1', _lan)];
      await _pump(tester, api);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(StoryItem).at(1));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
      }

      expect(api.storiesViewed, ['s1']);
    });
  });

  group('chat polling', () {
    ChatMessage msg(String id, String text, {UserModel? from}) => ChatMessage(
      id: id,
      senderId: (from ?? _lan).id,
      text: text,
      time: 'Vừa xong',
    );

    _FakeRemoteApi chatApi() {
      final api = _FakeRemoteApi(sessionUser: _me);
      api.conversations = [
        Conversation(
          id: 'c1',
          user: _lan,
          lastMessage: 'tin cũ',
          time: '1 giờ trước',
          unreadCount: 0,
          messages: const [],
        ),
      ];
      api.chatHistory['c1'] = [msg('m1', 'tin cũ')];
      return api;
    }

    Future<void> openChat(WidgetTester tester) async {
      await openMessagesFromHome(tester);
      await tester.tap(find.text('Lan Hương'));
      await tester.pumpAndSettle();
    }

    testWidgets('a new message appears without leaving the chat', (
      tester,
    ) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);
      expect(find.text('tin cũ'), findsWidgets);

      api.newMessages['c1'] = [msg('m2', 'Chào bạn, có đó không?')];
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Chào bạn, có đó không?'), findsOneWidget);
      expect(api.pollCalls, ['c1 after m1']);
      expect(
        api.readConversations,
        contains('c1'),
      ); // seen, so told to the server
    });

    testWidgets("the other person's typing shows and goes away", (
      tester,
    ) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);
      expect(find.text('Lan Hương đang soạn tin...'), findsNothing);

      api.partnerTyping = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Lan Hương đang soạn tin...'), findsOneWidget);

      api.partnerTyping = false;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Lan Hương đang soạn tin...'), findsNothing);
    });

    testWidgets('typing does not carry over to the next time the chat opens', (
      tester,
    ) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);
      api.partnerTyping = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Lan Hương đang soạn tin...'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lan Hương'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Lan Hương đang soạn tin...'), findsNothing);
    });

    testWidgets('the same message is not added twice', (tester) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);

      api.newMessages['c1'] = [msg('m2', 'Một lần thôi')];
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));

      expect(find.text('Một lần thôi'), findsOneWidget);
      expect(api.pollCalls.last, 'c1 after m2'); // asks after the newest now
    });

    testWidgets('my own message from another device shows too', (tester) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);

      api.newMessages['c1'] = [msg('m2', 'Gửi từ máy khác', from: _me)];
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Gửi từ máy khác'), findsOneWidget);
      expect(api.readConversations, isEmpty); // nothing from the other person
    });

    testWidgets('polling waits for a message that is still being sent', (
      tester,
    ) async {
      final api = chatApi()..sendCompleter = Completer<ChatMessage>();
      await _pump(tester, api);
      await openChat(tester);

      await tester.enterText(find.byType(TextField), 'Đang gửi');
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(api.pollCalls, isEmpty);

      api.sendCompleter!.complete(msg('m5', 'Đang gửi', from: _me));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(api.pollCalls, ['c1 after m5']);
      expect(find.text('Đang gửi'), findsOneWidget);
    });

    testWidgets('polling stops when the chat is closed', (tester) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);
      await tester.pump(const Duration(seconds: 4));
      final calls = api.pollCalls.length;

      await tester.tap(find.byTooltip('Quay lại danh sách tin nhắn'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 12));

      expect(api.pollCalls.length, calls);
    });

    testWidgets('the Messages list refreshes by itself', (tester) async {
      final api = chatApi();
      await _pump(tester, api);
      await openMessagesFromHome(tester);
      expect(find.text('tin cũ'), findsOneWidget);

      api.conversations = [
        Conversation(
          id: 'c1',
          user: _lan,
          lastMessage: 'tin rất mới',
          time: 'Vừa xong',
          unreadCount: 3,
          messages: const [],
        ),
      ];
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.text('tin rất mới'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(api.conversationListCalls, 1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(api.conversationListCalls, 1); // stopped with the screen
    });

    testWidgets('a conversation being read does not get an unread badge', (
      tester,
    ) async {
      final api = chatApi();
      await _pump(tester, api);
      await openChat(tester);

      api.conversations = [
        Conversation(
          id: 'c1',
          user: _lan,
          lastMessage: 'tin cũ',
          time: 'Vừa xong',
          unreadCount: 2,
          messages: const [],
        ),
      ];
      // Both polls run while the chat is open; the list one fires at 15 s.
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      await tester.tap(find.byTooltip('Quay lại danh sách tin nhắn'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsNothing);
    });
  });

  group('pull to refresh', () {
    Future<void> pullDown(WidgetTester tester) async {
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Home loads everything again', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      expect(api.loadCalls, 1);

      api.extraPosts.add(_mine('m9', 'Bài mới về'));
      await pullDown(tester);

      expect(api.loadCalls, 2);
      await tester.scrollUntilVisible(
        find.text('Bài mới về'),
        300,
        scrollable: visibleVerticalScrollable,
      );
      expect(find.text('Bài mới về'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the screen and explains', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..loadFailure = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);

      await pullDown(tester);

      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);
    });

    testWidgets('an empty Home can be refreshed too', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      // Nothing but the composer: a short, non-scrolling page.
      api.extraPosts.clear();
      await pullDown(tester);
      expect(api.loadCalls, 2);
    });

    testWidgets('Notifications and Friends refresh as well', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await tapTab(tester, notificationsTab);
      await tester.fling(
        find.byType(CustomScrollView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(api.loadCalls, 2);

      await tapTab(tester, friendsTab);
      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(api.loadCalls, 3);
    });

    testWidgets('the mock app has no pull-to-refresh', (tester) async {
      await pumpSocialHub(tester);

      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });

  group('Explore details', () {
    Future<void> openExploreDetails(WidgetTester tester) async {
      await tapTab(tester, exploreTab);
      await tester.tap(find.text('Bài chỉ có trong Explore').first);
      await tester.pumpAndSettle();
    }

    testWidgets('the details offer comment, share and save', (tester) async {
      await _pump(tester, _FakeRemoteApi(sessionUser: _me));

      await openExploreDetails(tester);

      expect(find.byTooltip('Bình luận'), findsOneWidget);
      expect(find.byTooltip('Chia sẻ'), findsOneWidget);
      expect(find.byTooltip('Lưu bài viết'), findsOneWidget);
    });

    testWidgets('a comment added there updates the count in the details', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openExploreDetails(tester);
      expect(find.textContaining('0 bình luận'), findsOneWidget);

      await tester.tap(find.byTooltip('Bình luận'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hay lắm');
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();
      expect(find.text('Hay lắm'), findsOneWidget);

      await tester.tapAt(const Offset(400, 20)); // close the comments
      await tester.pumpAndSettle();

      expect(api.commentsByPost['p2']!.single.content, 'Hay lắm');
      expect(find.textContaining('1 bình luận'), findsOneWidget);
    });

    testWidgets('copying the link records a share and updates the details', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              _clipboard = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        _clipboard = null;
      });
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openExploreDetails(tester);

      await tester.tap(find.byTooltip('Chia sẻ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sao chép liên kết'));
      await tester.pumpAndSettle();

      expect(api.sharedPosts, ['p2:link']);
      expect(_clipboard, 'socialhub://posts/p2');
      expect(find.textContaining('1 lượt chia sẻ'), findsOneWidget);
    });

    testWidgets('sending in a message closes the details and opens Messages', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openExploreDetails(tester);

      await tester.tap(find.byTooltip('Chia sẻ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi trong tin nhắn'));
      await tester.pumpAndSettle();

      expect(api.sharedPosts, ['p2:message']);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('saving shows on the tile, in the details and unsaves again', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openExploreDetails(tester);

      await tester.tap(find.byTooltip('Lưu bài viết'));
      await tester.pumpAndSettle();

      expect(api.savedCalls, ['p2:true']);
      expect(find.byTooltip('Bỏ lưu bài viết'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsWidgets); // the tile too

      await tester.tap(find.byTooltip('Bỏ lưu bài viết'));
      await tester.pumpAndSettle();
      expect(api.savedCalls, ['p2:true', 'p2:false']);
      expect(find.byTooltip('Lưu bài viết'), findsOneWidget);
    });

    testWidgets('a refused save is undone and explained', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..saveError = const ApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Không tìm thấy bài viết',
        );
      await _pump(tester, api);
      await openExploreDetails(tester);

      await tester.tap(find.byTooltip('Lưu bài viết'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lưu bài viết'), findsOneWidget);
      expect(find.text('Không tìm thấy bài viết'), findsOneWidget);
    });

    testWidgets('a post saved on Home shows as saved in Explore', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await savePostFromMenu(tester, _post('p1', 'Bài trên bảng tin'));

      await tapTab(tester, exploreTab);
      await tester.tap(find.text('Bài trên bảng tin').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Bỏ lưu bài viết'), findsOneWidget);
    });

    testWidgets('tapping the author opens their profile', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = UserProfile(
          user: _lan,
          friendship: Friendship.friends,
          posts: [_post('p9', 'Bài trong hồ sơ')],
        );
      await _pump(tester, api);
      await openExploreDetails(tester);

      await tester.tap(find.text('Lan Hương').last);
      await tester.pumpAndSettle();

      expect(api.profilesLoaded, ['lan']);
      expect(find.text('Bài trong hồ sơ'), findsOneWidget);
      expect(find.byTooltip('Bình luận'), findsNothing); // the sheet is closed
    });

    testWidgets('the actions fit a narrow phone screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, _FakeRemoteApi(sessionUser: _me));

      await openExploreDetails(tester);

      expect(tester.takeException(), isNull); // no overflow
      expect(find.byTooltip('Lưu bài viết'), findsOneWidget);
    });

    testWidgets('the mock app keeps read-only details', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, exploreTab);
      await tester.tap(find.byType(InkWell).at(3));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lưu bài viết'), findsNothing);
      expect(find.textContaining('lượt chia sẻ'), findsOneWidget);
    });
  });

  group('saved posts', () {
    Future<void> openSaved(WidgetTester tester) async {
      await tapTab(tester, profileTab);
      await tester.tap(find.text('Bài đã lưu'));
      await tester.pumpAndSettle();
    }

    testWidgets('Profile opens the list the server returns', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedOnServer = [
          _post('s2', 'Bài đã lưu thứ hai'),
          _post('s1', 'Bài đã lưu thứ nhất'),
        ];
      await _pump(tester, api);

      await openSaved(tester);

      expect(find.widgetWithText(AppBar, 'Bài đã lưu'), findsOneWidget);
      expect(find.text('Bài đã lưu thứ hai'), findsOneWidget);
      expect(find.text('Bài đã lưu thứ nhất'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Bài đã lưu thứ hai')).dy,
        lessThan(tester.getTopLeft(find.text('Bài đã lưu thứ nhất')).dy),
      );
    });

    testWidgets('unsaving removes the post and tells the server', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedOnServer = [_post('s1', 'Bài sẽ bỏ lưu')];
      await _pump(tester, api);
      await openSaved(tester);

      await tester.tap(find.byTooltip('Bỏ lưu bài viết'));
      await tester.pumpAndSettle();

      expect(api.savedCalls, ['s1:false']);
      expect(find.text('Bài sẽ bỏ lưu'), findsNothing);
      expect(find.text('Bạn chưa lưu bài viết nào'), findsOneWidget);
    });

    testWidgets('a saved post is still unsaved when it is not on Home', (
      tester,
    ) async {
      // s1 is not in the feed, so the app never saw it as saved: unsaving must
      // not turn into saving.
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedOnServer = [_post('s1', 'Chỉ có trong danh sách lưu')];
      await _pump(tester, api);
      await openSaved(tester);

      await tester.tap(find.byTooltip('Bỏ lưu bài viết'));
      await tester.pumpAndSettle();

      expect(api.savedCalls, ['s1:false']);
    });

    testWidgets('a refused unsave keeps the app state honest', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedOnServer = [_post('s1', 'Bài lưu')]
        ..saveError = const ApiException(
          statusCode: 500,
          code: 'server_error',
          message: 'Lỗi máy chủ',
        );
      await _pump(tester, api);
      await openSaved(tester);

      await tester.tap(find.byTooltip('Bỏ lưu bài viết'));
      await tester.pumpAndSettle();

      expect(find.text('Lỗi máy chủ'), findsOneWidget);
    });

    testWidgets('an empty list says so and can be refreshed', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openSaved(tester);
      expect(find.text('Bạn chưa lưu bài viết nào'), findsOneWidget);

      api.savedOnServer = [_post('s1', 'Vừa lưu ở máy khác')];
      await tester.fling(
        find.byType(CustomScrollView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(api.savedLoads, 2);
      expect(find.text('Vừa lưu ở máy khác'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);
      await openSaved(tester);
      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      api
        ..savedError = null
        ..savedOnServer = [_post('s1', 'Đã tải được')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Đã tải được'), findsOneWidget);
    });

    testWidgets('tapping the author opens their profile', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..savedOnServer = [_post('s1', 'Bài của Lan')];
      await _pump(tester, api);
      await openSaved(tester);

      await tester.tap(find.text('Lan Hương'));
      await tester.pumpAndSettle();

      expect(api.profilesLoaded, ['lan']);
    });

    testWidgets('other people\'s profiles have no saved button', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = UserProfile(
          user: _lan,
          friendship: Friendship.friends,
          posts: const [],
        );
      await _pump(tester, api);

      await tester.tap(find.text('Lan Hương').first);
      await tester.pumpAndSettle();

      expect(find.text('Bài đã lưu'), findsNothing);
    });

    testWidgets('the mock app lists what was saved in this session', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await savePostFromMenu(tester, mockPosts[0]);
      await savePostFromMenu(tester, mockPosts[1]);

      await tapTab(tester, profileTab);
      await tester.tap(find.text('Bài đã lưu'));
      await tester.pumpAndSettle();

      // Newest save first: post_2 (saved last), then post_1.
      expect(find.text(mockPosts[1].content), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(mockPosts[1].content)).dy,
        lessThan(tester.getTopLeft(find.text(mockPosts[0].content)).dy),
      );

      await tester.tap(find.byTooltip('Bỏ lưu bài viết').first);
      await tester.pumpAndSettle();
      expect(find.text(mockPosts[1].content), findsNothing);
      expect(find.text(mockPosts[0].content), findsOneWidget);
    });

    testWidgets('the mock app starts with nothing saved', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, profileTab);
      await tester.tap(find.text('Bài đã lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa lưu bài viết nào'), findsOneWidget);
    });
  });

  group('account security', () {
    final unverified = _me.copyWith(emailVerified: false);

    Future<void> openProfile(WidgetTester tester) async {
      await tapTab(tester, profileTab);
    }

    testWidgets('a verified user sees no banner', (tester) async {
      await _pump(tester, _FakeRemoteApi(sessionUser: _me));
      await openProfile(tester);

      expect(find.text('Email chưa được xác thực'), findsNothing);
    });

    testWidgets('the banner opens the code screen and then goes away', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: unverified);
      await _pump(tester, api);
      await openProfile(tester);

      await tester.tap(find.text('Xác thực'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12ab');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Mã gồm 6 chữ số'), findsOneWidget);
      expect(api.accountCalls, isEmpty);

      await tester.tap(find.text('Gửi lại mã'));
      await tester.pumpAndSettle();
      expect(find.text('Đã gửi mã mới'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(api.accountCalls, ['request-verification', 'verify:123456']);
      expect(find.text('Email chưa được xác thực'), findsNothing);
    });

    testWidgets('a wrong verification code shows the server message', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: unverified)
        ..accountError = const ApiException(
          statusCode: 422,
          code: 'invalid_code',
          message: 'Mã không đúng hoặc đã hết hạn',
        );
      await _pump(tester, api);
      await openProfile(tester);

      await tester.tap(find.text('Xác thực'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('Mã không đúng hoặc đã hết hạn'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Email chưa được xác thực'), findsOneWidget);
    });

    testWidgets('forgot password: email, then code and a new password', (
      tester,
    ) async {
      final api = _FakeRemoteApi();
      await _pump(tester, api);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'minh@example.com',
      );
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      // the typed email is carried over
      expect(find.text('minh@example.com'), findsOneWidget);

      await tester.tap(find.text('Gửi mã'));
      await tester.pumpAndSettle();
      expect(api.accountCalls, ['forgot:minh@example.com']);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã xác nhận'),
        '654321',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'short',
      );
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'brand-new-pass',
      );
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(
        api.accountCalls.last,
        'reset:minh@example.com|654321|brand-new-pass',
      );
      expect(find.text('Đã đổi mật khẩu, hãy đăng nhập lại'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    });

    testWidgets('a wrong reset code stays on the form with the message', (
      tester,
    ) async {
      final api = _FakeRemoteApi()
        ..accountError = const ApiException(
          statusCode: 422,
          code: 'invalid_code',
          message: 'Mã không đúng hoặc đã hết hạn',
        );
      await _pump(tester, api);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'minh@example.com',
      );
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi mã'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã xác nhận'),
        '000000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'brand-new-pass',
      );
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(find.text('Mã không đúng hoặc đã hết hạn'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    });

    testWidgets('the register form has no forgot-password link', (
      tester,
    ) async {
      await _pump(tester, _FakeRemoteApi());

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu?'), findsNothing);
    });

    Future<void> openDeleteDialog(WidgetTester tester) async {
      await openProfile(tester);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Xóa tài khoản'),
        300,
        scrollable: visibleVerticalScrollable,
      );
      await tester.tap(find.text('Xóa tài khoản'));
      await tester.pumpAndSettle();
    }

    testWidgets('a wrong password keeps the dialog open with the error', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..accountError = const ApiException(
          statusCode: 422,
          code: 'invalid_credentials',
          message: 'Mật khẩu không đúng',
        );
      await _pump(tester, api);
      await openDeleteDialog(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Xóa tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(api.accountCalls, isEmpty);

      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.widgetWithText(TextButton, 'Xóa tài khoản'));
      await tester.pumpAndSettle();

      expect(api.accountCalls, ['delete:wrong']);
      expect(find.text('Mật khẩu không đúng'), findsOneWidget);
      expect(find.text('Xóa tài khoản?'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openDeleteDialog(tester);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa tài khoản?'), findsNothing);
      expect(api.accountCalls, isEmpty);
    });

    testWidgets('deleting the account returns to sign-in with a notice', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openDeleteDialog(tester);

      await tester.enterText(find.byType(TextField).last, 'secret-pass');
      await tester.tap(find.widgetWithText(TextButton, 'Xóa tài khoản'));
      await tester.pumpAndSettle();

      expect(api.accountCalls, ['delete:secret-pass']);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Tài khoản đã được xóa'), findsOneWidget);
    });
  });

  testWidgets('the mock app has no delete-account button', (tester) async {
    await pumpSocialHub(tester);
    await tapTab(tester, profileTab);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Xóa tài khoản'), findsNothing);
  });

  group('starting a conversation', () {
    testWidgets('"Tin nhắn mới" lists friends and opens an empty chat', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openMessagesFromHome(tester);

      await tester.tap(find.byTooltip('Tin nhắn mới'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Lan Hương'), findsOneWidget);
      expect(find.text('Duy Khang'), findsNothing); // not a friend

      await tester.tap(find.widgetWithText(ListTile, 'Lan Hương'));
      await tester.pumpAndSettle();

      expect(api.startedWith, ['lan']);
      expect(find.text('Nhắn tin...'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Chào Lan');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Chào Lan'), findsOneWidget);

      // back on the list, the new conversation is there
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Lan Hương'), findsOneWidget);
    });

    testWidgets('a friend you already talk to reuses the conversation', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..conversations = [
          Conversation(
            id: 'c1',
            user: _lan,
            lastMessage: 'tin cũ',
            time: '1 giờ trước',
            unreadCount: 0,
            messages: const [],
          ),
        ];
      await _pump(tester, api);
      await openMessagesFromHome(tester);

      await tester.tap(find.byTooltip('Tin nhắn mới'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lan Hương'));
      await tester.pumpAndSettle();

      expect(api.startedWith, isEmpty);
      expect(find.text('Nhắn tin...'), findsOneWidget);
    });

    testWidgets('a refusal is shown and no chat opens', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..startError = const ApiException(
          statusCode: 403,
          code: 'not_friends',
          message: 'Bạn chỉ nhắn tin được cho bạn bè',
        );
      await _pump(tester, api);
      await openMessagesFromHome(tester);

      await tester.tap(find.byTooltip('Tin nhắn mới'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lan Hương'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chỉ nhắn tin được cho bạn bè'), findsOneWidget);
      expect(find.text('Nhắn tin...'), findsNothing);
    });

    testWidgets('a friend\'s profile has a "Nhắn tin" button', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = UserProfile(
          user: _lan,
          friendship: Friendship.friends,
          posts: const [],
        );
      await _pump(tester, api);
      await tester.tap(find.text('Lan Hương').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Nhắn tin'));
      await tester.pumpAndSettle();

      expect(api.startedWith, ['lan']);
      expect(find.text('Nhắn tin...'), findsOneWidget);
    });

    testWidgets('strangers have no "Nhắn tin" button', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = UserProfile(
          user: _khang,
          friendship: Friendship.none,
          posts: const [],
        );
      await _pump(tester, api);
      await tester.tap(find.text('Lan Hương').first);
      await tester.pumpAndSettle();

      expect(find.text('Nhắn tin'), findsNothing);
    });

    testWidgets('the mock app has no "Tin nhắn mới" button', (tester) async {
      await pumpSocialHub(tester);
      await openMessagesFromHome(tester);

      expect(find.byTooltip('Tin nhắn mới'), findsNothing);
    });
  });

  group('paging and user search', () {
    List<Post> manyPosts(String prefix, int count) => [
      for (var i = 0; i < count; i++)
        _post('$prefix${(1000 - i)}', 'Bài $prefix $i'),
    ];

    testWidgets('Home loads the next page near the end, once', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.addAll(manyPosts('f', 12))
        ..feedCursor = 'c1'
        ..feedPages = [
          PostPage(posts: [_post('a1', 'Bài trang hai')]),
        ];
      await _pump(tester, api);

      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();

      expect(api.moreCalls, ['feed:c1']); // no cursor left after page two
      await tester.scrollUntilVisible(
        find.text('Bài trang hai'),
        300,
        scrollable: visibleVerticalScrollable,
      );
      expect(find.text('Bài trang hai'), findsOneWidget);
    });

    testWidgets('a failed page shows the error and a later scroll retries', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);
      loadMoreRetryDelay = const Duration(milliseconds: 50);
      addTearDown(() => loadMoreRetryDelay = const Duration(seconds: 3));
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.addAll(manyPosts('f', 12))
        ..feedCursor = 'c1'
        ..moreError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);

      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      api
        ..moreError = null
        ..feedPages = [
          PostPage(posts: [_post('a1', 'Bài trang hai')]),
        ];
      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();

      expect(api.moreCalls, ['feed:c1', 'feed:c1']);
    });

    testWidgets('Explore and Notifications page too', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.reset);
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.addAll(manyPosts('e', 12))
        ..exploreCursor = 'x1'
        ..explorePages = [
          PostPage(posts: [_post('b1', 'Bài Explore trang hai')]),
        ]
        ..notificationsCursor = 'n1'
        ..notifications = [
          for (var i = 0; i < 14; i++)
            _notification(id: 'n$i', type: 'like', actor: _lan),
        ]
        ..notificationPages = [
          NotificationPage(
            notifications: [
              _notification(id: 'n99', type: 'like', actor: _khang),
            ],
          ),
        ];
      await _pump(tester, api);

      await tapTab(tester, exploreTab);
      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();
      await tapTab(tester, notificationsTab);
      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();

      expect(api.moreCalls, ['explore:x1', 'notifications:n1']);
    });

    testWidgets('Friends searches the server after a pause', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..searchResults = {
          'khang': UserPage(users: [_khang], pendingIds: {'khang'}),
        };
      await _pump(tester, api);
      await tapTab(tester, friendsTab);

      await tester.enterText(find.byType(TextField), 'kha');
      await tester.enterText(find.byType(TextField), 'khang');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(api.searches, ['khang|']); // typing fast sent one request
      expect(find.text('Duy Khang'), findsOneWidget);
      expect(find.text('Đang chờ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'khong-co');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy người dùng'), findsOneWidget);

      // clearing goes back to the full list without asking the server
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      expect(find.text('Lan Hương'), findsOneWidget);
      expect(api.searches.length, 2);
    });

    testWidgets('the mock app searches locally', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, friendsTab);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
    });
  });

  group('push notifications', () {
    testWidgets('the phone is registered once signed in', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api, push: _FakePush());

      expect(api.devices, ['+tok-1|android']);
    });

    testWidgets('without a token nothing is registered', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api, push: _FakePush(startToken: null));

      expect(api.devices, isEmpty);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a refreshed token is registered too', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      final push = _FakePush();
      await _pump(tester, api, push: push);

      push.refreshed.add('tok-2');
      await tester.pumpAndSettle();

      expect(api.devices, ['+tok-1|android', '+tok-2|android']);
    });

    testWidgets('a push while the app is open reloads the lists', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      final push = _FakePush();
      await _pump(tester, api, push: push);
      expect(api.loadCalls, 1);

      push.inForeground.add(const PushMessage({'type': 'like'}));
      await tester.pumpAndSettle();

      expect(api.loadCalls, 2);
    });

    testWidgets('tapping a message push opens that chat', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..conversations = [
          Conversation(
            id: 'c1',
            user: _lan,
            lastMessage: 'chào',
            time: '1 phút trước',
            unreadCount: 1,
            messages: const [],
          ),
        ];
      final push = _FakePush();
      await _pump(tester, api, push: push);

      push.tapped.add(
        const PushMessage({'type': 'message', 'conversationId': 'c1'}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhắn tin...'), findsOneWidget);
    });

    testWidgets('a push that launched the app opens the post', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      final push = _FakePush()
        ..launch = const PushMessage({'type': 'like', 'postId': 'p1'});
      await _pump(tester, api, push: push);

      expect(api.postsLoaded, contains('p1'));
    });

    testWidgets('signing out forgets the phone first', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      final push = _FakePush();
      await _pump(tester, api, push: push);

      await tapTab(tester, profileTab);
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();

      expect(api.devices.last, '-tok-1');
      expect(push.stops, 1);
      expect(api.logouts, 1);
    });
  });

  group('reporting, blocking and post privacy', () {
    Future<void> fillReport(
      WidgetTester tester,
      String reason, {
      String? details,
    }) async {
      await tester.ensureVisible(find.text(reason));
      await tester.tap(find.text(reason));
      await tester.pump();
      if (details != null) {
        await tester.enterText(find.byType(TextField), details);
      }
      final send = find.widgetWithText(FilledButton, 'Gửi báo cáo');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
    }

    Future<void> openMenuOf(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        300,
        scrollable: visibleVerticalScrollable,
      );
      final card = find
          .ancestor(of: find.text(text), matching: find.byType(Column))
          .first;
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.more_horiz_rounded),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('my own post can change its audience', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'));
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      expect(find.text('Báo cáo bài viết'), findsNothing);
      expect(find.text('Chặn Minh Ánh'), findsNothing);
      await tester.tap(find.text('Đổi quyền riêng tư'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget); // the current one
      await tester.tap(find.text('Chỉ mình tôi'));
      await tester.pumpAndSettle();

      expect(api.privacyChanges, ['m1:only_me']);
      expect(find.textContaining('Chỉ mình tôi'), findsWidgets);
    });

    testWidgets('picking the current audience changes nothing', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'));
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Đổi quyền riêng tư'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Công khai'),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.privacyChanges, isEmpty);
    });

    testWidgets('a refused change goes back and says why', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..extraPosts.add(_mine('m1', 'Bài của tôi'))
        ..moderationError = const ApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'Bạn không có quyền thực hiện thao tác này.',
        );
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Đổi quyền riêng tư'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bạn bè'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn không có quyền thực hiện thao tác này.'),
        findsOneWidget,
      );
      // still public: the menu marks the old value again
      await openMenuOf(tester, 'Bài của tôi');
      await tester.tap(find.text('Đổi quyền riêng tư'));
      await tester.pumpAndSettle();
      final publicTile = find.widgetWithText(ListTile, 'Công khai');
      expect(
        find.descendant(of: publicTile, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets("someone else's post can be reported", (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      expect(find.text('Đổi quyền riêng tư'), findsNothing);
      await tester.tap(find.text('Báo cáo bài viết'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Gửi báo cáo'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi báo cáo'),
            )
            .onPressed,
        isNull, // a reason is required
      );
      await fillReport(tester, 'Spam hoặc quảng cáo', details: 'Link lạ');

      expect(api.reports, ['post:p1:spam:Link lạ']);
      expect(find.text('Đã gửi báo cáo, cảm ơn bạn'), findsOneWidget);
    });

    testWidgets('closing the report sheet sends nothing', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      await tester.tap(find.text('Báo cáo bài viết'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(api.reports, isEmpty);
    });

    testWidgets('a failed report shows the server message', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..moderationError = const ApiException(
          statusCode: 429,
          code: 'too_many_requests',
          message: 'Bạn thao tác quá nhanh, hãy thử lại sau.',
        );
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      await tester.tap(find.text('Báo cáo bài viết'));
      await tester.pumpAndSettle();
      await fillReport(tester, 'Lý do khác');

      expect(
        find.text('Bạn thao tác quá nhanh, hãy thử lại sau.'),
        findsOneWidget,
      );
    });

    testWidgets("blocking an author removes everything of theirs", (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);

      await openMenuOf(tester, 'Bài trên bảng tin');
      await tester.tap(find.text('Chặn Lan Hương'));
      await tester.pumpAndSettle();
      expect(find.text('Chặn Lan Hương?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Chặn'));
      await tester.pumpAndSettle();

      expect(api.blocked, ['lan']);
      expect(find.text('Bài trên bảng tin'), findsNothing);
      expect(find.text('Đã chặn Lan Hương'), findsOneWidget);
    });

    testWidgets('cancelling the block keeps the post', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      await tester.tap(find.text('Chặn Lan Hương'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(api.blocked, isEmpty);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);
    });

    testWidgets('a refused block keeps the post and says why', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..moderationError = const ApiException(
          statusCode: 500,
          code: 'server_error',
          message: 'Máy chủ gặp lỗi, hãy thử lại sau.',
        );
      await _pump(tester, api);

      await openMenuOf(tester, 'Bài trên bảng tin');
      await tester.tap(find.text('Chặn Lan Hương'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Chặn'));
      await tester.pumpAndSettle();

      expect(find.text('Máy chủ gặp lỗi, hãy thử lại sau.'), findsOneWidget);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);
    });

    testWidgets("someone else's comment can be reported, mine cannot", (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..commentsByPost['p1'] = [
          Comment(
            id: 'c1',
            postId: 'p1',
            author: _lan,
            content: 'Bình luận của Lan',
            time: '1 giờ trước',
          ),
          Comment(
            id: 'c2',
            postId: 'p1',
            author: _me,
            content: 'Bình luận của tôi',
            time: '1 giờ trước',
          ),
        ];
      await _pump(tester, api);

      await tester.tap(find.byTooltip('Bình luận').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Báo cáo bình luận'), findsOneWidget);

      await tester.tap(find.byTooltip('Báo cáo bình luận'));
      await tester.pumpAndSettle();
      await fillReport(tester, 'Quấy rối hoặc bắt nạt');

      expect(api.reports, ['comment:c1:harassment:']);
    });

    group('on a profile', () {
      Future<void> openLanProfile(
        WidgetTester tester,
        UserProfile profile,
        _FakeRemoteApi api,
      ) async {
        api.profileToShow = profile;
        await _pump(tester, api);
        await tester.tap(find.text('Lan Hương').first);
        await tester.pumpAndSettle();
      }

      UserProfile lan({bool blocked = false}) => UserProfile(
        user: _lan,
        friendship: blocked ? Friendship.none : Friendship.friends,
        posts: const [],
        isBlocked: blocked,
      );

      testWidgets('the menu reports the user', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await openLanProfile(tester, lan(), api);

        await tester.tap(find.byTooltip('Tùy chọn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Báo cáo người dùng'));
        await tester.pumpAndSettle();
        await fillReport(tester, 'Ngôn từ thù ghét');

        expect(api.reports, ['user:lan:hate:']);
      });

      testWidgets('blocking from the menu then offers "Bỏ chặn"', (
        tester,
      ) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await openLanProfile(tester, lan(), api);

        await tester.tap(find.byTooltip('Tùy chọn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chặn'));
        await tester.pumpAndSettle();
        api.profileToShow = lan(blocked: true);
        await tester.tap(find.widgetWithText(FilledButton, 'Chặn'));
        await tester.pumpAndSettle();

        expect(api.blocked, ['lan']);
        expect(find.widgetWithText(FilledButton, 'Bỏ chặn'), findsOneWidget);
        expect(find.text('Nhắn tin'), findsNothing); // no friend buttons

        api.profileToShow = lan();
        await tester.tap(find.widgetWithText(FilledButton, 'Bỏ chặn'));
        await tester.pumpAndSettle();
        expect(api.unblocked, ['lan']);
        expect(find.widgetWithText(FilledButton, 'Nhắn tin'), findsOneWidget);
      });
    });

    group('the blocked list', () {
      Future<void> openBlockedList(WidgetTester tester) async {
        await tapTab(tester, profileTab);
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Người đã chặn'),
          300,
          scrollable: visibleVerticalScrollable,
        );
        await tester.tap(find.text('Người đã chặn'));
        await tester.pumpAndSettle();
      }

      testWidgets('lists the people and unblocks one', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me)..blockedUsers = [_khang];
        await _pump(tester, api);
        await openBlockedList(tester);

        expect(find.text('Duy Khang'), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ chặn'));
        await tester.pumpAndSettle();

        expect(api.unblocked, ['khang']);
        expect(find.text('Duy Khang'), findsNothing);
        expect(find.text('Bạn chưa chặn ai'), findsOneWidget);
      });

      testWidgets('says so when nobody is blocked', (tester) async {
        await _pump(tester, _FakeRemoteApi(sessionUser: _me));
        await openBlockedList(tester);

        expect(find.text('Bạn chưa chặn ai'), findsOneWidget);
      });
    });

    testWidgets('the mock app has none of these buttons', (tester) async {
      await pumpSocialHub(tester);
      await openPostMenu(tester, mockPosts.first);

      expect(find.text('Báo cáo bài viết'), findsNothing);
      expect(find.textContaining('Chặn '), findsNothing);
      expect(find.text('Đổi quyền riêng tư'), findsNothing);
    });
  });

  group('moderation in Explore details and the opened post', () {
    Future<void> fill(WidgetTester tester, String reason) async {
      await tester.ensureVisible(find.text(reason));
      await tester.tap(find.text(reason));
      await tester.pump();
      final send = find.widgetWithText(FilledButton, 'Gửi báo cáo');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Tùy chọn bài viết'));
      await tester.pumpAndSettle();
    }

    group('Explore details', () {
      Future<void> openDetails(WidgetTester tester, String text) async {
        // Tall enough for every tile to be visible and tappable.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tapTab(tester, exploreTab);
        await tester.tap(find.text(text).first);
        await tester.pumpAndSettle();
      }

      testWidgets("someone else's post can be reported", (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await _pump(tester, api);
        await openDetails(tester, 'Bài chỉ có trong Explore');

        await openMenu(tester);
        expect(find.text('Đổi quyền riêng tư'), findsNothing);
        await tester.tap(find.text('Báo cáo bài viết'));
        await tester.pumpAndSettle();
        await fill(tester, 'Spam hoặc quảng cáo');

        expect(api.reports, ['post:p2:spam:']);
        expect(find.text('Đã gửi báo cáo, cảm ơn bạn'), findsOneWidget);
      });

      testWidgets('blocking the author closes the details and the post goes', (
        tester,
      ) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await _pump(tester, api);
        await openDetails(tester, 'Bài chỉ có trong Explore');

        await openMenu(tester);
        await tester.tap(find.text('Chặn Lan Hương'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Chặn'));
        await tester.pumpAndSettle();

        expect(api.blocked, ['lan']);
        expect(
          find.byTooltip('Tùy chọn bài viết'),
          findsNothing,
        ); // sheet closed
        expect(find.text('Bài chỉ có trong Explore'), findsNothing);
      });

      testWidgets('my own post can change its audience', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me)
          ..extraPosts.add(_mine('m1', 'Bài của tôi'));
        await _pump(tester, api);
        await openDetails(tester, 'Bài của tôi');

        await openMenu(tester);
        expect(find.text('Báo cáo bài viết'), findsNothing);
        expect(find.textContaining('Chặn '), findsNothing);
        await tester.tap(find.text('Đổi quyền riêng tư'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bạn bè'));
        await tester.pumpAndSettle();

        expect(api.privacyChanges, ['m1:friends']);
        // no longer public: it left Explore, and the sheet closed with it
        expect(find.byTooltip('Tùy chọn bài viết'), findsNothing);
        expect(find.text('Bài của tôi'), findsNothing);
      });

      testWidgets('the mock app has no menu in the details', (tester) async {
        await pumpSocialHub(tester);
        await tapTab(tester, exploreTab);
        await tester.tap(find.text(mockPosts.first.content).first);
        await tester.pumpAndSettle();

        expect(find.byTooltip('Tùy chọn bài viết'), findsNothing);
      });
    });

    group('the opened post', () {
      Future<void> openPost(
        WidgetTester tester,
        _FakeRemoteApi api,
        String actorName,
      ) async {
        await _pump(tester, api);
        await tapTab(tester, notificationsTab);
        await tester.tap(find.textContaining(actorName));
        await tester.pumpAndSettle();
      }

      testWidgets("someone else's post can be reported", (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me)
          ..notifications = [
            _notification(id: 'n1', type: 'like', actor: _khang, postId: 'p1'),
          ];
        await openPost(tester, api, 'Duy Khang');

        await openMenu(tester);
        await tester.tap(find.text('Báo cáo bài viết'));
        await tester.pumpAndSettle();
        await fill(tester, 'Bạo lực');

        expect(api.reports, ['post:p1:violence:']);
      });

      testWidgets('blocking the author leaves the screen', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me)
          ..notifications = [
            _notification(id: 'n1', type: 'like', actor: _khang, postId: 'p1'),
          ];
        await openPost(tester, api, 'Duy Khang');

        await openMenu(tester);
        await tester.tap(find.text('Chặn Lan Hương'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Chặn'));
        await tester.pumpAndSettle();

        expect(api.blocked, ['lan']);
        expect(find.widgetWithText(AppBar, 'Bài viết'), findsNothing);
      });

      testWidgets('my own post changes its audience in place', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me)
          ..extraPosts.add(_mine('m1', 'Bài của tôi'))
          ..notifications = [
            _notification(id: 'n1', type: 'like', actor: _khang, postId: 'm1'),
          ];
        await openPost(tester, api, 'Duy Khang');
        expect(find.textContaining('· Công khai'), findsOneWidget);

        await openMenu(tester);
        await tester.tap(find.text('Đổi quyền riêng tư'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chỉ mình tôi'));
        await tester.pumpAndSettle();

        expect(api.privacyChanges, ['m1:only_me']);
        expect(find.textContaining('· Chỉ mình tôi'), findsOneWidget);
        expect(find.byTooltip('Xóa bài viết'), findsOneWidget); // delete stays
      });
    });
  });

  group('profile on the server', () {
    // Tall enough that nothing in a lazily built list is offscreen.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> openProfile(WidgetTester tester) {
      tall(tester);
      return tapTab(tester, profileTab);
    }

    Future<void> openSection(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, label));
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
    }

    testWidgets('the cover button uploads the picked photo', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api, pickPhoto: () async => '/photos/cover.jpg');
      await openProfile(tester);

      await tester.tap(find.text('Đổi ảnh bìa'));
      await tester.pumpAndSettle();

      expect(api.coverUploads, ['/photos/cover.jpg']);
    });

    testWidgets('cancelling the picker uploads nothing', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me);
      await _pump(tester, api);
      await openProfile(tester);

      await tester.tap(find.text('Đổi ảnh bìa'));
      await tester.pumpAndSettle();

      expect(api.coverUploads, isEmpty);
    });

    testWidgets('the mock app has no cover button', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, profileTab);

      expect(find.text('Đổi ảnh bìa'), findsNothing);
    });

    testWidgets('the Giới thiệu tab shows only the fields that are filled', (
      tester,
    ) async {
      final api = _FakeRemoteApi(
        sessionUser: _me.copyWith(
          about: const UserAbout(
            location: 'Hà Nội',
            workplace: 'SocialHub',
            birthday: '1998-05-17',
          ),
        ),
      );
      await _pump(tester, api);
      await openProfile(tester);

      await openSection(tester, 'Giới thiệu');

      expect(find.text('Hà Nội'), findsOneWidget);
      expect(find.text('SocialHub'), findsOneWidget);
      expect(find.text('17/05/1998'), findsOneWidget);
      expect(find.text('Nơi sống'), findsOneWidget);
      expect(find.text('Quê quán'), findsNothing); // empty: not shown
      expect(find.text('Học vấn'), findsNothing);
    });

    testWidgets('the Ảnh tab is loaded from the server and pages', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..photoPages = [
          const PhotoPage(
            photos: [ProfilePhoto(postId: 'p1', imageUrl: 'https://cdn/1.jpg')],
            nextCursor: 'c1',
          ),
          const PhotoPage(
            photos: [ProfilePhoto(postId: 'p2', imageUrl: 'https://cdn/2.jpg')],
          ),
        ];
      await _pump(tester, api);
      await openProfile(tester);

      await openSection(tester, 'Ảnh');

      expect(api.listCalls, ['photos:me:']);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(find.text('Xem thêm'));
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();

      expect(api.listCalls, ['photos:me:', 'photos:me:c1']);
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('Xem thêm'), findsNothing); // last page
    });

    testWidgets('an empty or failing Ảnh tab says so and can retry', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..listError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);
      await openProfile(tester);

      await openSection(tester, 'Ảnh');
      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      api
        ..listError = null
        ..photoPages = [const PhotoPage(photos: [])];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có hình ảnh nào'), findsOneWidget);
    });

    testWidgets('the Bạn bè tab comes from the server and opens a profile', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..friendPages = [
          UserPage(users: [_lan.copyWith(isFriend: true)]),
        ]
        ..profileToShow = UserProfile(
          user: _lan,
          friendship: Friendship.friends,
          posts: const [],
        );
      await _pump(tester, api);
      await openProfile(tester);

      await openSection(tester, 'Bạn bè');
      expect(api.listCalls, ['friends:me:']);
      await tester.tap(find.text('Lan Hương'));
      await tester.pumpAndSettle();

      expect(api.profilesLoaded, ['lan']);
    });

    testWidgets("another person's tabs ask for that person", (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..profileToShow = UserProfile(
          user: _lan,
          friendship: Friendship.friends,
          posts: const [],
        )
        ..photoPages = [const PhotoPage(photos: [])]
        ..friendPages = [const UserPage(users: [])];
      tall(tester);
      await _pump(tester, api);
      await tester.tap(find.text('Lan Hương').first);
      await tester.pumpAndSettle();

      await openSection(tester, 'Ảnh');
      await openSection(tester, 'Bạn bè');

      expect(api.listCalls, ['photos:lan:', 'friends:lan:']);
      expect(find.text('Chưa có bạn bè nào'), findsOneWidget);
    });

    testWidgets('the mock app keeps its local tabs', (tester) async {
      await pumpSocialHub(tester);
      await tapTab(tester, profileTab);
      await openSection(tester, 'Ảnh');

      expect(find.text('Xem thêm'), findsNothing);
    });

    group('Edit profile', () {
      Future<void> openEdit(WidgetTester tester) async {
        await openProfile(tester);
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();
      }

      testWidgets('saves the About fields', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await _pump(tester, api);
        await openEdit(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nơi sống'),
          '  Đà Nẵng ',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Website'),
          'https://example.com/me',
        );
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();

        final saved = api.updatedProfiles.single;
        expect(saved.about.location, 'Đà Nẵng');
        expect(saved.about.website, 'https://example.com/me');
        expect(saved.about.birthday, '');
      });

      testWidgets('a website must be an http address', (tester) async {
        final api = _FakeRemoteApi(sessionUser: _me);
        await _pump(tester, api);
        await openEdit(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Website'),
          'ftp://example.com',
        );
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();

        expect(
          find.text('Địa chỉ phải bắt đầu bằng http:// hoặc https://'),
          findsOneWidget,
        );
        expect(api.updatedProfiles, isEmpty);
      });

      testWidgets(
        'the birthday comes from the date picker and can be cleared',
        (tester) async {
          final api = _FakeRemoteApi(
            sessionUser: _me.copyWith(
              about: const UserAbout(birthday: '1998-05-17'),
            ),
          );
          await _pump(tester, api);
          await openEdit(tester);
          await tester.ensureVisible(find.text('17/05/1998'));
          expect(find.text('17/05/1998'), findsOneWidget);

          await tester.tap(find.byTooltip('Xóa ngày sinh'));
          await tester.pumpAndSettle();
          expect(find.text('Chưa chọn'), findsOneWidget);
          await tester.tap(find.text('Lưu'));
          await tester.pumpAndSettle();

          expect(api.updatedProfiles.single.about.birthday, '');
        },
      );

      testWidgets('the mock app has no About fields', (tester) async {
        await pumpSocialHub(tester);
        await tapTab(tester, profileTab);
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        expect(find.text('Nơi sống'), findsNothing);
      });
    });
  });

  group('friend suggestions on the server', () {
    Future<void> openSuggestions(WidgetTester tester) async {
      await tapTab(tester, friendsTab);
      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Người bạn có thể biết'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the tab shows what the server suggests', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..suggestionPages = [
          const UserPage(users: [_khang]),
        ];
      await _pump(tester, api);

      await openSuggestions(tester);

      expect(api.listCalls, ['suggestions:']);
      expect(find.text('Duy Khang'), findsOneWidget);
      expect(
        find.text('Lan Hương'),
        findsNothing,
      ); // a friend is not a suggestion
    });

    testWidgets('a suggestion can be added', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..suggestionPages = [
          const UserPage(users: [_khang]),
        ];
      await _pump(tester, api);
      await openSuggestions(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Thêm bạn'));
      await tester.pumpAndSettle();

      expect(api.friendRequests, ['khang']);
      expect(find.widgetWithText(OutlinedButton, 'Đang chờ'), findsOneWidget);
    });

    testWidgets('scrolling to the end loads the next page', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final many = [for (var i = 0; i < 12; i++) _stranger('s$i', 'Người $i')];
      final api = _FakeRemoteApi(sessionUser: _me)
        ..suggestionPages = [
          UserPage(users: many, nextCursor: 'c1'),
          UserPage(users: [_stranger('last', 'Người cuối')]),
        ];
      await _pump(tester, api);
      await openSuggestions(tester);

      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(api.listCalls, ['suggestions:', 'suggestions:c1']);
    });

    testWidgets('an error offers a retry and an empty list says so', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..listError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);
      await openSuggestions(tester);
      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      api
        ..listError = null
        ..suggestionPages = [const UserPage(users: [])];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có gợi ý nào'), findsOneWidget);
    });

    testWidgets('the mock app lists everyone who is not a friend', (
      tester,
    ) async {
      await pumpSocialHub(tester);
      await tapTab(tester, friendsTab);
      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Người bạn có thể biết'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có gợi ý nào'), findsNothing);
    });
  });

  group('"Đang theo dõi" feed tab', () {
    Future<void> openFollowing(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang theo dõi'));
      await tester.pumpAndSettle();
    }

    PostPage page(List<Post> posts, {String? next}) =>
        PostPage(posts: posts, nextCursor: next);

    testWidgets('opens the tab from the server, not from the loaded posts', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..followingPages = [
          page([_post('f1', 'Bài của người tôi theo dõi')]),
        ];
      await _pump(tester, api);
      expect(find.text('Bài trên bảng tin'), findsOneWidget);

      await openFollowing(tester);

      expect(api.feedFilterCalls, ['following:']);
      expect(find.text('Bài của người tôi theo dõi'), findsOneWidget);
      expect(find.text('Bài trên bảng tin'), findsNothing);
    });

    testWidgets('going back to "Dành cho bạn" shows the whole feed again', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..followingPages = [
          page([_post('f1', 'Bài của người tôi theo dõi')]),
        ];
      await _pump(tester, api);
      await openFollowing(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Dành cho bạn'));
      await tester.pumpAndSettle();

      expect(find.text('Bài trên bảng tin'), findsOneWidget);
      // the followed post is part of the feed too (older, so further down)
      await tester.scrollUntilVisible(
        find.text('Bài của người tôi theo dõi'),
        300,
        scrollable: visibleVerticalScrollable,
      );
      expect(find.text('Bài của người tôi theo dõi'), findsOneWidget);
    });

    testWidgets('an empty tab says so', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)..followingPages = [page([])];
      await _pump(tester, api);

      await openFollowing(tester);

      expect(
        find.text('Chưa có bài viết từ những người bạn theo dõi'),
        findsOneWidget,
      );
    });

    testWidgets('a failure shows the reason and can be retried', (
      tester,
    ) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..listError = const ApiException(
          code: 'network_error',
          message: 'Không thể kết nối tới máy chủ',
        );
      await _pump(tester, api);
      await openFollowing(tester);
      expect(find.text('Không thể kết nối tới máy chủ'), findsOneWidget);

      api
        ..listError = null
        ..followingPages = [
          page([_post('f1', 'Đã tải được')]),
        ];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Đã tải được'), findsOneWidget);
      expect(api.feedFilterCalls, ['following:', 'following:']);
    });

    testWidgets('scrolling to the end loads the next page of the tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeRemoteApi(sessionUser: _me)
        ..followingPages = [
          page([
            for (var i = 0; i < 12; i++) _post('f${100 - i}', 'Theo dõi $i'),
          ], next: 'c1'),
          page([_post('f1', 'Trang hai')]),
        ];
      await _pump(tester, api);
      await openFollowing(tester);

      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        visibleVerticalScrollable,
        const Offset(0, -3000),
        3000,
      );
      await tester.pumpAndSettle();

      expect(api.feedFilterCalls, ['following:', 'following:c1']);
    });

    testWidgets('pulling to refresh reloads the tab', (tester) async {
      final api = _FakeRemoteApi(sessionUser: _me)
        ..followingPages = [
          page([_post('f1', 'Bài của người tôi theo dõi')]),
        ];
      await _pump(tester, api);
      await openFollowing(tester);

      await tester.fling(visibleVerticalScrollable, const Offset(0, 500), 1000);
      await tester.pumpAndSettle();

      expect(api.feedFilterCalls, ['following:', 'following:']);
      expect(find.text('Bài của người tôi theo dõi'), findsOneWidget);
    });

    testWidgets('the mock app keeps filtering the posts it has', (
      tester,
    ) async {
      await pumpSocialHub(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang theo dõi'));
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có bài viết từ những người bạn theo dõi'),
        findsNothing,
      );
    });
  });

  testWidgets('the mock app does not open profiles from post authors', (
    tester,
  ) async {
    await pumpSocialHub(tester);

    await tester.tap(find.text('Minh Ánh').first);
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget); // still Home only
    expect(find.text('Thêm bạn'), findsNothing);
  });
}

String? _clipboard;
