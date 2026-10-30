import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/services/api_mappers.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/services/token_store.dart';

/// Talks to the Laravel API (docs/api/openapi.yaml). [baseUrl] includes the
/// version, for example `http://localhost:8000/api/v1`.
class HttpSocialApi extends SocialApi {
  final Dio _dio;
  final TokenStore _tokens;
  final Uri _origin;

  HttpSocialApi({
    required String baseUrl,
    required TokenStore tokenStore,
    Dio? dio,
  }) : _tokens = tokenStore,
       _origin = Uri.parse(baseUrl).replace(path: '', query: null),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
             ),
           ) {
    _dio.options
      ..baseUrl = baseUrl
      ..headers['Accept'] = 'application/json';
  }

  @override
  bool get isRemote => true;

  /// The server writes absolute URLs from its APP_URL (usually `localhost`),
  /// which a phone or emulator cannot reach; point them at the API host.
  String _absoluteUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return url;
    if (uri.host != 'localhost' && uri.host != '127.0.0.1') return url;
    return uri
        .replace(scheme: _origin.scheme, host: _origin.host, port: _origin.port)
        .toString();
  }

  // --- request helpers ------------------------------------------------------

  Future<Json> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool idempotent = false,
    bool authenticated = true,
  }) async {
    final headers = <String, dynamic>{};
    if (authenticated) {
      final token = await _tokens.read();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    // A retry after a timeout must not create the same thing twice.
    if (idempotent) headers['Idempotency-Key'] = _newIdempotencyKey();

    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      final body = response.data;
      return body is Json ? body : <String, dynamic>{};
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    final response = error.response;
    final body = response?.data;
    if (response == null || body is! Json) {
      return ApiException(
        statusCode: response?.statusCode,
        code: 'network_error',
        message: 'Không thể kết nối tới máy chủ',
      );
    }

    final rawErrors = body['errors'];
    return ApiException(
      statusCode: response.statusCode,
      code: (body['code'] as String?) ?? 'server_error',
      message: (body['message'] as String?) ?? 'Đã có lỗi xảy ra',
      errors: rawErrors is Map
          ? {
              for (final entry in rawErrors.entries)
                '${entry.key}': [for (final m in entry.value as List) '$m'],
            }
          : const {},
    );
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    String hex(int length) => List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final variant = (8 + random.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }

  List<Json> _list(Json response) => [
    for (final item in (response['data'] as List)) item as Json,
  ];

  // --- session --------------------------------------------------------------

  UserModel _me(Json response) =>
      userFromJson(response['data'] as Json, absoluteUrl: _absoluteUrl);

  @override
  Future<UserModel?> restoreSession() async {
    if (await _tokens.read() == null) return null;

    try {
      return _me(await _request('GET', '/me'));
    } on ApiException catch (error) {
      if (!error.isUnauthenticated) rethrow;
      await _tokens.clear();
      return null;
    }
  }

  Future<UserModel> _signedIn(Json response) async {
    final data = response['data'] as Json;
    await _tokens.write((data['token'] as Json)['accessToken'] as String);
    return userFromJson(data['user'] as Json, absoluteUrl: _absoluteUrl);
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async => _signedIn(
    await _request(
      'POST',
      '/auth/login',
      authenticated: false,
      data: {
        'email': email,
        'password': password,
        'deviceName': 'SocialHub app',
      },
    ),
  );

  @override
  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async => _signedIn(
    await _request(
      'POST',
      '/auth/register',
      authenticated: false,
      data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'deviceName': 'SocialHub app',
      },
    ),
  );

  @override
  Future<void> logout() async {
    try {
      await _request('POST', '/auth/logout');
    } on ApiException {
      // The token is dropped locally either way; a dead token is already out.
    }
    await _tokens.clear();
  }

  @override
  Future<void> registerDevice(String token, String platform) async {
    await _request(
      'PUT',
      '/me/devices',
      data: {'token': token, 'platform': platform},
    );
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _request('DELETE', '/me/devices', data: {'token': token});
  }

  @override
  Future<void> requestEmailVerification() async {
    await _request('POST', '/auth/email/verification');
  }

  @override
  Future<void> verifyEmail(String code) async {
    await _request('POST', '/auth/email/verify', data: {'code': code});
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _request(
      'POST',
      '/auth/password/forgot',
      authenticated: false,
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _request(
      'POST',
      '/auth/password/reset',
      authenticated: false,
      data: {'email': email, 'code': code, 'password': password},
    );
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _request('DELETE', '/me', data: {'password': password});
    await _tokens.clear();
  }

  // --- loading --------------------------------------------------------------

  @override
  Future<AppSnapshot> load(UserModel me) async {
    final responses = await Future.wait([
      _request('GET', '/feed', query: {'limit': 50}),
      _request('GET', '/explore', query: {'limit': 50}),
      _request('GET', '/stories', query: {'limit': 50}),
      _request('GET', '/users', query: {'limit': 50}),
      _request('GET', '/conversations', query: {'limit': 50}),
      _request('GET', '/notifications', query: {'limit': 50}),
      _request('GET', '/friend-requests', query: {'limit': 50}),
    ]);
    final feed = _list(responses[0]);
    final explore = _list(responses[1]);

    // A post can be in both lists; keep one copy.
    final byId = <String, Json>{
      for (final post in [...explore, ...feed]) post['id'] as String: post,
    };
    final users = _list(responses[3]);

    return AppSnapshot(
      posts:
          [
            for (final post in byId.values)
              postFromJson(post, absoluteUrl: _absoluteUrl),
          ]..sort(
            // ULIDs sort by creation time, so the id gives the order without
            // parsing the relative times the models carry.
            (a, b) => b.id.compareTo(a.id),
          ),
      feedPostIds: {for (final post in feed) post['id'] as String},
      savedPostIds: _idsWhere(byId.values, 'isSaved'),
      hiddenPostIds: _idsWhere(byId.values, 'isHidden'),
      stories: [
        for (final story in _list(responses[2]))
          storyFromJson(story, absoluteUrl: _absoluteUrl),
      ],
      users: [
        me,
        for (final user in users) userFromJson(user, absoluteUrl: _absoluteUrl),
      ],
      pendingFriendIds: {
        for (final user in users)
          if ((user['friendship'] as Json)['status'] == 'pending_outgoing')
            user['id'] as String,
      },
      conversations: [
        for (final conversation in _list(responses[4]))
          conversationFromJson(conversation, absoluteUrl: _absoluteUrl),
      ],
      notifications: [
        for (final notification in _list(responses[5]))
          notificationFromJson(notification, absoluteUrl: _absoluteUrl),
      ],
      friendRequests: [
        for (final request in _list(responses[6]))
          friendRequestFromJson(request, absoluteUrl: _absoluteUrl),
      ],
      feedCursor: _nextCursor(responses[0]),
      exploreCursor: _nextCursor(responses[1]),
      notificationsCursor: _nextCursor(responses[5]),
      usersCursor: _nextCursor(responses[3]),
    );
  }

  String? _nextCursor(Json page) =>
      (page['meta'] as Json?)?['nextCursor'] as String?;

  static const _moreLimit = 30;

  Future<PostPage> _postPage(String path, String cursor) async {
    final response = await _request(
      'GET',
      path,
      query: {'limit': _moreLimit, 'cursor': cursor},
    );
    final posts = _list(response);
    return PostPage(
      posts: [
        for (final post in posts) postFromJson(post, absoluteUrl: _absoluteUrl),
      ],
      nextCursor: _nextCursor(response),
      savedPostIds: _idsWhere(posts, 'isSaved'),
      hiddenPostIds: _idsWhere(posts, 'isHidden'),
    );
  }

  @override
  Future<PostPage> loadMoreFeed(String cursor) => _postPage('/feed', cursor);

  @override
  Future<PostPage> loadMoreExplore(String cursor) =>
      _postPage('/explore', cursor);

  @override
  Future<NotificationPage> loadMoreNotifications(String cursor) async {
    final response = await _request(
      'GET',
      '/notifications',
      query: {'limit': _moreLimit, 'cursor': cursor},
    );
    return NotificationPage(
      notifications: [
        for (final item in _list(response))
          notificationFromJson(item, absoluteUrl: _absoluteUrl),
      ],
      nextCursor: _nextCursor(response),
    );
  }

  @override
  Future<UserPage> searchUsers({String query = '', String? cursor}) async {
    final response = await _request(
      'GET',
      '/users',
      query: {
        'limit': _moreLimit,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'cursor': ?cursor,
      },
    );
    final users = _list(response);
    return UserPage(
      users: [
        for (final user in users) userFromJson(user, absoluteUrl: _absoluteUrl),
      ],
      pendingIds: {
        for (final user in users)
          if ((user['friendship'] as Json)['status'] == 'pending_outgoing')
            user['id'] as String,
      },
      nextCursor: _nextCursor(response),
    );
  }

  Set<String> _idsWhere(Iterable<Json> posts, String flag) => {
    for (final post in posts)
      if (post[flag] == true) post['id'] as String,
  };

  // --- changes --------------------------------------------------------------

  /// The draft's photo when it was picked on this device (a file path).
  /// Server URLs and bundled assets are not uploaded.
  String? _localPhoto(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('assets/') || imageUrl.startsWith('http')) {
      return null;
    }
    return imageUrl;
  }

  /// JSON for a text-only create call, multipart when a photo goes with it.
  Future<Object> _body(Map<String, Object?> fields, String? photoPath) async {
    final present = {
      for (final entry in fields.entries)
        if (entry.value != null && entry.value != '') entry.key: entry.value,
    };
    if (photoPath == null) return fields;

    return FormData.fromMap({
      ...present,
      'image': await MultipartFile.fromFile(photoPath),
    });
  }

  @override
  Future<Post> createPost(Post draft) async => postFromJson(
    (await _request(
          'POST',
          '/posts',
          idempotent: true,
          data: await _body({
            'content': draft.content,
            'feeling': feelingValue(draft.feeling),
            'privacy': privacyValue(draft.privacy) ?? 'public',
          }, _localPhoto(draft.imageUrl)),
        ))['data']
        as Json,
    absoluteUrl: _absoluteUrl,
  );

  @override
  Future<Story> createStory(Story draft) async => storyFromJson(
    (await _request(
          'POST',
          '/stories',
          idempotent: true,
          data: await _body({
            'text': draft.text,
            'background': storyBackgroundFor(draft.gradientColors),
          }, _localPhoto(draft.imageUrl)),
        ))['data']
        as Json,
    absoluteUrl: _absoluteUrl,
  );

  @override
  Future<ChatMessage> sendMessage(
    String conversationId,
    ChatMessage draft,
  ) async => messageFromJson(
    (await _request(
          'POST',
          '/conversations/$conversationId/messages',
          idempotent: true,
          data: {'text': draft.text},
        ))['data']
        as Json,
  );

  @override
  Future<void> deletePost(String postId) async {
    await _request('DELETE', '/posts/$postId');
  }

  @override
  Future<Post> loadPost(String postId) async => postFromJson(
    (await _request('GET', '/posts/$postId'))['data'] as Json,
    absoluteUrl: _absoluteUrl,
  );

  @override
  Future<void> markStoryViewed(String storyId) async {
    await _request('POST', '/stories/$storyId/view');
  }

  @override
  Future<List<Post>> loadSavedPosts() async => [
    for (final post in _list(
      await _request('GET', '/me/saved-posts', query: {'limit': 50}),
    ))
      postFromJson(post, absoluteUrl: _absoluteUrl),
  ];

  @override
  Future<void> setLiked(String postId, bool liked) async {
    await _request(liked ? 'PUT' : 'DELETE', '/posts/$postId/like');
  }

  @override
  Future<void> setSaved(String postId, bool saved) async {
    await _request(saved ? 'PUT' : 'DELETE', '/posts/$postId/save');
  }

  @override
  Future<void> setHidden(String postId, bool hidden) async {
    await _request(hidden ? 'PUT' : 'DELETE', '/posts/$postId/hide');
  }

  @override
  Future<void> sendFriendRequest(String userId) async {
    await _request('POST', '/friend-requests', data: {'userId': userId});
  }

  @override
  Future<UserModel> acceptFriendRequest(String requestId) async =>
      _me(await _request('POST', '/friend-requests/$requestId/accept'));

  @override
  Future<void> deleteFriendRequest(String requestId) async {
    await _request('DELETE', '/friend-requests/$requestId');
  }

  @override
  Future<void> unfriend(String userId) async {
    await _request('DELETE', '/friends/$userId');
  }

  @override
  Future<List<Comment>> loadComments(String postId) async => [
    for (final comment in _list(
      await _request('GET', '/posts/$postId/comments', query: {'limit': 50}),
    ))
      commentFromJson(comment, absoluteUrl: _absoluteUrl),
  ];

  @override
  Future<({Comment comment, int commentsCount})> addComment(
    String postId,
    String text,
  ) async {
    final response = await _request(
      'POST',
      '/posts/$postId/comments',
      idempotent: true,
      data: {'content': text},
    );
    return (
      comment: commentFromJson(
        response['data'] as Json,
        absoluteUrl: _absoluteUrl,
      ),
      commentsCount: (response['meta'] as Json)['commentsCount'] as int,
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _request('DELETE', '/comments/$commentId');
  }

  @override
  Future<int> sharePost(String postId, String target) async {
    final response = await _request(
      'POST',
      '/posts/$postId/shares',
      data: {'target': target},
    );
    return (response['data'] as Json)['shares'] as int;
  }

  @override
  Future<UserProfile> loadProfile(String userId) async {
    final responses = await Future.wait([
      _request('GET', '/users/$userId'),
      _request('GET', '/users/$userId/posts', query: {'limit': 20}),
    ]);
    final profile = responses[0]['data'] as Json;
    final friendship = profile['friendship'] as Json;

    return UserProfile(
      user: userFromJson(profile, absoluteUrl: _absoluteUrl),
      friendship: friendshipFromJson(friendship['status'] as String?),
      requestId: friendship['requestId'] as String?,
      isBlocked: profile['isBlocked'] == true,
      posts: [
        for (final post in _list(responses[1]))
          postFromJson(post, absoluteUrl: _absoluteUrl),
      ],
    );
  }

  @override
  Future<List<ChatMessage>?> loadMessages(String conversationId) async {
    final response = await _request(
      'GET',
      '/conversations/$conversationId/messages',
      query: {'limit': 100},
    );
    // The API answers newest first; the chat shows oldest first.
    return [
      for (final message in _list(response).reversed) messageFromJson(message),
    ];
  }

  @override
  Future<List<ChatMessage>> loadNewMessages(
    String conversationId, {
    String? afterMessageId,
  }) async {
    if (afterMessageId == null) {
      return await loadMessages(conversationId) ?? const [];
    }

    // `after` pages oldest first and says when there is more.
    final messages = <ChatMessage>[];
    var after = afterMessageId;
    while (true) {
      final response = await _request(
        'GET',
        '/conversations/$conversationId/messages',
        query: {'after': after, 'limit': 100},
      );
      final page = [
        for (final message in _list(response)) messageFromJson(message),
      ];
      messages.addAll(page);
      final hasMore = (response['meta'] as Json)['hasMore'] == true;
      if (!hasMore || page.isEmpty) return messages;
      after = page.last.id;
    }
  }

  @override
  Future<List<Conversation>> loadConversations() async => [
    for (final conversation in _list(
      await _request('GET', '/conversations', query: {'limit': 50}),
    ))
      conversationFromJson(conversation, absoluteUrl: _absoluteUrl),
  ];

  @override
  Future<Conversation> startConversation(UserModel friend) async =>
      conversationFromJson(
        (await _request(
              'POST',
              '/conversations',
              data: {'userId': friend.id},
            ))['data']
            as Json,
        absoluteUrl: _absoluteUrl,
      );

  @override
  Future<void> updatePostPrivacy(String postId, String privacy) async {
    await _request('PATCH', '/posts/$postId', data: {'privacy': privacy});
  }

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    await _request(
      'POST',
      '/reports',
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty) 'details': details,
      },
    );
  }

  @override
  Future<void> blockUser(String userId) async {
    await _request('PUT', '/users/$userId/block');
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _request('DELETE', '/users/$userId/block');
  }

  @override
  Future<List<UserModel>> loadBlockedUsers() async {
    final users = <UserModel>[];
    String? cursor;
    // Few people are blocked; follow the pages instead of showing a partial list.
    for (var page = 0; page < 20; page++) {
      final response = await _request(
        'GET',
        '/me/blocks',
        query: {'limit': 50, 'cursor': ?cursor},
      );
      users.addAll([
        for (final user in _list(response))
          userFromJson(user, absoluteUrl: _absoluteUrl),
      ]);
      final meta = response['meta'] as Json;
      cursor = meta['nextCursor'] as String?;
      if (meta['hasMore'] != true || cursor == null) break;
    }
    return users;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    await _request('POST', '/conversations/$conversationId/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _request('POST', '/notifications/read');
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async => _me(
    await _request('PATCH', '/me', data: {'name': user.name, 'bio': user.bio}),
  );

  @override
  Future<UserModel> uploadAvatar(String filePath) async => _me(
    await _request(
      'POST',
      '/me/avatar',
      data: FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      }),
    ),
  );
}
