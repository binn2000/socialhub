import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_profile.dart';
import 'package:flutter_learning/screens/profile_screen.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/follow_list_sheet.dart';
import 'package:flutter_learning/widgets/report_sheet.dart';
import 'package:flutter_learning/widgets/skeleton.dart';

/// Another user's profile: their posts and the friend buttons that fit how
/// we are related. Each button calls the app and then reloads the profile.
class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  final Future<UserProfile> Function() load;
  final Future<void> Function(String userId) onSendRequest;
  final Future<void> Function(String requestId) onAccept;

  /// Declines a request from them, or cancels one we sent.
  final Future<void> Function(String requestId) onDeleteRequest;
  final Future<void> Function(String userId) onUnfriend;

  /// Opens the chat with this user. Offered to friends only.
  final Future<void> Function(UserModel user) onMessage;

  /// Report this person; block and unblock them.
  final Future<void> Function(String reason, String? details) onReport;
  final Future<void> Function(UserModel user) onBlock;
  final Future<void> Function(String userId) onUnblock;

  /// Server lists for the profile's "Ảnh" and "Bạn bè" tabs, and opening a
  /// friend's profile from there. Null on the mock app.
  final Future<PhotoPage> Function(String userId, String? cursor)? onLoadPhotos;
  final Future<UserPage> Function(String userId, String? cursor)? onLoadFriends;
  final ValueChanged<UserModel>? onOpenProfile;

  /// Follow/unfollow and follow lists.
  final Future<void> Function(String userId)? onFollow;
  final Future<void> Function(String userId)? onUnfollow;
  final Future<UserPage> Function(String userId, String? cursor)?
  onLoadFollowers;
  final Future<UserPage> Function(String userId, String? cursor)?
  onLoadFollowing;

  const UserProfileScreen({
    super.key,
    this.onLoadPhotos,
    this.onLoadFriends,
    this.onOpenProfile,
    this.onFollow,
    this.onUnfollow,
    this.onLoadFollowers,
    this.onLoadFollowing,
    required this.user,
    required this.load,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDeleteRequest,
    required this.onUnfriend,
    required this.onMessage,
    required this.onReport,
    required this.onBlock,
    required this.onUnblock,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.displayMessage);
    }
  }

  /// Runs a friend action, then shows the profile as it is now.
  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmUnfriend(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hủy kết bạn với ${profile.user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy kết bạn'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _act(() => widget.onUnfriend(profile.user.id));
    }
  }

  Future<void> _confirmBlock(UserProfile profile) async {
    final name = profile.user.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Chặn $name?'),
        content: const Text(
          'Hai bạn sẽ không thấy bài viết của nhau và không nhắn tin hay kết '
          'bạn được. Nếu đang là bạn bè, tình bạn sẽ kết thúc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Chặn'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _act(() => widget.onBlock(profile.user));
  }

  Widget? _actionFor(UserProfile profile) {
    if (profile.isBlocked) {
      return _wide(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _act(() => widget.onUnblock(profile.user.id)),
          icon: const Icon(Icons.lock_open_rounded),
          label: const Text('Bỏ chặn'),
        ),
      );
    }

    final requestId = profile.requestId;
    final colorScheme = Theme.of(context).colorScheme;

    Widget? followButton;
    if (widget.onFollow != null && widget.onUnfollow != null) {
      if (profile.isFollowing) {
        followButton = OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _act(() => widget.onUnfollow!(profile.user.id)),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Đang theo dõi'),
        );
      } else {
        followButton = FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () => _act(() => widget.onFollow!(profile.user.id)),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Theo dõi'),
        );
      }
    }

    switch (profile.friendship) {
      case Friendship.self:
        return null;
      case Friendship.none:
        final addFriend = FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _act(() => widget.onSendRequest(profile.user.id)),
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Thêm bạn'),
        );
        if (followButton != null) {
          return Row(
            children: [
              Expanded(child: addFriend),
              const SizedBox(width: 8),
              Expanded(child: followButton),
            ],
          );
        }
        return _wide(addFriend);
      case Friendship.pendingOutgoing:
        final cancelReq = OutlinedButton.icon(
          onPressed: _busy || requestId == null
              ? null
              : () => _act(() => widget.onDeleteRequest(requestId)),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Hủy lời mời'),
        );
        if (followButton != null) {
          return Row(
            children: [
              Expanded(child: cancelReq),
              const SizedBox(width: 8),
              Expanded(child: followButton),
            ],
          );
        }
        return _wide(cancelReq);
      case Friendship.pendingIncoming:
        final acceptRow = Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy || requestId == null
                    ? null
                    : () => _act(() => widget.onAccept(requestId)),
                child: const Text('Chấp nhận'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy || requestId == null
                    ? null
                    : () => _act(() => widget.onDeleteRequest(requestId)),
                child: const Text('Từ chối'),
              ),
            ),
          ],
        );
        if (followButton != null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              acceptRow,
              const SizedBox(height: 8),
              _wide(followButton),
            ],
          );
        }
        return acceptRow;
      case Friendship.friends:
        final friendRow = Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => widget.onMessage(profile.user),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Nhắn tin'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _confirmUnfriend(profile),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Bạn bè'),
              ),
            ),
          ],
        );
        return friendRow;
    }
  }

  Widget _wide(Widget child) => SizedBox(width: double.infinity, child: child);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile?.user.name ?? widget.user.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (profile != null && profile.friendship != Friendship.self)
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn',
              onSelected: (value) {
                if (value == 'report') {
                  showReportSheet(
                    context,
                    what: 'người dùng',
                    send: widget.onReport,
                  );
                } else if (profile.isBlocked) {
                  _act(() => widget.onUnblock(profile.user.id));
                } else {
                  _confirmBlock(profile);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Báo cáo người dùng'),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(profile.isBlocked ? 'Bỏ chặn' : 'Chặn'),
                ),
              ],
            ),
        ],
      ),
      body: profile == null
          ? (_error == null
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: const [
                      PostCardSkeleton(showMedia: false),
                      SizedBox(height: AppSpacing.md),
                      PostCardSkeleton(),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _load();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ))
          : ProfileScreen(
              posts: profile.posts,
              user: profile.user.copyWith(
                followersCount: profile.followersCount > 0
                    ? profile.followersCount
                    : profile.user.followersCount,
                followingCount: profile.followingCount > 0
                    ? profile.followingCount
                    : profile.user.followingCount,
                isFollowing: profile.isFollowing || profile.user.isFollowing,
                followsYou: profile.followsYou || profile.user.followsYou,
              ),
              action: _actionFor(profile),
              onOpenProfile: widget.onOpenProfile,
              onOpenFollowers: widget.onLoadFollowers == null
                  ? null
                  : () => showFollowListSheet(
                      context,
                      title: 'Người theo dõi',
                      loadUsers: (cursor) =>
                          widget.onLoadFollowers!(profile.user.id, cursor),
                      onOpenProfile: widget.onOpenProfile,
                    ),
              onOpenFollowing: widget.onLoadFollowing == null
                  ? null
                  : () => showFollowListSheet(
                      context,
                      title: 'Đang theo dõi',
                      loadUsers: (cursor) =>
                          widget.onLoadFollowing!(profile.user.id, cursor),
                      onOpenProfile: widget.onOpenProfile,
                    ),
              loadPhotos: widget.onLoadPhotos == null
                  ? null
                  : (cursor) => widget.onLoadPhotos!(profile.user.id, cursor),
              loadFriends: widget.onLoadFriends == null
                  ? null
                  : (cursor) => widget.onLoadFriends!(profile.user.id, cursor),
            ),
    );
  }
}
