import 'package:flutter/material.dart';
import 'package:flutter_learning/widgets/load_more_listener.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/widgets/post_moderation.dart';
import 'package:flutter_learning/utils/post_search.dart';
import 'package:flutter_learning/widgets/comments_sheet.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/share_sheet.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

enum ExploreFilter { forYou, trending, shortVideo }

extension on ExploreFilter {
  String get label {
    switch (this) {
      case ExploreFilter.forYou:
        return 'Dành cho bạn';
      case ExploreFilter.trending:
        return 'Đang thịnh hành';
      case ExploreFilter.shortVideo:
        return 'Video ngắn';
    }
  }
}

class ExploreScreen extends StatefulWidget {
  /// The shared post list owned by MainScreen. Explore only reads it.
  final List<Post> posts;

  /// Pull-to-refresh. When null (the mock app) Explore does not refresh.
  final Future<void> Function()? onRefresh;

  /// Loads the next page when the list is scrolled near its end.
  final VoidCallback? onLoadMore;

  /// Comments, shares and profile links in the post details. Null on the mock
  /// app, whose details stay read-only.
  final PostInteractions? interactions;
  final void Function(String postId, int count)? onCommentCountChanged;

  /// Opens the Messages screen ("Gửi trong tin nhắn").
  final VoidCallback? onOpenMessages;

  /// Which posts the user saved, and the save toggle.
  final Set<String> savedPostIds;
  final ValueChanged<String>? onToggleSave;

