import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/friend_request.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/load_more_listener.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Filter pills for the Friends screen (4.5: All, Friends list, People you may know).
enum FriendsCategoryFilter {
  all('Tất cả mọi người'),
  connected('Danh sách bạn bè'),
  suggestions('Người bạn có thể biết');

  final String label;
  const FriendsCategoryFilter(this.label);
}

class FriendsScreen extends StatefulWidget {
  /// Every known user, passed in by MainScreen. The current user is left out
  /// of the list shown here.
  final List<UserModel> users;
  final UserModel currentUser;

  /// Users the current user already sent a request to (from the server).
  final Set<String> pendingUserIds;

  /// When set, "Thêm bạn" sends a real friend request and "Đang chờ" stays
  /// pending until the other person accepts. When null the screen simulates
  /// the whole flow locally, as the mock app always did.
  final ValueChanged<String>? onSendFriendRequest;

  /// Requests other people sent to the current user (server only).
  final List<FriendRequest> requests;
  final ValueChanged<FriendRequest>? onAcceptRequest;
  final ValueChanged<FriendRequest>? onDeclineRequest;

  /// Opens a user's profile when their name or photo is tapped.
  final ValueChanged<UserModel>? onOpenProfile;

  /// Pull-to-refresh. When null (the mock app) the list does not refresh.
  final Future<void> Function()? onRefresh;

  /// Server search by name or username. When null (the mock app) the typed
  /// text only filters the users the screen was given.
  final Future<UserPage> Function(String query, String? cursor)? onSearchUsers;

  /// Loads the next page of the plain (not searched) list.
  final VoidCallback? onLoadMore;

