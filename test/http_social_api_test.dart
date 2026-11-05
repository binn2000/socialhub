import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/post_video.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/services/http_social_api.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/services/token_store.dart';

/// Answers requests from a table instead of the network. Keys look like
/// "GET /feed"; the value is (status, JSON body).
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> requests = [];

  RequestOptions last(String key) =>
      requests.lastWhere((r) => '${r.method} ${r.path}' == key);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route == null) {
      return ResponseBody.fromString(
        '{"message":"Not found.","code":"not_found"}',
        404,
        headers: _json,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(route.$2),
      route.$1,
      headers: _json,
    );
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _summary(String id, String name, {String? avatar}) => {
  'id': id,
  'name': name,
  // Usernames are ASCII, unlike display names.
  'username': 'user_$id',
  'avatarUrl': avatar,
};

Map<String, dynamic> _me() => {
  ..._summary('me', 'Minh Ánh', avatar: 'http://localhost:8000/storage/a.png'),
  'email': 'minh@example.com',
  'bio': 'Designer',
  'friendsCount': 2,
  'createdAt': '2026-10-01T00:00:00Z',
};

Map<String, dynamic> _post(
  String id, {
  String privacy = 'public',
  bool hidden = false,
  bool saved = false,
}) => {
  'id': id,
  'author': _summary('u2', 'Lan Hương'),
  'content': 'post $id',
  'imageUrl': null,
  'feeling': null,
  'privacy': privacy,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'likes': 1,
  'comments': 0,
  'shares': 0,
  'isLiked': false,
  'isSaved': saved,
  'isHidden': hidden,
};

Map<String, dynamic> _page(List<Object?> data) => {
  'data': data,
  'meta': {'nextCursor': null, 'hasMore': false},
};

void main() {
  late _FakeAdapter adapter;
  late MemoryTokenStore tokens;
  late HttpSocialApi api;

  setUp(() {
    adapter = _FakeAdapter();
    tokens = MemoryTokenStore();
    final dio = Dio()..httpClientAdapter = adapter;
    api = HttpSocialApi(
      baseUrl: 'http://10.0.2.2:8000/api/v1',
      tokenStore: tokens,
      dio: dio,
    );
  });

  test('login stores the token and later calls send it', () async {
    adapter.routes['POST /auth/login'] = (
      200,
      {
        'data': {
          'user': _me(),
          'token': {
            'accessToken': '1|secret',
            'tokenType': 'Bearer',
            'expiresAt': '2026-11-01T00:00:00Z',
          },
        },
      },
    );
    adapter.routes['GET /me'] = (200, {'data': _me()});

    final user = await api.login(email: 'minh@example.com', password: 'pw');
    await api.restoreSession();

    expect(user.username, '@user_me');
    expect(await tokens.read(), '1|secret');
    expect(
      adapter.last('POST /auth/login').headers.containsKey('Authorization'),
      isFalse,
    );
    expect(adapter.last('GET /me').headers['Authorization'], 'Bearer 1|secret');
  });

  test('avatar urls on localhost are pointed at the API host', () async {
    adapter.routes['GET /me'] = (200, {'data': _me()});
    await tokens.write('t');

    final user = await api.restoreSession();

    expect(user!.avatarUrl, 'http://10.0.2.2:8000/storage/a.png');
  });

  test(
    'restoreSession is null without a token, and drops a rejected one',
    () async {
      expect(await api.restoreSession(), isNull);
      expect(adapter.requests, isEmpty);

      await tokens.write('old');
      adapter.routes['GET /me'] = (
        401,
        {'message': 'Unauthenticated.', 'code': 'unauthenticated'},
      );

      expect(await api.restoreSession(), isNull);
      expect(await tokens.read(), isNull);
    },
  );

  test('API errors become ApiException with the field messages', () async {
    adapter.routes['POST /auth/register'] = (
      422,
      {
        'message': 'Validation failed.',
        'code': 'validation_failed',
        'errors': {
          'email': ['The email has already been taken.'],
        },
      },
    );

    await expectLater(
      api.register(name: 'A', username: 'a', email: 'a@b.vn', password: 'x'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.code, 'code', 'validation_failed')
            .having(
              (e) => e.displayMessage,
              'message',
              'The email has already been taken.',
            ),
      ),
    );
  });

  test('a server that cannot be reached is a network_error', () async {
    final failing = HttpSocialApi(
      baseUrl: 'http://10.0.2.2:8000/api/v1',
      tokenStore: tokens,
      dio: Dio()..httpClientAdapter = _ThrowingAdapter(),
    );

    await expectLater(
      failing.login(email: 'a@b.vn', password: 'x'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'network_error'),
      ),
    );
  });

  test('logout clears the token even when the server call fails', () async {
    await tokens.write('t');
    adapter.routes['POST /auth/logout'] = (
      401,
      {'message': 'Unauthenticated.', 'code': 'unauthenticated'},
    );

    await api.logout();

    expect(await tokens.read(), isNull);
  });

  test('account calls use the contract paths and bodies', () async {
    adapter.routes['POST /auth/email/verification'] = (202, {});
    adapter.routes['POST /auth/email/verify'] = (200, {'data': _me()});
    adapter.routes['POST /auth/password/forgot'] = (202, {});
    adapter.routes['POST /auth/password/reset'] = (204, null);
    adapter.routes['DELETE /me'] = (204, null);
    await tokens.write('t');

    await api.requestEmailVerification();
    await api.verifyEmail('123456');
    await api.requestPasswordReset('a@b.vn');
    await api.resetPassword(
      email: 'a@b.vn',
      code: '654321',
      password: 'new-pass-1',
    );
    await api.deleteAccount('pw');

    expect(adapter.last('POST /auth/email/verify').data, {'code': '123456'});
    expect(adapter.last('POST /auth/password/forgot').data, {
      'email': 'a@b.vn',
    });
    expect(adapter.last('POST /auth/password/reset').data, {
      'email': 'a@b.vn',
      'code': '654321',
      'password': 'new-pass-1',
    });
    expect(adapter.last('DELETE /me').data, {'password': 'pw'});
    // reset is for someone who is signed out
    expect(
      adapter
          .last('POST /auth/password/reset')
          .headers
          .containsKey('Authorization'),
      isFalse,
    );
    expect(await tokens.read(), isNull); // deleting the account drops the token
  });

  test('a wrong code is an ApiException with the field message', () async {
    adapter.routes['POST /auth/email/verify'] = (
      422,
      {
        'message': 'Mã không đúng',
        'code': 'invalid_code',
        'errors': {
          'code': ['Mã không đúng'],
        },
      },
    );
    await tokens.write('t');

    await expectLater(
      api.verifyEmail('000000'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'invalid_code')
            .having((e) => e.displayMessage, 'message', 'Mã không đúng'),
      ),
    );
  });

  test('load merges feed and explore into one snapshot', () async {
    adapter.routes['GET /feed'] = (
      200,
      _page([_post('02'), _post('03', privacy: 'friends', hidden: true)]),
    );
    adapter.routes['GET /explore'] = (
      200,
      _page([_post('01', saved: true), _post('02')]),
    );
    adapter.routes['GET /stories'] = (
      200,
      _page([
        {
          'id': 's1',
          'author': _summary('u2', 'Lan Hương'),
          'text': 'Tin',
          'imageUrl': null,
          'background': 'mint',
          'createdAt': '2026-10-23T00:00:00Z',
          'expiresAt': '2026-10-24T00:00:00Z',
          'isViewed': true,
        },
      ]),
    );
    adapter.routes['GET /users'] = (
      200,
      _page([
        {
          ..._summary('u2', 'Lan Hương'),
          'mutualFriendsCount': 1,
          'friendship': {'status': 'friends', 'requestId': null},
        },
        {
          ..._summary('u3', 'Duy Khang'),
          'mutualFriendsCount': 0,
          'friendship': {'status': 'pending_outgoing', 'requestId': 'r1'},
        },
        {
          ..._summary('u4', 'Bảo Trâm'),
          'mutualFriendsCount': 0,
          'friendship': {'status': 'none', 'requestId': null},
        },
      ]),
    );
    adapter.routes['GET /conversations'] = (200, _page([]));
    adapter.routes['GET /notifications'] = (200, _page([]));
    adapter.routes['GET /friend-requests'] = (
      200,
      _page([
        {
          'id': 'r1',
          'sender': _summary('u4', 'Bảo Trâm'),
          'receiver': _summary('me', 'Minh Ánh'),
          'createdAt': '2026-10-23T00:00:00Z',
        },
      ]),
    );
    final me = (await _signedInUser(api, adapter, tokens));

    final snapshot = await api.load(me);

    expect(snapshot.posts.map((p) => p.id), [
      '03',
      '02',
      '01',
    ]); // newest id first, no duplicates
    expect(snapshot.feedPostIds, {'02', '03'});
    expect(snapshot.hiddenPostIds, {'03'});
    expect(snapshot.savedPostIds, {'01'});
    expect(snapshot.stories.single.isViewed, isTrue);
    expect(snapshot.users.map((u) => u.id), ['me', 'u2', 'u3', 'u4']);
    expect(snapshot.users[1].isFriend, isTrue);
    expect(snapshot.pendingFriendIds, {'u3'});
    expect(snapshot.friendRequests.single.id, 'r1');
    expect(snapshot.friendRequests.single.sender.id, 'u4');
  });

  test(
    'createPost sends API values and an Idempotency-Key, and returns the stored post',
    () async {
      adapter.routes['POST /posts'] = (201, {'data': _post('99')});
      final me = await _signedInUser(api, adapter, tokens);

      final saved = await api.createPost(
        Post(
          id: 'temp',
          author: me,
          content: 'Xin chào',
          feeling: 'Hứng thú',
          privacy: 'Bạn bè',
          createdAt: 'Vừa xong',
          likes: 0,
          comments: 0,
          shares: 0,
          isLiked: false,
        ),
      );

      final request = adapter.last('POST /posts');
      expect(request.data, {
        'content': 'Xin chào',
        'feeling': 'excited',
        'privacy': 'friends',
      });
      expect(
        request.headers['Idempotency-Key'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(saved.id, '99');
    },
  );

  test('a post with a picked video is uploaded as multipart', () async {
    adapter.routes['POST /posts'] = (
      201,
      {
        'data': {
          ..._post('99'),
          'video': {
            'status': 'processing',
            'url': null,
            'thumbnailUrl': null,
            'durationSeconds': null,
            'width': null,
            'height': null,
          },
        },
      },
    );
    final me = await _signedInUser(api, adapter, tokens);
    final clip = File('${Directory.systemTemp.path}/http_api_test_clip.mp4')
      ..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(clip.deleteSync);

    final saved = await api.createPost(
      Post(
        id: 'tmp',
        author: me,
        content: 'Clip',
        privacy: 'Công khai',
        createdAt: 'Vừa xong',
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
        video: PostVideo.draft(clip.path),
      ),
    );

    final data = adapter.last('POST /posts').data as FormData;
    expect(data.files.map((f) => f.key), ['video']);
    expect(saved.video?.isProcessing, isTrue);
  });

  test('several photos are sent as images[] so PHP reads a list', () async {
    adapter.routes['POST /posts'] = (201, {'data': _post('99')});
    final me = await _signedInUser(api, adapter, tokens);
    final photos = [
      for (final n in [1, 2])
        File('${Directory.systemTemp.path}/http_api_test_multi$n.png')
          ..writeAsBytesSync(const [1, 2, 3]),
    ];
    addTearDown(() {
      for (final f in photos) {
        f.deleteSync();
      }
    });

    await api.createPost(
      Post(
        id: 'tmp',
        author: me,
        content: 'Hai ảnh',
        privacy: 'Công khai',
        imageUrl: photos.first.path,
        imageUrls: [for (final f in photos) f.path],
        createdAt: 'Vừa xong',
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
      ),
    );

    final data = adapter.last('POST /posts').data as FormData;
    expect(data.files.map((f) => f.key), ['images[]', 'images[]']);
  });

  test('several chat attachments are sent as attachments[]', () async {
    adapter.routes['POST /conversations/c1/messages'] = (
      201,
      {
        'data': {
          'id': 'm9',
          'conversationId': 'c1',
          'senderId': 'me',
          'text': '',
          'attachments': <Object>[],
          'createdAt': '2026-10-23T10:00:03Z',
        },
      },
    );
    await _signedInUser(api, adapter, tokens);
    final files = [
      for (final n in [1, 2])
        File('${Directory.systemTemp.path}/http_api_test_att$n.png')
          ..writeAsBytesSync(const [1, 2, 3]),
    ];
    addTearDown(() {
      for (final f in files) {
        f.deleteSync();
      }
    });

    await api.sendMessage(
      'c1',
      const ChatMessage(id: 'tmp', senderId: 'me', text: '', time: ''),
      attachmentPaths: [for (final f in files) f.path],
    );

    final data =
        adapter.last('POST /conversations/c1/messages').data as FormData;
    expect(data.files.map((f) => f.key), ['attachments[]', 'attachments[]']);
  });

  test('a post with a picked photo is uploaded as multipart', () async {
    adapter.routes['POST /posts'] = (201, {'data': _post('99')});
    final me = await _signedInUser(api, adapter, tokens);
    final photo = File('${Directory.systemTemp.path}/http_api_test_photo.png')
      ..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(photo.deleteSync);

    await api.createPost(
      Post(
        id: 'tmp',
        author: me,
        content: '',
        feeling: 'Cảm thấy vui',
        privacy: 'Công khai',
        imageUrl: photo.path,
        createdAt: 'Vừa xong',
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
      ),
    );

    final data = adapter.last('POST /posts').data as FormData;
    expect(data.files.map((f) => f.key), ['image']);
    expect(data.fields.map((f) => f.key), containsAll(['feeling', 'privacy']));
    expect(data.fields.map((f) => f.key), isNot(contains('content')));
  });

  test('a server photo or a bundled asset is not uploaded again', () async {
    adapter.routes['POST /posts'] = (201, {'data': _post('99')});
    final me = await _signedInUser(api, adapter, tokens);

    for (final url in [
      'http://localhost:8000/storage/a.png',
      'assets/placeholder.png',
    ]) {
      await api.createPost(
        Post(
          id: 'tmp',
          author: me,
          content: 'Chữ',
          imageUrl: url,
          createdAt: 'Vừa xong',
          likes: 0,
          comments: 0,
          shares: 0,
          isLiked: false,
        ),
      );
      expect(adapter.last('POST /posts').data, isA<Map>(), reason: url);
    }
  });

  test('a photo-only story is uploaded without text', () async {
    adapter.routes['POST /stories'] = (
      201,
      {
        'data': {
          'id': 's9',
          'author': _summary('me', 'Minh Ánh'),
          'text': null,
          'imageUrl': 'http://localhost:8000/storage/stories/s.png',
          'background': 'berry',
          'createdAt': '2026-10-23T00:00:00Z',
          'expiresAt': '2026-10-24T00:00:00Z',
          'isViewed': false,
        },
      },
    );
    final me = await _signedInUser(api, adapter, tokens);
    final photo = File('${Directory.systemTemp.path}/http_api_test_story.png')
      ..writeAsBytesSync(const [1]);
    addTearDown(photo.deleteSync);

    final story = await api.createStory(
      Story(
        id: 'tmp',
        user: me,
        imageUrl: photo.path,
        isViewed: false,
        gradientColors: const [Color(0xFFE84393), Color(0xFF6C5CE7)],
      ),
    );

    final data = adapter.last('POST /stories').data as FormData;
    expect(data.files.map((f) => f.key), ['image']);
    expect(data.fields.map((f) => f.key), ['background', 'privacy']);
    expect(data.fields.first.value, 'berry');
    expect(data.fields.last.value, 'friends');
    expect(story.imageUrl, 'http://10.0.2.2:8000/storage/stories/s.png');
  });

  test(
    'accepting returns the new friend; declining and unfriending delete',
    () async {
      adapter.routes['POST /friend-requests/r1/accept'] = (
        200,
        {
          'data': {
            ..._summary('u4', 'Bảo Trâm'),
            'bio': null,
            'friendsCount': 3,
            'mutualFriendsCount': 1,
            'friendship': {'status': 'friends', 'requestId': null},
          },
        },
      );
      adapter.routes['DELETE /friend-requests/r2'] = (204, null);
      adapter.routes['DELETE /friends/u4'] = (204, null);

      final friend = await api.acceptFriendRequest('r1');
      await api.deleteFriendRequest('r2');
      await api.unfriend('u4');

      expect(friend.id, 'u4');
      expect(friend.isFriend, isTrue);
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /friend-requests/r1/accept',
        'DELETE /friend-requests/r2',
        'DELETE /friends/u4',
      ]);
    },
  );

  test('comments: list, add with the new count, delete', () async {
    final comment = {
      'id': 'c1',
      'postId': 'p1',
      'author': _summary('u2', 'Lan Hương'),
      'content': 'Hay quá',
      'createdAt': '2026-10-23T10:00:00Z',
    };
    adapter.routes['GET /posts/p1/comments'] = (200, _page([comment]));
    adapter.routes['POST /posts/p1/comments'] = (
      201,
      {
        'data': comment,
        'meta': {'commentsCount': 5},
      },
    );
    adapter.routes['DELETE /comments/c1'] = (204, null);

    final list = await api.loadComments('p1');
    final added = await api.addComment('p1', 'Hay quá');
    await api.deleteComment('c1');

    expect(list.single.content, 'Hay quá');
    expect(added.commentsCount, 5);
    expect(adapter.last('POST /posts/p1/comments').data, {
      'content': 'Hay quá',
    });
    expect(
      adapter.last('POST /posts/p1/comments').headers['Idempotency-Key'],
      isNotNull,
    );
    expect(adapter.requests.last.method, 'DELETE');
  });

  test('sharing sends the target and returns the count', () async {
    adapter.routes['POST /posts/p1/shares'] = (
      200,
      {
        'data': {'shares': 7},
      },
    );

    expect(await api.sharePost('p1', 'message'), 7);
    expect(adapter.last('POST /posts/p1/shares').data, {'target': 'message'});
  });

  test('a profile joins the user, the friendship and the posts', () async {
    adapter.routes['GET /users/u2'] = (
      200,
      {
        'data': {
          ..._summary('u2', 'Lan Hương'),
          'bio': 'Hello',
          'friendsCount': 9,
          'mutualFriendsCount': 2,
          'friendship': {'status': 'pending_incoming', 'requestId': 'r7'},
        },
      },
    );
    adapter.routes['GET /users/u2/posts'] = (200, _page([_post('p9')]));

    final profile = await api.loadProfile('u2');

    expect(profile.user.bio, 'Hello');
    expect(profile.user.mutualFriends, 9);
    expect(profile.friendship, Friendship.pendingIncoming);
    expect(profile.requestId, 'r7');
    expect(profile.posts.single.id, 'p9');
  });

  test('deleting a post, loading one post and marking a story seen', () async {
    adapter.routes['DELETE /posts/p1'] = (204, null);
    adapter.routes['GET /posts/p2'] = (200, {'data': _post('p2')});
    adapter.routes['POST /stories/s1/view'] = (204, null);

    await api.deletePost('p1');
    final post = await api.loadPost('p2');
    await api.markStoryViewed('s1');

    expect(post.id, 'p2');
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'DELETE /posts/p1',
      'GET /posts/p2',
      'POST /stories/s1/view',
    ]);
  });

  test('a missing post is an ApiException with the status', () async {
    await expectLater(
      api.loadPost('gone'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('saved posts come from /me/saved-posts in the server order', () async {
    adapter.routes['GET /me/saved-posts'] = (
      200,
      _page([_post('02', saved: true), _post('01', saved: true)]),
    );

    final posts = await api.loadSavedPosts();

    expect(posts.map((p) => p.id), ['02', '01']);
    expect(adapter.last('GET /me/saved-posts').queryParameters['limit'], 50);
  });

  test('likes use PUT and DELETE', () async {
    adapter.routes['PUT /posts/p1/like'] = (
      200,
      {
        'data': {'isLiked': true, 'likes': 2},
      },
    );
    adapter.routes['DELETE /posts/p1/like'] = (
      200,
      {
        'data': {'isLiked': false, 'likes': 1},
      },
    );

    await api.setLiked('p1', true);
    await api.setLiked('p1', false);

    expect(adapter.requests.map((r) => r.method), ['PUT', 'DELETE']);
  });

  test('a reaction is sent in the body of the like request', () async {
    adapter.routes['PUT /posts/p1/like'] = (
      200,
      {
        'data': {
          'isLiked': true,
          'likes': 1,
          'reaction': 'love',
          'reactionCounts': {'love': 1},
        },
      },
    );
    await _signedInUser(api, adapter, tokens);

    await api.setLiked('p1', true, reaction: 'love');

    expect(adapter.last('PUT /posts/p1/like').data, {'reaction': 'love'});
  });

  test(
    'messages are returned oldest first and sending maps the reply',
    () async {
      adapter.routes['GET /conversations/c1/messages'] = (
        200,
        _page([
          {
            'id': 'm2',
            'conversationId': 'c1',
            'senderId': 'u2',
            'text': 'second',
            'createdAt': '2026-10-23T10:00:02Z',
          },
          {
            'id': 'm1',
            'conversationId': 'c1',
            'senderId': 'me',
            'text': 'first',
            'createdAt': '2026-10-23T10:00:01Z',
          },
        ]),
      );
      adapter.routes['POST /conversations/c1/messages'] = (
        201,
        {
          'data': {
            'id': 'm3',
            'conversationId': 'c1',
            'senderId': 'me',
            'text': 'hello',
            'createdAt': '2026-10-23T10:00:03Z',
          },
        },
      );

      final messages = await api.loadMessages('c1');
      final sent = await api.sendMessage(
        'c1',
        const ChatMessage(id: 'tmp', senderId: 'me', text: 'hello', time: ''),
      );

      expect(messages!.map((m) => m.text), ['first', 'second']);
      expect(sent.id, 'm3');
      expect(adapter.last('POST /conversations/c1/messages').data, {
        'text': 'hello',
      });
    },
  );

  test('polling asks after the last message and follows hasMore', () async {
    Map<String, dynamic> m(String id) => {
      'id': id,
      'conversationId': 'c1',
      'senderId': 'u2',
      'text': 'tin $id',
      'createdAt': '2026-10-23T10:00:00Z',
    };
    final pages = [
      {
        'data': [m('m2'), m('m3')],
        'meta': {'nextCursor': null, 'hasMore': true},
      },
      {
        'data': [m('m4')],
        'meta': {'nextCursor': null, 'hasMore': false},
      },
    ];
    final adapter2 = _SequenceAdapter(pages);
    final polled = HttpSocialApi(
      baseUrl: 'http://10.0.2.2:8000/api/v1',
      tokenStore: tokens,
      dio: Dio()..httpClientAdapter = adapter2,
    );

    final messages = (await polled.loadNewMessages(
      'c1',
      afterMessageId: 'm1',
    )).messages;

    expect(messages.map((x) => x.id), ['m2', 'm3', 'm4']);
    expect(adapter2.queries, [
      {'after': 'm1', 'limit': 100},
      {'after': 'm3', 'limit': 100},
    ]);
  });

  test('notification filters, conversation search and story delete', () async {
    adapter.routes['GET /notifications'] = (200, _page([]));
    adapter.routes['GET /conversations'] = (200, _page([]));
    adapter.routes['DELETE /stories/s1'] = (204, null);
    await tokens.write('t');

    final page = await api.loadNotificationCategory('friends', cursor: 'abc');
    final found = await api.searchConversations('  lan ');
    await api.deleteStory('s1');

    expect(page.notifications, isEmpty);
    expect(
      adapter.requests
          .firstWhere((r) => r.path == '/notifications')
          .queryParameters,
      {'limit': 30, 'cursor': 'abc', 'category': 'friends'},
    );
    expect(found, isEmpty);
    expect(
      adapter.requests
          .firstWhere((r) => r.path == '/conversations')
          .queryParameters,
      {'limit': 50, 'q': 'lan'},
    );
    expect(
      adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/stories/s1',
      ),
      isTrue,
    );
  });

  test('load reads the unread count and survives it failing', () async {
    for (final path in [
      '/feed',
      '/explore',
      '/stories',
      '/users',
      '/conversations',
      '/notifications',
      '/friend-requests',
    ]) {
      adapter.routes['GET $path'] = (200, _page([]));
    }
    adapter.routes['GET /notifications/unread-count'] = (
      200,
      {
        'data': {'count': 9},
      },
    );
    final me = await _signedInUser(api, adapter, tokens);

    expect((await api.load(me)).unreadNotificationCount, 9);

    adapter.routes['GET /notifications/unread-count'] = (
      500,
      {'message': 'x', 'code': 'server_error'},
    );
    expect((await api.load(me)).unreadNotificationCount, isNull);
  });

  test('polling reports whether the other person is typing', () async {
    adapter.routes['GET /conversations/c1/messages'] = (
      200,
      {
        'data': [],
        'meta': {'nextCursor': null, 'hasMore': false, 'otherTyping': true},
      },
    );
    await tokens.write('t');

    final typing = await api.loadNewMessages('c1', afterMessageId: 'm1');
    adapter.routes['GET /conversations/c1/messages'] = (
      200,
      {
        'data': [],
        'meta': {'nextCursor': null, 'hasMore': false},
      },
    );
    final quiet = await api.loadNewMessages('c1', afterMessageId: 'm1');

    expect(typing.otherTyping, isTrue);
    expect(typing.messages, isEmpty);
    expect(quiet.otherTyping, isFalse); // an old server says nothing
  });

  test('notes: list, share and remove', () async {
    final note = {
      'user': _summary('u2', 'Lan Hương'),
      'text': 'Đang học bài',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': DateTime.now().toUtc().toIso8601String(),
    };
    adapter.routes['GET /notes'] = (
      200,
      {
        'data': [note],
      },
    );
    adapter.routes['PUT /me/note'] = (200, {'data': note});
    adapter.routes['DELETE /me/note'] = (204, null);
    await tokens.write('t');

    final notes = await api.loadNotes();
    final saved = await api.setNote('Đang học bài');
    await api.deleteNote();

    expect(notes.single.text, 'Đang học bài');
    expect(notes.single.user.name, 'Lan Hương');
    expect(notes.single.time, 'Vừa xong');
    expect(saved.text, 'Đang học bài');
    expect(adapter.last('PUT /me/note').data, {'text': 'Đang học bài'});
    expect(
      adapter.requests.any((r) => r.method == 'DELETE' && r.path == '/me/note'),
      isTrue,
    );
  });

  test('music: search, and a song is sent by its id only', () async {
    final track = {
      'id': '111',
      'title': 'Em Của Ngày Hôm Qua',
      'artist': 'Sơn Tùng M-TP',
      'artworkUrl': 'https://is1-ssl.mzstatic.com/a.jpg',
      'previewUrl': 'https://audio-ssl.itunes.apple.com/preview/111.m4a',
      'appleMusicUrl': 'https://music.apple.com/vn/album/x/1?i=111',
      'spotifyUrl': null,
    };
    adapter.routes['GET /music/search'] = (
      200,
      {
        'data': [track],
      },
    );
    adapter.routes['PUT /me/note'] = (
      200,
      {
        'data': {
          'user': _summary('me', 'Minh Ánh'),
          'text': '',
          'track': track,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'expiresAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
    adapter.routes['POST /stories'] = (
      201,
      {
        'data': {
          'id': 's1',
          'author': _summary('me', 'Minh Ánh'),
          'text': 'Hè về',
          'imageUrl': null,
          'background': 'mint',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'expiresAt': DateTime.now().toUtc().toIso8601String(),
          'isViewed': false,
          'track': track,
        },
      },
    );
    await tokens.write('t');

    final found = await api.searchMusic('  em của ngày ');
    final note = await api.setNote('', track: found.single);
    final story = await api.createStory(
      Story(
        id: 'draft',
        user: (await _signedInUser(api, adapter, tokens)) as UserModel,
        text: 'Hè về',
        isViewed: false,
        gradientColors: const [Color(0xFF00B894), Color(0xFF26C6DA)],
        track: found.single,
      ),
    );

    expect(adapter.last('GET /music/search').queryParameters, {
      'q': 'em của ngày',
    });
    expect(
      found.single.previewUrl,
      'https://audio-ssl.itunes.apple.com/preview/111.m4a',
    );
    expect(found.single.spotifyUrl, isNull);
    expect(adapter.last('PUT /me/note').data, {'text': '', 'trackId': '111'});
    expect(note.track?.title, 'Em Của Ngày Hôm Qua');
    expect(note.text, '');
    expect((adapter.last('POST /stories').data as Map)['trackId'], '111');
    expect(story.track?.id, '111');

    // without a song no trackId is sent
    await api.setNote('chỉ chữ');
    expect(adapter.last('PUT /me/note').data, {'text': 'chỉ chữ'});
  });

  test('uploads wait longer than normal requests', () async {
    final file = File('${Directory.systemTemp.path}/timeout_test.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(file.deleteSync);
    adapter.routes['POST /me/cover'] = (200, {'data': _me()});
    adapter.routes['GET /me'] = (200, {'data': _me()});
    await tokens.write('t');

    await api.uploadCover(file.path);
    await api.restoreSession();

    final upload = adapter.last('POST /me/cover');
    final normal = adapter.last('GET /me');
    expect(upload.sendTimeout, const Duration(seconds: 120));
    expect(upload.receiveTimeout, const Duration(seconds: 120));
    expect(normal.receiveTimeout, isNot(const Duration(seconds: 120)));
  });

  test('a feed tab is asked for by name and cursor', () async {
    adapter.routes['GET /feed'] = (
      200,
      {
        'data': [_post('p1')],
        'meta': {'nextCursor': 'next', 'hasMore': true},
      },
    );
    await tokens.write('t');

    final first = await api.loadFeedFilter('following');
    await api.loadFeedFilter('following', cursor: 'abc');

    final requests = adapter.requests.where((r) => r.path == '/feed').toList();
    expect(requests.first.queryParameters, {
      'limit': 30,
      'filter': 'following',
    });
    expect(requests.last.queryParameters['cursor'], 'abc');
    expect(first.posts.single.id, 'p1');
    expect(first.nextCursor, 'next');
  });

  test('polling without an id loads the latest messages', () async {
    adapter.routes['GET /conversations/c1/messages'] = (
      200,
      _page([
        {
          'id': 'm2',
          'conversationId': 'c1',
          'senderId': 'u2',
          'text': 'hai',
          'createdAt': '2026-10-23T10:00:02Z',
        },
        {
          'id': 'm1',
          'conversationId': 'c1',
          'senderId': 'me',
          'text': 'một',
          'createdAt': '2026-10-23T10:00:01Z',
        },
      ]),
    );

    final messages = (await api.loadNewMessages('c1')).messages;

    expect(messages.map((x) => x.id), ['m1', 'm2']);
    expect(
      adapter
          .last('GET /conversations/c1/messages')
          .queryParameters
          .containsKey('after'),
      isFalse,
    );
  });

  test('later pages send the cursor and report the next one', () async {
    adapter.routes['GET /feed'] = (
      200,
      {
        'data': [_post('p9', saved: true)],
        'meta': {'nextCursor': 'next-1', 'hasMore': true},
      },
    );
    adapter.routes['GET /users'] = (
      200,
      {
        'data': [
          {
            ..._summary('u7', 'Khang'),
            'mutualFriendsCount': 0,
            'friendship': {'status': 'pending_outgoing', 'requestId': 'r1'},
          },
        ],
        'meta': {'nextCursor': null, 'hasMore': false},
      },
    );
    await tokens.write('t');

    final feed = await api.loadMoreFeed('cur-0');
    final users = await api.searchUsers(query: ' kha ', cursor: 'cur-1');

    expect(adapter.last('GET /feed').queryParameters['cursor'], 'cur-0');
    expect(feed.nextCursor, 'next-1');
    expect(feed.savedPostIds, {'p9'});
    expect(adapter.last('GET /users').queryParameters, {
      'limit': 30,
      'q': 'kha',
      'cursor': 'cur-1',
    });
    expect(users.pendingIds, {'u7'});
    expect(users.nextCursor, isNull);
  });

  test('starting a conversation posts the friend id', () async {
    adapter.routes['POST /conversations'] = (
      201,
      {
        'data': {
          'id': 'c9',
          'participant': _summary('u2', 'Lan Hương'),
          'lastMessage': null,
          'unreadCount': 0,
          'updatedAt': '2026-10-28T00:00:00Z',
        },
      },
    );
    final me = await _signedInUser(api, adapter, tokens);

    final friend = me.copyWith(name: 'Lan Hương');
    final conversation = await api.startConversation(friend);

    expect(adapter.last('POST /conversations').data, {'userId': 'me'});
    expect(conversation.id, 'c9');
    expect(conversation.user.name, 'Lan Hương');
    expect(conversation.messages, isEmpty);
  });

  test('privacy, reports and blocks use the contract paths', () async {
    adapter.routes['PATCH /posts/p1'] = (200, {'data': _post('p1')});
    adapter.routes['POST /reports'] = (
      201,
      {
        'data': {
          'id': 'r1',
          'targetType': 'post',
          'targetId': 'p1',
          'reason': 'spam',
          'createdAt': '2026-10-29T00:00:00Z',
        },
      },
    );
    adapter.routes['PUT /users/u2/block'] = (204, null);
    adapter.routes['DELETE /users/u2/block'] = (204, null);
    await tokens.write('t');

    await api.updatePostPrivacy('p1', 'only_me');
    await api.report(targetType: 'post', targetId: 'p1', reason: 'spam');
    await api.report(
      targetType: 'user',
      targetId: 'u2',
      reason: 'other',
      details: '  ',
    );
    await api.blockUser('u2');
    await api.unblockUser('u2');

    expect(adapter.last('PATCH /posts/p1').data, {'privacy': 'only_me'});
    expect(adapter.requests.where((r) => r.path == '/reports').first.data, {
      'targetType': 'post',
      'targetId': 'p1',
      'reason': 'spam',
    });
    // a blank detail is not sent
    expect(adapter.last('POST /reports').data, {
      'targetType': 'user',
      'targetId': 'u2',
      'reason': 'other',
    });
    expect(
      adapter.requests.any(
        (r) => r.method == 'PUT' && r.path == '/users/u2/block',
      ),
      isTrue,
    );
    expect(
      adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/users/u2/block',
      ),
      isTrue,
    );
  });

  test('blocked users follow the pages of /me/blocks', () async {
    var calls = 0;
    adapter.routes['GET /me/blocks'] = (
      200,
      {
        'data': [_summary('u2', 'Lan Hương')],
        'meta': {'nextCursor': null, 'hasMore': false},
      },
    );
    await tokens.write('t');

    final users = await api.loadBlockedUsers();
    calls = adapter.requests.where((r) => r.path == '/me/blocks').length;

    expect(users.map((u) => u.name), ['Lan Hương']);
    expect(calls, 1);
    expect(adapter.last('GET /me/blocks').queryParameters, {'limit': 50});
  });

  test('a profile knows if the caller blocked the person', () async {
    adapter.routes['GET /users/u2'] = (
      200,
      {
        'data': {
          ..._summary('u2', 'Lan Hương'),
          'bio': null,
          'friendsCount': 0,
          'mutualFriendsCount': 0,
          'friendship': {'status': 'none', 'requestId': null},
          'isBlocked': true,
        },
      },
    );
    adapter.routes['GET /users/u2/posts'] = (200, _page([]));
    await tokens.write('t');

    final profile = await api.loadProfile('u2');

    expect(profile.isBlocked, isTrue);
    expect(profile.posts, isEmpty);
  });

  test('the conversation list maps participants and unread counts', () async {
    adapter.routes['GET /conversations'] = (
      200,
      _page([
        {
          'id': 'c1',
          'participant': _summary('u2', 'Lan Hương'),
          'lastMessage': {
            'id': 'm1',
            'conversationId': 'c1',
            'senderId': 'u2',
            'text': 'Chào',
            'createdAt': '2026-10-23T10:00:00Z',
          },
          'unreadCount': 4,
          'updatedAt': '2026-10-23T10:00:00Z',
        },
      ]),
    );

    final list = await api.loadConversations();

    expect(list.single.unreadCount, 4);
    expect(list.single.lastMessage, 'Chào');
    expect(list.single.user.name, 'Lan Hương');
  });

  test('updateProfile sends name, bio and the About fields', () async {
    adapter.routes['PATCH /me'] = (
      200,
      {
        'data': {..._me(), 'name': 'Tên mới'},
      },
    );
    final me = await _signedInUser(api, adapter, tokens);

    final updated = await api.updateProfile(
      me.copyWith(
        name: 'Tên mới',
        bio: 'Bio mới',
        about: const UserAbout(
          location: ' Hà Nội ',
          website: 'https://example.com',
          birthday: '1998-05-17',
        ),
      ),
    );

    expect(adapter.last('PATCH /me').data, {
      'name': 'Tên mới',
      'bio': 'Bio mới',
      'location': 'Hà Nội',
      'hometown': null, // empty means "clear it"
      'workplace': null,
      'education': null,
      'website': 'https://example.com',
      'birthday': '1998-05-17',
    });
    expect(updated.name, 'Tên mới');
  });

  test(
    'the cover is uploaded as multipart and comes back on the user',
    () async {
      final file = File('${Directory.systemTemp.path}/cover_test.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(file.deleteSync);
      adapter.routes['POST /me/cover'] = (
        200,
        {
          'data': {
            ..._me(),
            'coverUrl': 'http://localhost:8000/storage/covers/c.jpg',
          },
        },
      );
      await tokens.write('t');

      final user = await api.uploadCover(file.path);

      final data = adapter.last('POST /me/cover').data as FormData;
      expect(data.files.single.key, 'cover');
      expect(user.coverUrl, 'http://10.0.2.2:8000/storage/covers/c.jpg');
    },
  );

  test('photos, friends and suggestions use the contract paths', () async {
    adapter.routes['GET /users/u2/photos'] = (
      200,
      {
        'data': [
          {
            'postId': 'p1',
            'imageUrl': 'http://localhost:8000/storage/posts/a.jpg',
            'createdAt': '2026-10-30T00:00:00Z',
          },
        ],
        'meta': {'nextCursor': 'next', 'hasMore': true},
      },
    );
    final friend = {
      ..._summary('u3', 'Bạn của Lan'),
      'mutualFriendsCount': 2,
      'friendship': {'status': 'pending_outgoing', 'requestId': 'r1'},
    };
    adapter.routes['GET /users/u2/friends'] = (200, _page([friend]));
    adapter.routes['GET /users/suggestions'] = (200, _page([friend]));
    await tokens.write('t');

    final photos = await api.loadUserPhotos('u2', cursor: 'abc');
    final friends = await api.loadUserFriends('u2');
    final suggestions = await api.loadSuggestions(cursor: 'zzz');

    expect(photos.photos.single.postId, 'p1');
    expect(
      photos.photos.single.imageUrl,
      'http://10.0.2.2:8000/storage/posts/a.jpg',
    );
    expect(photos.nextCursor, 'next');
    expect(
      adapter.last('GET /users/u2/photos').queryParameters['cursor'],
      'abc',
    );
    expect(friends.users.single.name, 'Bạn của Lan');
    expect(friends.users.single.mutualFriends, 2);
    expect(friends.pendingIds, {'u3'});
    expect(friends.nextCursor, isNull);
    expect(suggestions.users, hasLength(1));
    expect(
      adapter.last('GET /users/suggestions').queryParameters['cursor'],
      'zzz',
    );
  });
}

Future<dynamic> _signedInUser(
  HttpSocialApi api,
  _FakeAdapter adapter,
  MemoryTokenStore tokens,
) async {
  await tokens.write('t');
  adapter.routes['GET /me'] = (200, {'data': _me()});
  return (await api.restoreSession())!;
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}

/// Answers the same route with the next page each time it is asked.
class _SequenceAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> pages;
  final queries = <Map<String, dynamic>>[];

  _SequenceAdapter(this.pages);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(Map.of(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(pages[queries.length - 1]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
