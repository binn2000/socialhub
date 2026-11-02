import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/models/friend_request.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/notification.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/models/server_tab.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/screens/auth_screen.dart';
import 'package:flutter_learning/screens/create_post_screen.dart';
import 'package:flutter_learning/screens/chat_screen.dart';
import 'package:flutter_learning/screens/edit_profile_screen.dart';
import 'package:flutter_learning/screens/verify_email_screen.dart';
import 'package:flutter_learning/screens/explore_screen.dart';
import 'package:flutter_learning/screens/friends_screen.dart';
import 'package:flutter_learning/screens/home_screen.dart';
import 'package:flutter_learning/screens/messages_screen.dart';
import 'package:flutter_learning/screens/notifications_screen.dart';
import 'package:flutter_learning/screens/post_detail_screen.dart';
import 'package:flutter_learning/screens/profile_screen.dart';
import 'package:flutter_learning/screens/blocked_users_screen.dart';
import 'package:flutter_learning/screens/saved_posts_screen.dart';
import 'package:flutter_learning/screens/story_creator_screen.dart';
import 'package:flutter_learning/screens/user_profile_screen.dart';
import 'package:flutter_learning/services/http_social_api.dart';
import 'package:flutter_learning/services/mock_social_api.dart';
import 'package:flutter_learning/services/photo_picker.dart';
import 'package:flutter_learning/services/api_mappers.dart' show privacyValue;
import 'package:flutter_learning/services/push_service.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/services/token_store.dart';
import 'package:flutter_learning/theme/app_theme.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';
import 'package:flutter_learning/widgets/follow_list_sheet.dart';

/// Set with `--dart-define=API_BASE_URL=http://localhost:8000/api/v1` to use
/// the Laravel backend. Without it the app runs on the offline mock data.
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() {
  runApp(
    SocialHubApp(
      api: _apiBaseUrl.isEmpty
          ? null
          : HttpSocialApi(
              baseUrl: _apiBaseUrl,
              tokenStore: const SecureTokenStore(),
            ),
      push: _apiBaseUrl.isEmpty ? null : FirebasePushService(),
    ),
  );
}

/// How long a failed "next page" load waits before scrolling can retry it.
@visibleForTesting
Duration loadMoreRetryDelay = const Duration(seconds: 3);

class SocialHubApp extends StatefulWidget {
  /// The backend to use. Defaults to the offline mock.
  final SocialApi? api;

  /// Opens the photo library; tests replace it with a fake.
  final Future<String?> Function() pickPhoto;

  /// Push notifications. Defaults to none (the mock app and the tests).
  final PushService? push;

  const SocialHubApp({
    super.key,
    this.api,
    this.pickPhoto = pickPhotoPath,
    this.push,
  });

  @override
  State<SocialHubApp> createState() => _SocialHubAppState();
}