  const FriendsScreen({
    super.key,
    required this.users,
    required this.currentUser,
    this.pendingUserIds = const {},
    this.onSendFriendRequest,
    this.requests = const [],
    this.onAcceptRequest,
    this.onDeclineRequest,
    this.onOpenProfile,
    this.onRefresh,
    this.onSearchUsers,
    this.onLoadMore,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

enum _FriendStatus { add, pending, friends }

class _FriendsScreenState extends State<FriendsScreen> {
  // Friend requests made in this session. Users without an entry use the
  // status from their isFriend field.
  final Map<String, _FriendStatus> _friendStatuses = {};
  String _searchQuery = '';
  FriendsCategoryFilter _category = FriendsCategoryFilter.all;

  // Server search state (only when onSearchUsers is set).
  Timer? _debounce;
  List<UserModel>? _results;
  Set<String> _resultPendingIds = {};
  String? _resultCursor;
  bool _searching = false;
  bool _loadingMoreResults = false;
  String? _searchError;

  bool get _searchesOnServer =>
      widget.onSearchUsers != null && _searchQuery.trim().isNotEmpty;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _searchQuery = value);
    if (widget.onSearchUsers == null) return;

    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _searchQuery.trim();
    try {
      final page = await widget.onSearchUsers!(query, null);
      // A newer search replaced this one while it was running.
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _results = page.users;
        _resultPendingIds = page.pendingIds;
        _resultCursor = page.nextCursor;
        _searching = false;
        _searchError = null;
      });
    } on ApiException catch (error) {
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = error.displayMessage;
      });
    }
  }

  void _loadMore() {
    if (!_searchesOnServer) {
      widget.onLoadMore?.call();
      return;
    }
    _loadMoreResults();
  }

  Future<void> _loadMoreResults() async {
    final cursor = _resultCursor;
    if (cursor == null || _loadingMoreResults || _searching) return;
    final query = _searchQuery.trim();
    _loadingMoreResults = true;
    try {
      final page = await widget.onSearchUsers!(query, cursor);
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        final known = {for (final user in _results ?? <UserModel>[]) user.id};
        _results = [
          ...?_results,
          for (final user in page.users)
            if (!known.contains(user.id)) user,
        ];
        _resultPendingIds = {..._resultPendingIds, ...page.pendingIds};
        _resultCursor = page.nextCursor;
      });
    } on ApiException {
      // The next scroll tries again.
    } finally {
      _loadingMoreResults = false;
    }
  }

  _FriendStatus _statusOf(UserModel user) {
    return _friendStatuses[user.id] ??
        (user.isFriend
            ? _FriendStatus.friends
            : widget.pendingUserIds.contains(user.id) ||
                  _resultPendingIds.contains(user.id)
            ? _FriendStatus.pending
            : _FriendStatus.add);
  }

  List<UserModel> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();
    return (_searchesOnServer ? _results ?? const <UserModel>[] : widget.users)
        .where((user) => user.id != widget.currentUser.id)
        // People who asked us are answered in the requests section above.
        .where(
          (user) =>
              !widget.requests.any((request) => request.sender.id == user.id),
        )
        .where(
          (user) =>
              _searchesOnServer || user.name.toLowerCase().contains(query),
        )
        .where((user) {
          switch (_category) {
            case FriendsCategoryFilter.all:
              return true;
            case FriendsCategoryFilter.connected:
              return _statusOf(user) == _FriendStatus.friends;
            case FriendsCategoryFilter.suggestions:
              return _statusOf(user) != _FriendStatus.friends;
          }
        })
        .toList(growable: false);
  }

  void _updateFriendStatus(UserModel user) {
    final currentStatus = _statusOf(user);
    if (currentStatus == _FriendStatus.friends) return;

    final sendRequest = widget.onSendFriendRequest;
    if (sendRequest != null) {
      // The other person has to accept, so only "add" does anything.
      if (currentStatus != _FriendStatus.add) return;
      sendRequest(user.id);
    }

    setState(() {
      _friendStatuses[user.id] = currentStatus == _FriendStatus.add
          ? _FriendStatus.pending
          : _FriendStatus.friends;
    });
  }

  String _statusLabel(_FriendStatus status) {
    switch (status) {
      case _FriendStatus.add:
        return 'Thêm bạn';
      case _FriendStatus.pending:
        return 'Đang chờ';
      case _FriendStatus.friends:
        return 'Bạn bè';
    }
  }

  /// Rows above the user list: a title plus one row per friend request.
  int get _headerCount =>
      widget.requests.isEmpty ? 0 : widget.requests.length + 1;

  Widget _buildRequestRow(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    if (index == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Lời mời kết bạn (${widget.requests.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }

    final request = widget.requests[index - 1];
    final sender = request.sender;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(
        context,
        borderColor: colorScheme.primary.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: widget.onOpenProfile == null
                  ? null
                  : () => widget.onOpenProfile!(sender),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  UserAvatar(imageUrl: sender.avatarUrl, radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.time,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Chấp nhận lời mời của ${sender.name}',
            excludeSemantics: true,
            child: FilledButton(
              onPressed: () => widget.onAcceptRequest?.call(request),
              child: const Text('Chấp nhận'),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Từ chối lời mời của ${sender.name}',
            excludeSemantics: true,
            child: IconButton(
              tooltip: 'Từ chối',
              onPressed: () => widget.onDeclineRequest?.call(request),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredUsers = _filteredUsers;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text(
          'Friends',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bạn bè',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => _onQueryChanged(''),
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in FriendsCategoryFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(category.label),
                          selected: _category == category,
                          showCheckmark: false,
                          selectedColor: colorScheme.primary,
                          backgroundColor: Theme.of(context).cardColor,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _category == category
                                ? Colors.white
                                : colorScheme.onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: _category == category
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _refreshable(
                  filteredUsers.isEmpty && widget.requests.isEmpty
                      ? _emptyState(colorScheme)
                      : ListView.builder(
                          physics: widget.onRefresh == null
                              ? null
                              : const AlwaysScrollableScrollPhysics(),
                          itemCount: _headerCount + filteredUsers.length,
                          itemBuilder: (context, index) {
                            if (index < _headerCount) {
                              return _buildRequestRow(context, index);
                            }
                            final friend = filteredUsers[index - _headerCount];
                            final status = _statusOf(friend);
                            final statusLabel = _statusLabel(status);
                            return HoverableCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Photo and name open the profile. They sit
                                  // directly in this Row, not in an inner one.
                                  GestureDetector(
                                    onTap: widget.onOpenProfile == null
                                        ? null
                                        : () => widget.onOpenProfile!(friend),
                                    child: UserAvatar(
                                      imageUrl: friend.avatarUrl,
                                      radius: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: widget.onOpenProfile == null
                                          ? null
                                          : () => widget.onOpenProfile!(friend),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${friend.mutualFriends} bạn chung',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: statusLabel,
                                    child: Semantics(
                                      button: status != _FriendStatus.friends,
                                      label: '$statusLabel với ${friend.name}',
                                      child: OutlinedButton(
                                        onPressed:
                                            status == _FriendStatus.friends
                                            ? null
                                            : () => _updateFriendStatus(friend),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              status == _FriendStatus.pending
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                          side: BorderSide(
                                            color:
                                                status == _FriendStatus.pending
                                                ? colorScheme.primary
                                                : colorScheme.outline,
                                          ),
                                        ),
                                        child: Text(statusLabel),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme colorScheme) {
    final message = Center(
      child: _searching
          ? const CircularProgressIndicator()
          : Text(
              _searchError ?? 'Không tìm thấy người dùng',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
    );
    // A list that fills the screen, so pulling down still reaches the
    // refresh indicator when there is nothing to show.
    return widget.onRefresh == null
        ? message
        : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(hasScrollBody: false, child: message),
            ],
          );
  }

  Widget _refreshable(Widget child) {
    final refresh = widget.onRefresh;
    return LoadMoreListener(
      onLoadMore: widget.onSearchUsers == null && widget.onLoadMore == null
          ? null
          : _loadMore,
      child: refresh == null
          ? child
          : RefreshIndicator(onRefresh: refresh, child: child),
    );
  }
}