  const ExploreScreen({
    super.key,
    required this.posts,
    this.onRefresh,
    this.onLoadMore,
    this.interactions,
    this.onCommentCountChanged,
    this.onOpenMessages,
    this.savedPostIds = const {},
    this.onToggleSave,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // Bumped whenever MainScreen gives Explore new posts, so an open details
  // sheet (a separate route) shows the current counts and saved state.
  final ValueNotifier<int> _postsVersion = ValueNotifier(0);

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After this frame: listeners (the open details sheet) must not be marked
    // dirty while the tree is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _postsVersion.value++;
    });
  }

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  ExploreFilter _selectedFilter = ExploreFilter.forYou;

  @override
  void dispose() {
    _postsVersion.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Posts to show, worked out from widget.posts on every build so Explore
  /// always reflects MainScreen's current state. widget.posts is never
  /// modified; sorting happens on a new list.
  List<Post> get _visiblePosts {
    final matching = searchPosts(widget.posts, _searchQuery);

    switch (_selectedFilter) {
      case ExploreFilter.forYou:
        return matching;
      case ExploreFilter.trending:
        return matching..sort((a, b) => b.likes.compareTo(a.likes));
      case ExploreFilter.shortVideo:
        // Posts have no video field yet, so nothing can match this filter.
        return const [];
    }
  }

  void _openSearch() => setState(() => _isSearching = true);

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showPostDetails(Post post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final interactions = widget.interactions;
        if (interactions == null) return _ExplorePostDetails(post: post);

        return ListenableBuilder(
          listenable: _postsVersion,
          builder: (context, _) {
            // The post as it is now (likes, comments and shares can change
            // while the sheet is open).
            final current = widget.posts.firstWhere(
              (candidate) => candidate.id == post.id,
              orElse: () => post,
            );
            final isSaved = widget.savedPostIds.contains(post.id);
            return _ExplorePostDetails(
              post: current,
              onOpenAuthor: () {
                Navigator.pop(sheetContext);
                interactions.onOpenProfile(current.author);
              },
              menu: PostModerationMenu(
                post: current,
                interactions: interactions,
                // Explore lists public posts only, so a post that is no longer
                // public leaves Explore (and this sheet) at once.
                onPrivacyChanged: (label) {
                  if (label != 'Công khai') Navigator.pop(sheetContext);
                },
                // The blocked person's posts are gone; leave the sheet.
                onBlocked: () => Navigator.pop(sheetContext),
              ),
              actions: _ExploreActions(
                post: current,
                isSaved: isSaved,
                onToggleSave: widget.onToggleSave == null
                    ? null
                    : () {
                        widget.onToggleSave!(post.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                isSaved
                                    ? 'Đã bỏ lưu bài viết của ${current.author.name}'
                                    : 'Đã lưu bài viết của ${current.author.name}',
                              ),
                            ),
                          );
                      },
                onComments: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CommentsSheet(
                    post: current,
                    interactions: interactions,
                    onCountChanged: (count) =>
                        widget.onCommentCountChanged?.call(post.id, count),
                  ),
                ),
                onShare: () => showShareSheet(
                  context,
                  post: current,
                  interactions: interactions,
                  onOpenMessages: () {
                    // Close the details too, so Messages opens from Explore.
                    Navigator.pop(sheetContext);
                    widget.onOpenMessages?.call();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _visiblePosts;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // While searching, the back arrow closes search and the field's own
        // clear button empties the query.
        leading: _isSearching
            ? IconButton(
                onPressed: _closeSearch,
                tooltip: 'Đóng tìm kiếm',
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: _isSearching
            ? _buildSearchField(context)
            : const Text(
                'Khám phá',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              onPressed: _openSearch,
              tooltip: 'Tìm kiếm bài viết',
              icon: const Icon(Icons.search_rounded),
            ),
        ],
      ),
      body: _refreshable(
        CustomScrollView(
          physics: widget.onRefresh == null
              ? null
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    for (final filter in ExploreFilter.values) ...[
                      if (filter != ExploreFilter.values.first)
                        const SizedBox(width: 8),
                      _ExploreFilterButton(
                        label: filter.label,
                        selected: filter == _selectedFilter,
                        onPressed: () =>
                            setState(() => _selectedFilter = filter),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (visiblePosts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ExploreTile(
                      post: visiblePosts[index],
                      onTap: () => _showPostDetails(visiblePosts[index]),
                      isSaved: widget.savedPostIds.contains(
                        visiblePosts[index].id,
                      ),
                    ),
                    childCount: visiblePosts.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Wraps the grid in pull-to-refresh when the app can refresh it.
  Widget _refreshable(Widget child) {
    final onRefresh = widget.onRefresh;
    return LoadMoreListener(
      onLoadMore: widget.onLoadMore,
      child: onRefresh == null
          ? child
          : RefreshIndicator(onRefresh: onRefresh, child: child),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Semantics(
      label: 'Tìm kiếm bài viết theo nội dung hoặc tác giả',
      textField: true,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Tìm bài viết hoặc tác giả',
          border: InputBorder.none,
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.clear_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final IconData icon;
    final String title;
    final String subtitle;
    if (widget.posts.isEmpty) {
      icon = Icons.explore_off_rounded;
      title = 'Chưa có bài viết nào để khám phá';
      subtitle = 'Bài viết mới sẽ xuất hiện ở đây.';
    } else if (_selectedFilter == ExploreFilter.shortVideo) {
      icon = Icons.videocam_off_outlined;
      title = 'Chưa có video ngắn';
      subtitle = 'SocialHub hiện chỉ hỗ trợ bài viết chữ và ảnh.';
    } else {
      icon = Icons.search_off_rounded;
      title = 'Không tìm thấy bài viết phù hợp';
      subtitle = 'Thử từ khóa khác hoặc xóa tìm kiếm.';
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExploreFilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ExploreFilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: 'Bộ lọc $label',
        onTap: onPressed,
        excludeSemantics: true,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: selected
                ? colorScheme.primary
                : Theme.of(context).cardColor,
            foregroundColor: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
            side: selected
                ? BorderSide.none
                : BorderSide(color: colorScheme.outlineVariant),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final bool isSaved;

  const _ExploreTile({
    required this.post,
    required this.onTap,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = post.hasMedia;
    final summary = post.content.isEmpty ? 'Bài viết có ảnh' : post.content;

    return Semantics(
      button: true,
      label:
          'Bài viết của ${post.author.name}: $summary, '
          '${post.likes} lượt thích, ${post.comments} bình luận',
      onTapHint: 'Xem bài viết',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: AppDecorations.card(context),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: hasImage
                      ? PostMedia(post: post, playable: false)
                      : Container(
                          color: colorScheme.primaryContainer,
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            post.content,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasImage && post.content.isNotEmpty) ...[
                        Text(
                          post.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          UserAvatar(
                            imageUrl: post.author.avatarUrl,
                            radius: 12,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              post.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSaved) ...[
                            Icon(
                              Icons.bookmark_rounded,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(
                            post.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 14,
                            color: post.isLiked
                                ? AppPalette.of(context).like
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${post.likes}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only view of a post opened from an Explore tile.
class _ExplorePostDetails extends StatelessWidget {
  final Post post;

  /// Opens the author's profile. Null on the mock app.
  final VoidCallback? onOpenAuthor;

  /// Save, comment and share buttons. Null on the mock app.
  final Widget? actions;

  /// The "⋯" menu (report, block, change audience). Null on the mock app.
  final Widget? menu;

  const _ExplorePostDetails({
    required this.post,
    this.onOpenAuthor,
    this.actions,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = TextStyle(color: colorScheme.onSurfaceVariant);
    final meta = [
      post.createdAt,
      if (post.feeling?.isNotEmpty == true)
        'đang ${post.feeling!.toLowerCase()}',
      if (post.privacy?.isNotEmpty == true) post.privacy!,
    ].join(' · ');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenAuthor,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  UserAvatar(imageUrl: post.author.avatarUrl, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(meta, style: secondary.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  ?menu,
                ],
              ),
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(post.content, style: const TextStyle(height: 1.5)),
            ],
            if (post.hasMedia) ...[
              const SizedBox(height: 14),
              PostMedia(post: post),
            ],
            const SizedBox(height: 14),
            Text(
              '${post.likes} lượt thích · ${post.comments} bình luận · '
              '${post.shares} lượt chia sẻ',
              style: secondary,
            ),
            ?actions,
          ],
        ),
      ),
    );
  }
}

/// Save, comment and share for the post in Explore's details.
class _ExploreActions extends StatelessWidget {
  final Post post;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final VoidCallback onComments;
  final VoidCallback onShare;

  const _ExploreActions({
    required this.post,
    required this.isSaved,
    required this.onToggleSave,
    required this.onComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Bình luận',
              child: TextButton.icon(
                onPressed: onComments,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text('${post.comments}'),
              ),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: 'Chia sẻ',
              child: TextButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined),
                label: Text('${post.shares}'),
              ),
            ),
          ),
          if (onToggleSave != null)
            Expanded(
              child: Tooltip(
                message: isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
                child: TextButton.icon(
                  onPressed: onToggleSave,
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isSaved ? colorScheme.primary : null,
                  ),
                  label: Text(isSaved ? 'Đã lưu' : 'Lưu'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
