import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/skeleton.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Shows a bottom sheet listing followers or following accounts, with pagination
/// and optional follow/unfollow toggle.
Future<void> showFollowListSheet(
  BuildContext context, {
  required String title,
  required Future<UserPage> Function(String? cursor) loadUsers,
  ValueChanged<UserModel>? onOpenProfile,
  Future<void> Function(UserModel user)? onFollowToggle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => _FollowListSheetContent(
        title: title,
        loadUsers: loadUsers,
        scrollController: scrollController,
        onOpenProfile: onOpenProfile,
        onFollowToggle: onFollowToggle,
      ),
    ),
  );
}

class _FollowListSheetContent extends StatefulWidget {
  final String title;
  final Future<UserPage> Function(String? cursor) loadUsers;
  final ScrollController scrollController;
  final ValueChanged<UserModel>? onOpenProfile;
  final Future<void> Function(UserModel user)? onFollowToggle;

  const _FollowListSheetContent({
    required this.title,
    required this.loadUsers,
    required this.scrollController,
    this.onOpenProfile,
    this.onFollowToggle,
  });

  @override
  State<_FollowListSheetContent> createState() =>
      _FollowListSheetContentState();
}

class _FollowListSheetContentState extends State<_FollowListSheetContent> {
  final List<UserModel> _users = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final Set<String> _togglingIds = {};

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _cursor == null) return;
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loadUsers(null);
      if (!mounted) return;
      setState(() {
        _users.clear();
        _users.addAll(page.users);
        _cursor = page.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.loadUsers(_cursor);
      if (!mounted) return;
      setState(() {
        _users.addAll(page.users);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow(UserModel user) async {
    if (widget.onFollowToggle == null || _togglingIds.contains(user.id)) return;
    setState(() => _togglingIds.add(user.id));
    try {
      await widget.onFollowToggle!(user);
      if (!mounted) return;
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        final current = _users[index];
        final nowFollowing = !current.isFollowing;
        setState(() {
          _users[index] = current.copyWith(
            isFollowing: nowFollowing,
            followersCount: current.followersCount + (nowFollowing ? 1 : -1),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            widget.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const Row(
                    children: [
                      SkeletonBox(
                        width: 44,
                        height: 44,
                        radius: AppRadius.full,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 120, height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 80, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _loadFirstPage,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Danh sách trống',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: _users.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: palette.border, indent: 68),
                  itemBuilder: (context, index) {
                    if (index == _users.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final user = _users[index];
                    final isToggling = _togglingIds.contains(user.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      leading: UserAvatar(
                        imageUrl: user.avatarUrl,
                        radius: 22,
                        isOnline: user.isOnline,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: user.username.isNotEmpty
                          ? Text(
                              user.username,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: widget.onFollowToggle != null
                          ? (user.isFollowing
                                ? OutlinedButton(
                                    onPressed: isToggling
                                        ? null
                                        : () => _toggleFollow(user),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: isToggling
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Đang theo dõi'),
                                  )
                                : FilledButton.tonal(
                                    onPressed: isToggling
                                        ? null
                                        : () => _toggleFollow(user),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                    ),
                                    child: isToggling
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Theo dõi'),
                                  ))
                          : null,
                      onTap: widget.onOpenProfile != null
                          ? () {
                              Navigator.pop(context);
                              widget.onOpenProfile!(user);
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