class _SocialHubAppState extends State<SocialHubApp> {
  PushService get _push => widget.push ?? const NoPushService();
  bool _isDarkMode = false;
  late final SocialApi _api = widget.api ?? MockSocialApi();
  UserModel? _user;
  bool _restoringSession = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // The mock has a user right away; a server has to confirm the saved
    // session first.
    _user = _api.seedUser;
    if (_user == null) {
      _restoringSession = true;
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _api.restoreSession();
      if (!mounted) return;
      setState(() {
        _user = user;
        _restoringSession = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _restoringSession = false;
        _notice = error.displayMessage;
      });
    }
  }

  Future<void> _signOut({String? notice}) async {
    // Stop pushes to this phone first; a dead session may refuse, which is fine.
    final pushToken = _push.token;
    if (pushToken != null) {
      try {
        await _api.unregisterDevice(pushToken);
      } on ApiException {
        // Nothing to do: the token is dropped from the phone below anyway.
      }
    }
    await _push.stop();
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _notice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return MaterialApp(
      title: 'SocialHub',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _restoringSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : user == null
          ? AuthScreen(
              api: _api,
              notice: _notice,
              onAuthenticated: (signedIn) => setState(() {
                _user = signedIn;
                _notice = null;
              }),
            )
          : MainScreen(
              // A new user gets a fresh MainScreen (and fresh state).
              key: ValueKey(user.id),
              api: _api,
              initialUser: user,
              pickPhoto: widget.pickPhoto,
              push: _push,
              onLogout: _signOut,
              isDarkMode: _isDarkMode,
              onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final SocialApi api;
  final UserModel initialUser;
  final Future<String?> Function() pickPhoto;
  final PushService push;
  final Future<void> Function({String? notice}) onLogout;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainScreen({
    super.key,
    required this.api,
    required this.initialUser,
    required this.pickPhoto,
    this.push = const NoPushService(),
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // With the mock these are filled from api.seed before the first frame; with
  // a server they start empty and api.load() fills them.
  int _selectedIndex = AppTab.home.index;
  List<Post> _posts = [];
  List<Story> _stories = [];
  late UserModel _currentUser = widget.initialUser;
  List<UserModel> _users = [];
  // Updated in place (not replaced) on purpose: an open ChatScreen keeps a
  // reference to this list and re-reads it after each message it sends.
  final List<Conversation> _conversations = [];
  List<SocialNotification> _notifications = [];
  // Session-only UI state for the Home post menu, keyed by post id.
  // Posts themselves stay in _posts; these sets only change how Home shows
  // them.
  final Set<String> _savedPostIds = {};
  final Set<String> _hiddenPostIds = {};
  // Ids of the posts Home shows. null = every post (the mock data).
  Set<String>? _feedPostIds;
  Set<String> _pendingFriendIds = {};
  List<FriendRequest> _friendRequests = [];
  // Stories already reported as seen, so each is sent to the server once.
  final Set<String> _reportedStoryIds = {};

  // Where each server list continues (null = nothing more). A reload bumps
  // _loadGeneration so a page that was still on its way is dropped.
  String? _feedCursor;
  String? _exploreCursor;
  String? _notificationsCursor;
  String? _usersCursor;
  final Set<String> _loadingMore = {};
  final Map<String, DateTime> _loadMoreFailedAt = {};
  int _loadGeneration = 0;

  bool _loading = false;
  String? _loadError;
  DateTime? _loadedAt;

  static const _refreshAfter = Duration(seconds: 15);
  static const _chatPollEvery = Duration(seconds: 4);
  static const _conversationsPollEvery = Duration(seconds: 15);

  // Polling (the server has no push): an open chat asks for newer messages,
  // an open Messages screen re-reads the conversation list.
  Timer? _chatTimer;
  Timer? _conversationsTimer;
  Timer? _presenceTimer;
  static const _presenceHeartbeatEvery = Duration(seconds: 45);
  String? _openChatId;
  bool _pollingChat = false;
  // Messages being sent. Polling waits for them, otherwise it could return
  // our own message before the send's answer replaces the local copy.
  int _sendsInFlight = 0;
  // Bumped when the conversations change behind an open screen's back.
  final ValueNotifier<int> _chatChanges = ValueNotifier(0);

  /// Whether the other person of the open chat is typing (from the poll).
  final ValueNotifier<bool> _partnerTyping = ValueNotifier(false);

  // Tabs that load their own list from the server when opened: the feed
  // tabs "Đang theo dõi" (`following`) and "Đa phương tiện" (`media`), and the
  // notification filters (`interactions`, `friends`). Keyed by the API name.
  final Map<String, _ServerTab> _feedTabs = {
    'following': _ServerTab(),
    'media': _ServerTab(),
  };
  final Map<String, _ServerTab> _notificationTabs = {
    'interactions': _ServerTab(),
    'friends': _ServerTab(),
  };

  // Unread notifications according to the server (null: count the loaded ones).
  int? _serverUnread;

  int get _unreadNotificationCount =>
      _serverUnread ??
      _notifications.where((notification) => !notification.isRead).length;

  @override
  void initState() {
    super.initState();
    final seed = widget.api.seed;
    if (seed != null) {
      _apply(seed);
    } else {
      _loading = true;
      _load();
      _startPush();
      _startPresenceHeartbeat();
    }
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    widget.api.sendPresence().ignore();
    _presenceTimer = Timer.periodic(_presenceHeartbeatEvery, (_) {
      if (mounted) {
        widget.api.sendPresence().ignore();
      }
    });
  }

  final List<StreamSubscription<Object?>> _pushSubscriptions = [];

  /// Registers this phone for pushes and reacts to them. Works without push
  /// (permission refused, no Firebase config): then `start()` returns null.
  Future<void> _startPush() async {
    final token = await widget.push.start();
    if (token == null || !mounted) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    Future<void> register(String value) async {
      try {
        await _guard(() => widget.api.registerDevice(value, platform));
      } on ApiException {
        // Push is a convenience; the next start tries again.
      }
    }

    await register(token);
    _pushSubscriptions
      ..add(widget.push.tokenRefreshed.listen(register))
      // The app is open: just refresh what the push is about.
      ..add(widget.push.foreground.listen((_) => _load(silent: true)))
      ..add(widget.push.opened.listen((m) => _openFromPush(m.data)));

    final launch = await widget.push.launchMessage();
    if (launch != null) _openFromPush(launch.data);
  }

  /// Opens what a tapped push is about.
  Future<void> _openFromPush(Map<String, String> data) async {
    // The lists may be older than the push, so load first.
    while (_loading && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);

    final type = data['type'];
    if (type == 'message') {
      await _load(silent: true);
      final conversation = _conversations
          .where((c) => c.id == data['conversationId'])
          .firstOrNull;
      if (conversation != null && mounted) {
        await _openConversation(conversation);
      }
    } else if (data['postId'] != null) {
      _openPost(data['postId']!);
    } else {
      _load(silent: true);
      setState(() => _selectedIndex = AppTab.friends.index);
    }
  }

  @override
  void dispose() {
    for (final subscription in _pushSubscriptions) {
      subscription.cancel();
    }
    _presenceTimer?.cancel();
    _chatTimer?.cancel();
    _conversationsTimer?.cancel();
    _chatChanges.dispose();
    _partnerTyping.dispose();
    super.dispose();
  }

  void _apply(AppSnapshot snapshot) {
    _serverUnread = snapshot.unreadNotificationCount;
    _posts = List<Post>.from(snapshot.posts);
    _feedPostIds = snapshot.feedPostIds == null
        ? null
        : Set<String>.from(snapshot.feedPostIds!);
    _savedPostIds
      ..clear()
      ..addAll(snapshot.savedPostIds);
    _hiddenPostIds
      ..clear()
      ..addAll(snapshot.hiddenPostIds);
    _stories = List<Story>.from(snapshot.stories);
    _users = List<UserModel>.from(snapshot.users);
    _pendingFriendIds = Set<String>.from(snapshot.pendingFriendIds);
    _conversations
      ..clear()
      ..addAll(snapshot.conversations);
    _notifications = List<SocialNotification>.from(snapshot.notifications);
    _friendRequests = List<FriendRequest>.from(snapshot.friendRequests);
    _feedCursor = snapshot.feedCursor;
    _exploreCursor = snapshot.exploreCursor;
    _notificationsCursor = snapshot.notificationsCursor;
    _usersCursor = snapshot.usersCursor;
    _loadGeneration++;
  }

  /// Runs one "next page" load at a time per list; errors are only shown, and
  /// the next scroll near the end tries again.
  Future<void> _loadMore(
    String list,
    String? cursor,
    Future<void> Function(String cursor, int generation) run,
  ) async {
    if (cursor == null) return;
    // After a failure wait a little, or every scroll event near the end would
    // ask again.
    final failedAt = _loadMoreFailedAt[list];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < loadMoreRetryDelay) {
      return;
    }
    if (!_loadingMore.add(list)) return;
    try {
      await _guard(() => run(cursor, _loadGeneration));
      _loadMoreFailedAt.remove(list);
    } on ApiException catch (error) {
      _loadMoreFailedAt[list] = DateTime.now();
      if (!mounted || error.isUnauthenticated) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    } finally {
      _loadingMore.remove(list);
    }
  }

  /// Adds posts the app does not have yet, newest first.
  void _addPosts(PostPage page) {
    final known = {for (final post in _posts) post.id};
    _posts = [
      ..._posts,
      for (final post in page.posts)
        if (!known.contains(post.id)) post,
    ]..sort((a, b) => b.id.compareTo(a.id));
    _savedPostIds.addAll(page.savedPostIds);
    _hiddenPostIds.addAll(page.hiddenPostIds);
  }

  Future<void> _loadMoreFeed() =>
      _loadMore('feed', _feedCursor, (cursor, generation) async {
        final page = await widget.api.loadMoreFeed(cursor);
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _addPosts(page);
          _feedPostIds = {...?_feedPostIds, for (final p in page.posts) p.id};
          _feedCursor = page.nextCursor;
        });
      });

  /// Loads a feed tab (`following`, `media`) from the server: the first page
  /// when the tab is opened or refreshed, the next one when scrolling to the
  /// end. The posts join [_posts] like any other, so likes and comments stay
  /// in step; the tab only keeps which ids belong to it.
  Future<void> _loadFeedTab(String filter, {bool more = false}) async {
    final tab = _feedTabs[filter]!;
    if (tab.loading) return;
    final cursor = more ? tab.cursor : null;
    if (more && cursor == null) return;
    setState(() {
      tab.loading = true;
      tab.error = null;
    });
    try {
      final page = await _guard(
        () => widget.api.loadFeedFilter(filter, cursor: cursor),
      );
      if (!mounted) return;
      final ids = {for (final post in page.posts) post.id};
      setState(() {
        _addPosts(page);
        // Every tab is part of the feed, so Home lists these posts too.
        _feedPostIds = {...?_feedPostIds, ...ids};
        tab
          ..ids = more ? {...?tab.ids, ...ids} : ids
          ..cursor = page.nextCursor
          ..loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        tab.loading = false;
        if (!error.isUnauthenticated) tab.error = error.displayMessage;
      });
    }
  }

  /// Same for a notification filter (`interactions`, `friends`).
  Future<void> _loadNotificationTab(
    String category, {
    bool more = false,
  }) async {
    final tab = _notificationTabs[category]!;
    if (tab.loading) return;
    final cursor = more ? tab.cursor : null;
    if (more && cursor == null) return;
    setState(() {
      tab.loading = true;
      tab.error = null;
    });
    try {
      final page = await _guard(
        () => widget.api.loadNotificationCategory(category, cursor: cursor),
      );
      if (!mounted) return;
      final ids = {for (final n in page.notifications) n.id};
      setState(() {
        final known = {for (final n in _notifications) n.id};
        _notifications = [
          ..._notifications,
          for (final n in page.notifications)
            if (!known.contains(n.id)) n,
        ];
        tab
          ..ids = more ? {...?tab.ids, ...ids} : ids
          ..cursor = page.nextCursor
          ..loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        tab.loading = false;
        if (!error.isUnauthenticated) tab.error = error.displayMessage;
      });
    }
  }

  /// Server search for the Messages screen. Conversations the app had not
  /// loaded yet are added to [_conversations] so they can be opened.
  Future<List<Conversation>> _searchConversations(String query) async {
    final found = await _guard(() => widget.api.searchConversations(query));
    if (!mounted) return const [];
    final result = <Conversation>[];
    for (final conversation in found) {
      var known = _findConversation(conversation.id);
      if (known == null) {
        _conversations.add(conversation);
        known = conversation;
      }
      result.add(known);
    }
    if (result.any((c) => c.messages.isEmpty)) _chatChanges.value++;
    return result;
  }

  /// Deletes one of my stories; it disappears at once and comes back with a
  /// message if the server refuses.
  void _handleDeleteStory(Story story) {
    final before = _stories;
    setState(() => _stories = _stories.where((s) => s.id != story.id).toList());
    _sync(
      () => widget.api.deleteStory(story.id),
      rollback: () => _stories = before,
    );
  }

  Map<String, ServerTabState> _tabStates(Map<String, _ServerTab> tabs) => {
    for (final entry in tabs.entries)
      entry.key: ServerTabState(
        ids: entry.value.ids,
        loading: entry.value.loading,
        error: entry.value.error,
      ),
  };

  Future<void> _loadMoreExplore() =>
      _loadMore('explore', _exploreCursor, (cursor, generation) async {
        final page = await widget.api.loadMoreExplore(cursor);
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _addPosts(page);
          _exploreCursor = page.nextCursor;
        });
      });

  Future<void> _loadMoreNotifications() => _loadMore(
    'notifications',
    _notificationsCursor,
    (cursor, generation) async {
      final page = await widget.api.loadMoreNotifications(cursor);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        final known = {for (final n in _notifications) n.id};
        _notifications = [
          ..._notifications,
          for (final n in page.notifications)
            if (!known.contains(n.id)) n,
        ];
        _notificationsCursor = page.nextCursor;
      });
    },
  );

  Future<void> _loadMoreUsers() =>
      _loadMore('users', _usersCursor, (cursor, generation) async {
        final page = await widget.api.searchUsers(cursor: cursor);
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          final known = {for (final user in _users) user.id};
          _users = [
            ..._users,
            for (final user in page.users)
              if (!known.contains(user.id)) user,
          ];
          _pendingFriendIds = {..._pendingFriendIds, ...page.pendingIds};
          _usersCursor = page.nextCursor;
        });
      });

  /// Pull-to-refresh: reload everything now, and say so if it fails.
  Future<void> _refreshAll() async {
    try {
      final snapshot = await _guard(() => widget.api.load(_currentUser));
      if (!mounted) return;
      setState(() {
        _apply(snapshot);
        _loadedAt = DateTime.now();
      });
      _chatChanges.value++;
    } on ApiException catch (error) {
      if (!mounted || error.isUnauthenticated) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final snapshot = await widget.api.load(_currentUser);
      if (!mounted) return;
      setState(() {
        _apply(snapshot);
        _loading = false;
        _loadError = null;
        _loadedAt = DateTime.now();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthenticated) {
        widget.onLogout(notice: 'Phiên đăng nhập đã hết hạn');
        return;
      }
      // A failed background refresh keeps what is on screen.
      if (!silent) {
        setState(() {
          _loading = false;
          _loadError = error.displayMessage;
        });
      }
    }
  }

  /// Runs a server call for a change the screen already shows. If it fails,
  /// [rollback] undoes the change and a message explains why.
  Future<void> _sync(
    Future<void> Function() call, {
    VoidCallback? rollback,
  }) async {
    try {
      await call();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthenticated) {
        widget.onLogout(notice: 'Phiên đăng nhập đã hết hạn');
        return;
      }
      if (rollback != null) setState(rollback);
      // Replace a "done" message the screen already showed for this change.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  void _handleAddPost(
    String text,
    String feeling,
    String privacy,
    String? imageUrl,
    String? imageId,
  ) {
    final draft = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: _currentUser,
      content: text,
      imageUrl: imageUrl,
      imageId: imageId,
      feeling: feeling,
      privacy: privacy,
      createdAt: 'Vừa xong',
      likes: 0,
      comments: 0,
      shares: 0,
      isLiked: false,
    );
    setState(() {
      _posts.insert(0, draft);
      _feedPostIds?.add(draft.id);
      _selectedIndex = AppTab.home.index;
    });

    _sync(
      () async {
        final saved = await widget.api.createPost(draft);
        if (!mounted || saved.id == draft.id) return;
        setState(() {
          _posts = _posts
              .map((post) => post.id == draft.id ? saved : post)
              .toList();
          _feedPostIds
            ?..remove(draft.id)
            ..add(saved.id);
        });
      },
      rollback: () {
        _posts = _posts.where((post) => post.id != draft.id).toList();
        _feedPostIds?.remove(draft.id);
      },
    );
  }

  void _setLiked(String postId, bool liked) {
    _posts = _posts.map((post) {
      if (post.id != postId || post.isLiked == liked) return post;
      return post.copyWith(
        likes: liked ? post.likes + 1 : post.likes - 1,
        isLiked: liked,
      );
    }).toList();
  }

  void _handleToggleLike(String postId) {
    final post = _posts.firstWhere((post) => post.id == postId);
    final liked = !post.isLiked;
    setState(() => _setLiked(postId, liked));
    _sync(
      () => widget.api.setLiked(postId, liked),
      rollback: () => _setLiked(postId, !liked),
    );
  }

  void _setSaved(String postId, bool saved) {
    setState(() {
      saved ? _savedPostIds.add(postId) : _savedPostIds.remove(postId);
    });
    _sync(
      () => widget.api.setSaved(postId, saved),
      rollback: () {
        saved ? _savedPostIds.remove(postId) : _savedPostIds.add(postId);
      },
    );
  }

  void _handleToggleSave(String postId) =>
      _setSaved(postId, !_savedPostIds.contains(postId));

  void _openSavedPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedPostsScreen(
          // A server knows every saved post; the mock app only knows the ones
          // saved in this session, newest first.
          load: widget.api.isRemote
              ? () => _guard(widget.api.loadSavedPosts)
              : () async => [
                  for (final id in _savedPostIds.toList().reversed)
                    ..._posts.where((post) => post.id == id),
                ],
          onUnsave: (postId) => _setSaved(postId, false),
          onOpenProfile: widget.api.isRemote ? _openProfile : null,
        ),
      ),
    );
  }

  void _handleHidePost(String postId) {
    setState(() => _hiddenPostIds.add(postId));
    _sync(
      () => widget.api.setHidden(postId, true),
      rollback: () => _hiddenPostIds.remove(postId),
    );
  }

  void _handleUnhidePost(String postId) {
    setState(() => _hiddenPostIds.remove(postId));
    _sync(
      () => widget.api.setHidden(postId, false),
      rollback: () => _hiddenPostIds.add(postId),
    );
  }

  void _handleAddStory(Story story) {
    setState(() {
      _stories = [story, ..._stories];
      _selectedIndex = AppTab.home.index;
    });

    _sync(
      () async {
        final saved = await widget.api.createStory(story);
        if (!mounted || saved.id == story.id) return;
        setState(() {
          _stories = _stories.map((s) => s.id == story.id ? saved : s).toList();
        });
      },
      rollback: () {
        _stories = _stories.where((s) => s.id != story.id).toList();
      },
    );
  }

  /// Runs a server call the caller handles errors for. A rejected sign-in
  /// still sends the user back to the login screen first.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      if (error.isUnauthenticated && mounted) {
        widget.onLogout(notice: 'Phiên đăng nhập đã hết hạn');
      }
      rethrow;
    }
  }

  void _replacePost(String postId, Post Function(Post) change) {
    _posts = _posts
        .map((post) => post.id == postId ? change(post) : post)
        .toList();
  }

  void _replaceUser(String userId, UserModel Function(UserModel) change) {
    _users = _users
        .map((user) => user.id == userId ? change(user) : user)
        .toList();
  }

  Future<void> _handleShare(String postId, String target) async {
    try {
      final shares = await _guard(() => widget.api.sharePost(postId, target));
      if (!mounted) return;
      setState(
        () => _replacePost(postId, (post) => post.copyWith(shares: shares)),
      );
    } on ApiException catch (error) {
      if (!mounted || error.isUnauthenticated) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  late final PostInteractions _interactions = PostInteractions(
    currentUserId: widget.initialUser.id,
    loadComments: (postId) => _guard(() => widget.api.loadComments(postId)),
    addComment: (postId, text) =>
        _guard(() => widget.api.addComment(postId, text)),
    deleteComment: (postId, commentId) =>
        _guard(() => widget.api.deleteComment(commentId)),
    sharePost: _handleShare,
    onOpenProfile: _openProfile,
    report: _report,
    blockUser: _blockUser,
    changePrivacy: _changePrivacy,
  );

  void _openProfile(UserModel user) {
    if (user.id == _currentUser.id) {
      // Leave any open comment sheet or profile, then show our own tab.
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _selectedIndex = AppTab.profile.index);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          user: user,
          onOpenProfile: _openProfile,
          onLoadPhotos: (userId, cursor) =>
              _guard(() => widget.api.loadUserPhotos(userId, cursor: cursor)),
          onLoadFriends: (userId, cursor) =>
              _guard(() => widget.api.loadUserFriends(userId, cursor: cursor)),
          load: () => _guard(() => widget.api.loadProfile(user.id)),
          onSendRequest: (userId) => _guard(() async {
            await widget.api.sendFriendRequest(userId);
            if (mounted) {
              setState(
                () => _pendingFriendIds = {..._pendingFriendIds, userId},
              );
            }
          }),
          onAccept: (requestId) => _guard(() async {
            final friend = await widget.api.acceptFriendRequest(requestId);
            if (!mounted) return;
            setState(() {
              _friendRequests = _friendRequests
                  .where((request) => request.id != requestId)
                  .toList();
              // Accepting also makes the two follow each other (server rule).
              _replaceUser(
                friend.id,
                (user) => user.copyWith(isFriend: true, isFollowing: true),
              );
            });
            _load(silent: true); // the follower counts changed too
          }),
          onDeleteRequest: (requestId) => _guard(() async {
            await widget.api.deleteFriendRequest(requestId);
            if (!mounted) return;
            setState(() {
              _friendRequests = _friendRequests
                  .where((request) => request.id != requestId)
                  .toList();
              _pendingFriendIds = {..._pendingFriendIds}..remove(user.id);
            });
          }),
          onMessage: _startConversation,
          onReport: (reason, details) =>
              _report('user', user.id, reason, details),
          onBlock: _blockUser,
          onUnblock: _unblockUser,
          onFollow: widget.api.isRemote
              ? (userId) => _guard(() async {
                  await widget.api.followUser(userId);
                  if (mounted) {
                    setState(() {
                      _replaceUser(
                        userId,
                        (u) => u.copyWith(
                          isFollowing: true,
                          followersCount: u.followersCount + 1,
                        ),
                      );
                    });
                  }
                })
              : null,
          onUnfollow: widget.api.isRemote
              ? (userId) => _guard(() async {
                  await widget.api.unfollowUser(userId);
                  if (mounted) {
                    setState(() {
                      _replaceUser(
                        userId,
                        (u) => u.copyWith(
                          isFollowing: false,
                          followersCount: (u.followersCount - 1).clamp(
                            0,
                            999999,
                          ),
                        ),
                      );
                    });
                  }
                })
              : null,
          onLoadFollowers: widget.api.isRemote
              ? (userId, cursor) => _guard(
                  () => widget.api.loadFollowers(userId, cursor: cursor),
                )
              : null,
          onLoadFollowing: widget.api.isRemote
              ? (userId, cursor) => _guard(
                  () => widget.api.loadFollowing(userId, cursor: cursor),
                )
              : null,
          onUnfriend: (userId) => _guard(() async {
            await widget.api.unfriend(userId);
            if (mounted) {
              setState(
                () => _replaceUser(userId, (u) => u.copyWith(isFriend: false)),
              );
            }
          }),
        ),
      ),
    );
  }

  void _handleAcceptRequest(FriendRequest request) {
    final before = _friendRequests;
    setState(() {
      _friendRequests = before.where((r) => r.id != request.id).toList();
      // Accepting also makes the two follow each other (server rule).
      _replaceUser(
        request.sender.id,
        (user) => user.copyWith(isFriend: true, isFollowing: true),
      );
    });
    _sync(
      () async {
        await widget.api.acceptFriendRequest(request.id);
        if (mounted && widget.api.isRemote) {
          _load(silent: true); // the follower counts changed too
        }
      },
      rollback: () {
        _friendRequests = before;
        _replaceUser(
          request.sender.id,
          (user) => user.copyWith(isFriend: false, isFollowing: false),
        );
      },
    );
  }

  void _handleDeclineRequest(FriendRequest request) {
    final before = _friendRequests;
    setState(
      () => _friendRequests = before.where((r) => r.id != request.id).toList(),
    );
    _sync(
      () => widget.api.deleteFriendRequest(request.id),
      rollback: () => _friendRequests = before,
    );
  }

  void _handleDeletePost(String postId) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return;
    final removed = _posts[index];
    final wasInFeed = _feedPostIds?.contains(postId) ?? false;
    final wasSaved = _savedPostIds.contains(postId);
    final wasHidden = _hiddenPostIds.contains(postId);

    final removedNotifications = _notifications;
    setState(() {
      _posts = [..._posts]..removeAt(index);
      _feedPostIds?.remove(postId);
      _savedPostIds.remove(postId);
      _hiddenPostIds.remove(postId);
      // The server deletes them with the post.
      _notifications = _notifications.where((n) => n.postId != postId).toList();
    });

    _sync(
      () => widget.api.deletePost(postId),
      rollback: () {
        _notifications = removedNotifications;
        _posts = [..._posts]..insert(index.clamp(0, _posts.length), removed);
        if (wasInFeed) _feedPostIds?.add(postId);
        if (wasSaved) _savedPostIds.add(postId);
        if (wasHidden) _hiddenPostIds.add(postId);
      },
    );
  }

  /// Changes who can see one of our own posts (server only).
  Future<bool> _changePrivacy(String postId, String privacyLabel) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    final value = privacyValue(privacyLabel);
    if (index == -1 || value == null) return false;
    final before = _posts[index];
    if (before.privacy == privacyLabel) return true;
    var done = true;

    setState(
      () => _replacePost(postId, (p) => p.copyWith(privacy: privacyLabel)),
    );
    await _sync(
      () => widget.api.updatePostPrivacy(postId, value),
      rollback: () {
        done = false;
        _replacePost(postId, (p) => p.copyWith(privacy: before.privacy));
      },
    );
    return done;
  }

  Future<void> _report(
    String targetType,
    String targetId,
    String reason,
    String? details,
  ) => _guard(
    () => widget.api.report(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details,
    ),
  );

  /// Blocks [user] and removes them from everything on screen. Errors go to
  /// the caller, which shows them.
  Future<void> _blockUser(UserModel user) async {
    await _guard(() => widget.api.blockUser(user.id));
    if (!mounted) return;
    final id = user.id;
    setState(() {
      _posts = _posts.where((p) => p.author.id != id).toList();
      _stories = _stories.where((s) => s.user.id != id).toList();
      _users = _users.where((u) => u.id != id).toList();
      _conversations.removeWhere((c) => c.user.id == id);
      _notifications = _notifications.where((n) => n.actor.id != id).toList();
      _friendRequests = _friendRequests
          .where((r) => r.sender.id != id)
          .toList();
      _pendingFriendIds = {..._pendingFriendIds}..remove(id);
    });
    _chatChanges.value++;
    // Counts, saved posts and the like are easiest to get right from the server.
    _load(silent: true);
  }

  Future<void> _unblockUser(String userId) async {
    await _guard(() => widget.api.unblockUser(userId));
    if (!mounted) return;
    _load(silent: true);
  }

  void _openBlockedUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockedUsersScreen(
          load: () => _guard(() => widget.api.loadBlockedUsers()),
          onUnblock: _unblockUser,
        ),
      ),
    );
  }

  void _handleStoryViewed(Story story) {
    if (!widget.api.isRemote ||
        story.user.id == _currentUser.id ||
        story.isViewed ||
        !_reportedStoryIds.add(story.id)) {
      return;
    }

    setState(() {
      _stories = _stories
          .map((s) => s.id == story.id ? s.copyWith(isViewed: true) : s)
          .toList();
    });
    // Seen marks are not worth an error message; the server just won't know.
    _guard(() => widget.api.markStoryViewed(story.id)).catchError((_) {});
  }

  /// Opens the post a notification is about.
  void _openPost(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          load: () => _guard(() => widget.api.loadPost(postId)),
          interactions: _interactions,
          onSetLiked: (id, liked) => _guard(() async {
            await widget.api.setLiked(id, liked);
            if (mounted) setState(() => _setLiked(id, liked));
          }),
          onDelete: (id) => _guard(() async {
            await widget.api.deletePost(id);
            if (!mounted) return;
            setState(() {
              _posts = _posts.where((post) => post.id != id).toList();
              _feedPostIds?.remove(id);
              _notifications = _notifications
                  .where((n) => n.postId != id)
                  .toList();
            });
          }),
        ),
      ),
    );
  }

  void _handleSendFriendRequest(String userId) {
    _sync(() async {
      await widget.api.sendFriendRequest(userId);
      _pendingFriendIds = {..._pendingFriendIds, userId};
    });
  }

  void _openCreateScreen() {
    setState(() {
      _selectedIndex = AppTab.createPost.index;
    });
  }

  void _openMessages() {
    if (widget.api.isRemote) {
      _conversationsTimer?.cancel();
      _conversationsTimer = Timer.periodic(
        _conversationsPollEvery,
        (_) => _refreshConversations(),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          conversations: _conversations,
          onOpenConversation: _openConversation,
          refresh: widget.api.isRemote ? _chatChanges : null,
          friends: widget.api.isRemote ? _friendsToMessage : null,
          onStartConversation: widget.api.isRemote ? _startConversation : null,
          onSearchConversations: widget.api.isRemote
              ? _searchConversations
              : null,
          currentUser: _currentUser,
          onSendMessage: _handleSendMessage,
          onPickAttachment: widget.api.isRemote ? _pickPhoto : null,
          onSelectDesktopConversation: (conversation) {
            final hadUnread = conversation.unreadCount > 0;
            _markConversationRead(conversation.id);
            if (hadUnread) {
              _sync(() => widget.api.markConversationRead(conversation.id));
            }
          },
        ),
      ),
    ).then((_) {
      _conversationsTimer?.cancel();
      _conversationsTimer = null;
    });
  }

  /// Re-reads the conversation list, keeping the messages already loaded.
  Future<void> _refreshConversations() async {
    try {
      final fresh = await _guard(() => widget.api.loadConversations());
      if (!mounted) return;
      setState(() {
        final merged = [
          for (final conversation in fresh)
            Conversation(
              id: conversation.id,
              user: conversation.user,
              lastMessage: conversation.lastMessage,
              time: conversation.time,
              // What is open is being read right now.
              unreadCount: conversation.id == _openChatId
                  ? 0
                  : conversation.unreadCount,
              messages:
                  _findConversation(conversation.id)?.messages ?? const [],
            ),
        ];
        _conversations
          ..clear()
          ..addAll(merged);
        _chatChanges.value++;
      });
    } on ApiException {
      // The next poll tries again.
    }
  }

  /// Asks for messages newer than the last one we have, in the open chat.
  Future<void> _pollOpenChat() async {
    final id = _openChatId;
    if (id == null || _sendsInFlight > 0 || _pollingChat) return;
    final conversation = _findConversation(id);
    if (conversation == null) return;

    // Messages we just sent have a local id until the server answers.
    String? after;
    for (final message in conversation.messages.reversed) {
      if (!message.id.startsWith('message_')) {
        after = message.id;
        break;
      }
    }

    _pollingChat = true;
    try {
      final poll = await _guard(
        () => widget.api.loadNewMessages(id, afterMessageId: after),
      );
      if (!mounted || _openChatId != id || _sendsInFlight > 0) return;
      _partnerTyping.value = poll.otherTyping;
      final incoming = poll.messages;

      final known = _findConversation(id)!.messages.map((m) => m.id).toSet();
      final fresh = incoming.where((m) => !known.contains(m.id)).toList();
      if (fresh.isEmpty) return;

      _updateConversation(id, (current) {
        return _copyConversation(
          current,
          messages: [...current.messages, ...fresh],
          lastMessage: fresh.last.text,
          time: fresh.last.time,
          unreadCount: 0,
        );
      });
      if (fresh.any((m) => m.senderId != _currentUser.id)) {
        _guard(() => widget.api.markConversationRead(id)).catchError((_) {});
      }
    } on ApiException {
      // The next poll tries again.
    } finally {
      _pollingChat = false;
    }
  }

  void _openNotifications() {
    final hadUnread = _unreadNotificationCount > 0;
    setState(() {
      _serverUnread = _serverUnread == null ? null : 0;
      _notifications = _notifications
          .map((notification) => _copyNotification(notification, isRead: true))
          .toList();
      _selectedIndex = AppTab.notifications.index;
    });
    if (hadUnread) _sync(widget.api.markAllNotificationsRead);
  }

  void _handleNotificationTap(SocialNotification notification) {
    setState(() {
      _notifications = _notifications
          .map(
            (current) => current.id == notification.id
                ? _copyNotification(current, isRead: true)
                : current,
          )
          .toList();
    });

    if (widget.api.isRemote) {
      // Friend notifications open the person (where a request can be
      // answered); the rest open the post they are about.
      if (notification.type == 'friend') {
        _openProfile(notification.actor);
      } else if (notification.postId != null) {
        _openPost(notification.postId!);
      }
      return;
    }

    if (notification.type == 'friend') {
      setState(() => _selectedIndex = AppTab.friends.index);
    } else if (notification.type == 'message') {
      _openMessages();
    } else {
      setState(() => _selectedIndex = AppTab.home.index);
    }
  }

  SocialNotification _copyNotification(
    SocialNotification notification, {
    required bool isRead,
  }) {
    return SocialNotification(
      id: notification.id,
      actor: notification.actor,
      description: notification.description,
      time: notification.time,
      type: notification.type,
      icon: notification.icon,
      iconColor: notification.iconColor,
      isRead: isRead,
      relatedContent: notification.relatedContent,
      postId: notification.postId,
    );
  }

  List<UserModel> _friendsToMessage() => [
    for (final user in _users)
      if (user.isFriend && user.id != _currentUser.id) user,
  ];

  /// Opens the chat with [friend], creating the conversation the first time.
  Future<void> _startConversation(UserModel friend) async {
    final existing = _conversations
        .where((c) => c.user.id == friend.id)
        .firstOrNull;
    if (existing != null) {
      await _openConversation(existing);
      return;
    }

    final Conversation started;
    try {
      started = await _guard(() => widget.api.startConversation(friend));
    } on ApiException catch (error) {
      if (!mounted || error.isUnauthenticated) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
      return;
    }
    if (!mounted) return;
    // The server may know a conversation this list has not loaded yet.
    if (!_conversations.any((c) => c.id == started.id)) {
      _conversations.insert(0, started);
    }
    setState(() {});
    _chatChanges.value++;
    await _openConversation(started);
  }

  Future<void> _openConversation(Conversation conversation) async {
    final hadUnread = conversation.unreadCount > 0;
    _markConversationRead(conversation.id);
    if (hadUnread) {
      _sync(() => widget.api.markConversationRead(conversation.id));
    }

    // The server list has no message bodies; fetch them before the chat opens.
    // (The mock answers null, so nothing waits there.)
    if (widget.api.isRemote) {
      await _sync(() async {
        final messages = await widget.api.loadMessages(conversation.id);
        if (messages == null) return;
        _updateConversation(
          conversation.id,
          (current) => _copyConversation(current, messages: messages),
        );
      });
      if (!mounted) return;
    }

    if (widget.api.isRemote) {
      _openChatId = conversation.id;
      _chatTimer?.cancel();
      _chatTimer = Timer.periodic(_chatPollEvery, (_) => _pollOpenChat());
    }

    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: _partnerTyping,
            builder: (context, partnerTyping, _) => ChatScreen(
              isPartnerTyping: partnerTyping,
              conversations: _conversations,
              conversationId: conversation.id,
              currentUser: _currentUser,
              onSendMessage: (text, {attachmentPaths}) => _handleSendMessage(
                conversation.id,
                text,
                attachmentPaths: attachmentPaths,
              ),
              onPickAttachment: widget.api.isRemote ? _pickPhoto : null,
              onTyping: widget.api.isRemote
                  ? (typing) {
                      if (typing) {
                        widget.api.sendTyping(conversation.id).ignore();
                      } else {
                        widget.api.stopTyping(conversation.id).ignore();
                      }
                    }
                  : null,
              refresh: widget.api.isRemote ? _chatChanges : null,
            ),
          ),
        ),
      );
    } finally {
      _chatTimer?.cancel();
      _chatTimer = null;
      _openChatId = null;
      _partnerTyping.value = false;
    }
  }

  void _handleSendMessage(
    String conversationId,
    String text, {
    List<String>? attachmentPaths,
  }) {
    final attachments = [
      if (attachmentPaths != null)
        for (final p in attachmentPaths)
          ChatAttachment(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${p.hashCode}',
            type:
                p.endsWith('.jpg') || p.endsWith('.png') || p.endsWith('.jpeg')
                ? 'image'
                : 'file',
            url: p,
            name: p.split('/').last,
            mimeType: p.endsWith('.png')
                ? 'image/png'
                : (p.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg'),
            sizeBytes: 1024,
          ),
    ];

    final message = ChatMessage(
      id: 'message_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      text: text,
      time: 'Vừa xong',
      attachments: attachments,
    );

    _updateConversation(conversationId, (conversation) {
      return _copyConversation(
        conversation,
        messages: [...conversation.messages, message],
        lastMessage: message.text.isNotEmpty
            ? message.text
            : (attachments.isNotEmpty ? '[Đính kèm]' : ''),
        time: message.time,
        unreadCount: 0,
      );
    });

    _sendsInFlight++;
    _sync(
      () async {
        final saved = await widget.api.sendMessage(
          conversationId,
          message,
          attachmentPaths: attachmentPaths,
        );
        if (!mounted || saved.id == message.id) return;
        _updateConversation(conversationId, (conversation) {
          return _copyConversation(
            conversation,
            messages: [
              for (final m in conversation.messages)
                m.id == message.id ? saved : m,
            ],
          );
        });
      },
      rollback: () {
        // _conversations is updated in place, so edit the list directly.
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conversation = _conversations[index];
        final remaining = conversation.messages
            .where((m) => m.id != message.id)
            .toList();
        _conversations[index] = _copyConversation(
          conversation,
          messages: remaining,
          lastMessage: remaining.isEmpty ? '' : remaining.last.text,
          time: remaining.isEmpty ? '' : remaining.last.time,
        );
      },
    ).whenComplete(() => _sendsInFlight--);
  }

  void _markConversationRead(String conversationId) {
    final conversation = _findConversation(conversationId);
    if (conversation == null || conversation.unreadCount == 0) return;

    _updateConversation(
      conversationId,
      (current) => _copyConversation(current, unreadCount: 0),
    );
  }

  Conversation? _findConversation(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  void _updateConversation(
    String conversationId,
    Conversation Function(Conversation) update,
  ) {
    final conversationIndex = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (conversationIndex == -1) return;

    _conversations[conversationIndex] = update(
      _conversations[conversationIndex],
    );
    setState(() {});
    _chatChanges.value++;
  }

  Conversation _copyConversation(
    Conversation conversation, {
    List<ChatMessage>? messages,
    String? lastMessage,
    String? time,
    int? unreadCount,
  }) {
    return Conversation(
      id: conversation.id,
      user: conversation.user,
      lastMessage: lastMessage ?? conversation.lastMessage,
      time: time ?? conversation.time,
      unreadCount: unreadCount ?? conversation.unreadCount,
      messages: messages ?? conversation.messages,
    );
  }

  /// Opens the photo library. A refused permission or a missing library shows
  /// a message instead of crashing.
  Future<String?> _pickPhoto() async {
    try {
      return await widget.pickPhoto();
    } on PlatformException {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể mở thư viện ảnh. Hãy kiểm tra quyền truy cập.',
          ),
        ),
      );
      return null;
    }
  }

  /// Picks a photo, uploads it and returns the new avatar URL, for the Edit
  /// Profile screen.
  Future<String?> _changeAvatar() async {
    final path = await _pickPhoto();
    if (path == null) return null;

    String? url;
    await _sync(() async {
      url = (await widget.api.uploadAvatar(path)).avatarUrl;
    });
    return url;
  }

  /// Picks a photo and uploads it as the profile cover (Profile tab).
  Future<void> _changeCover() async {
    final path = await _pickPhoto();
    if (path == null) return;
    await _sync(() async {
      final saved = await widget.api.uploadCover(path);
      if (!mounted) return;
      setState(
        () => _applyUser(_currentUser.copyWith(coverUrl: saved.coverUrl)),
      );
    });
  }

  /// Deletes the account, then leaves every pushed screen and shows sign-in.
  /// A refused password throws to the dialog that asked.
  Future<void> _deleteAccount(String password) async {
    try {
      await widget.api.deleteAccount(password);
    } on ApiException catch (error) {
      if (error.isUnauthenticated) {
        widget.onLogout(notice: 'Phiên đăng nhập đã hết hạn');
        return;
      }
      rethrow;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLogout(notice: 'Tài khoản đã được xóa');
  }

  Future<void> _openVerifyEmail() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VerifyEmailScreen(api: widget.api)),
    );
    if (verified != true || !mounted) return;
    setState(() => _applyUser(_currentUser.copyWith(emailVerified: true)));
  }

  Future<void> _openEditProfile() async {
    final previousUser = _currentUser;
    final updatedUser = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _currentUser,
          editAbout: widget.api.isRemote,
          onChangeAvatar: widget.api.isRemote ? _changeAvatar : null,
          onDeleteAccount: widget.api.isRemote ? _deleteAccount : null,
          onOpenBlocked: widget.api.isRemote ? _openBlockedUsers : null,
        ),
      ),
    );
    if (updatedUser == null) return;

    if (widget.api.isRemote &&
        updatedUser.showOnlineStatus != previousUser.showOnlineStatus) {
      widget.api.setShowOnlineStatus(updatedUser.showOnlineStatus).ignore();
    }

    setState(() => _applyUser(updatedUser));
    _sync(() async {
      final saved = await widget.api.updateProfile(updatedUser);
      if (!mounted || identical(saved, updatedUser)) return;
      setState(() => _applyUser(saved));
    }, rollback: () => _applyUser(previousUser));
  }

  /// Shows [user] as the current user everywhere their name or photo appears.
  void _applyUser(UserModel user) {
    _currentUser = user;
    _posts = _posts
        .map(
          (post) =>
              post.author.id == user.id ? post.copyWith(author: user) : post,
        )
        .toList();
    _stories = _stories
        .map(
          (story) => story.user.id == user.id
              ? Story(
                  id: story.id,
                  user: user,
                  imageUrl: story.imageUrl,
                  text: story.text,
                  isViewed: story.isViewed,
                  gradientColors: story.gradientColors,
                )
              : story,
        )
        .toList();
  }

  void _handleTabTap(int index) {
    // Opening Notifications also marks every notification as read.
    if (index == AppTab.notifications.index) {
      _openNotifications();
    } else {
      setState(() => _selectedIndex = index);
    }

    // With a server, other people's activity arrives only when we ask.
    final loadedAt = _loadedAt;
    if (widget.api.isRemote &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) > _refreshAfter) {
      _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loadError != null) {
      return Scaffold(
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _load();
                      },
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: widget.onLogout,
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
        ),
      );
    }

    // Home shows the feed minus the posts hidden from it; Explore only the
    // public ones (with the mock data every post is on both).
    final feedPostIds = _feedPostIds;
    final homePosts = _posts
        .where(
          (post) =>
              !_hiddenPostIds.contains(post.id) &&
              (feedPostIds?.contains(post.id) ?? true),
        )
        .toList();
    final explorePosts = feedPostIds == null
        ? _posts
        : _posts.where((post) => post.privacy == 'Công khai').toList();

    // One screen per AppTab, in the same order.
    final screens = <Widget>[
      HomeScreen(
        currentUser: _currentUser,
        posts: homePosts,
        stories: _stories,
        savedPostIds: _savedPostIds,
        onToggleLike: _handleToggleLike,
        onToggleSave: _handleToggleSave,
        onHidePost: _handleHidePost,
        onUndoHidePost: _handleUnhidePost,
        onOpenCreate: _openCreateScreen,
        onOpenStoryCreator: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryCreatorScreen(
                currentUser: _currentUser,
                onStoryCreated: _handleAddStory,
                onPickPhoto: widget.api.isRemote ? _pickPhoto : null,
              ),
            ),
          );
        },
        onOpenMessages: _openMessages,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        interactions: widget.api.isRemote ? _interactions : null,
        onCommentCountChanged: (postId, count) => setState(
          () => _replacePost(postId, (post) => post.copyWith(comments: count)),
        ),
        onDeletePost: widget.api.isRemote ? _handleDeletePost : null,
        onStoryViewed: _handleStoryViewed,
        onRefresh: widget.api.isRemote ? _refreshAll : null,
        onLoadMore: widget.api.isRemote ? _loadMoreFeed : null,
        serverTabs: widget.api.isRemote ? _tabStates(_feedTabs) : null,
        onLoadTab: widget.api.isRemote
            ? (filter, {bool more = false}) => _loadFeedTab(filter, more: more)
            : null,
        onDeleteStory: widget.api.isRemote ? _handleDeleteStory : null,
      ),
      ExploreScreen(
        posts: explorePosts,
        onRefresh: widget.api.isRemote ? _refreshAll : null,
        onLoadMore: widget.api.isRemote ? _loadMoreExplore : null,
        interactions: widget.api.isRemote ? _interactions : null,
        onCommentCountChanged: (postId, count) => setState(
          () => _replacePost(postId, (post) => post.copyWith(comments: count)),
        ),
        onOpenMessages: _openMessages,
        savedPostIds: _savedPostIds,
        onToggleSave: widget.api.isRemote ? _handleToggleSave : null,
      ),
      FriendsScreen(
        users: _users,
        currentUser: _currentUser,
        pendingUserIds: _pendingFriendIds,
        onSendFriendRequest: widget.api.isRemote
            ? _handleSendFriendRequest
            : null,
        requests: _friendRequests,
        onAcceptRequest: _handleAcceptRequest,
        onDeclineRequest: _handleDeclineRequest,
        onOpenProfile: widget.api.isRemote ? _openProfile : null,
        onRefresh: widget.api.isRemote ? _refreshAll : null,
        onSearchUsers: widget.api.isRemote
            ? (query, cursor) => _guard(
                () => widget.api.searchUsers(query: query, cursor: cursor),
              )
            : null,
        onLoadMore: widget.api.isRemote ? _loadMoreUsers : null,
        onLoadSuggestions: widget.api.isRemote
            ? (cursor) =>
                  _guard(() => widget.api.loadSuggestions(cursor: cursor))
            : null,
      ),
      CreatePostScreen(
        currentUser: _currentUser,
        onPostCreated: _handleAddPost,
        onPickPhoto: widget.api.isRemote ? _pickPhoto : null,
      ),
      NotificationsScreen(
        notifications: _notifications,
        onNotificationTap: _handleNotificationTap,
        onRefresh: widget.api.isRemote ? _refreshAll : null,
        onLoadMore: widget.api.isRemote ? _loadMoreNotifications : null,
        onMarkAllRead: _openNotifications,
        serverTabs: widget.api.isRemote ? _tabStates(_notificationTabs) : null,
        onLoadTab: widget.api.isRemote
            ? (category, {bool more = false}) =>
                  _loadNotificationTab(category, more: more)
            : null,
      ),
      ProfileScreen(
        posts: _posts,
        user: _currentUser,
        friends: _users
            .where((u) => u.isFriend && u.id != _currentUser.id)
            .toList(),
        onOpenProfile: widget.api.isRemote ? _openProfile : null,
        loadPhotos: widget.api.isRemote
            ? (cursor) => _guard(
                () =>
                    widget.api.loadUserPhotos(_currentUser.id, cursor: cursor),
              )
            : null,
        loadFriends: widget.api.isRemote
            ? (cursor) => _guard(
                () =>
                    widget.api.loadUserFriends(_currentUser.id, cursor: cursor),
              )
            : null,
        onChangeCover: widget.api.isRemote ? _changeCover : null,
        onOpenFollowers: widget.api.isRemote
            ? () => showFollowListSheet(
                context,
                title: 'Người theo dõi',
                loadUsers: (cursor) =>
                    widget.api.loadFollowers(_currentUser.id, cursor: cursor),
                onOpenProfile: _openProfile,
              )
            : null,
        onOpenFollowing: widget.api.isRemote
            ? () => showFollowListSheet(
                context,
                title: 'Đang theo dõi',
                loadUsers: (cursor) =>
                    widget.api.loadFollowing(_currentUser.id, cursor: cursor),
                onOpenProfile: _openProfile,
              )
            : null,
        onEditProfile: _openEditProfile,
        onOpenSaved: _openSavedPosts,
        onVerifyEmail: widget.api.isRemote && !_currentUser.emailVerified
            ? _openVerifyEmail
            : null,
        onLogout: widget.api.isRemote ? () => widget.onLogout() : null,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: SocialBottomNav(
        currentIndex: _selectedIndex,
        unreadNotificationCount: _unreadNotificationCount,
        onTap: _handleTabTap,
      ),
    );
  }
}

/// What MainScreen remembers about one server-backed tab.
class _ServerTab {
  Set<String>? ids;
  String? cursor;
  bool loading = false;
  String? error;
}
