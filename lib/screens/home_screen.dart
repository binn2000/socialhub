import 'package:flutter/material.dart';
import 'package:flutter_learning/widgets/load_more_listener.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/models/server_tab.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/screens/story_viewer_screen.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/utils/post_search.dart';
import 'package:flutter_learning/widgets/comments_sheet.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/post_moderation.dart';
import 'package:flutter_learning/widgets/share_sheet.dart';
import 'package:flutter_learning/widgets/story_item.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  final List<Post> posts;
  final List<Story> stories;
  final Set<String> savedPostIds;
  final Function(String) onToggleLike;

  /// Chooses a reaction for a post (server only; null keeps the local one).
  final void Function(String postId, String reaction)? onReact;
  final ValueChanged<String> onToggleSave;
  final ValueChanged<String> onHidePost;
  final ValueChanged<String> onUndoHidePost;
  final VoidCallback onOpenCreate;
  final VoidCallback onOpenStoryCreator;
  final VoidCallback onOpenMessages;

  /// Unread messages, shown as a small number on the Messages icon.
  final int unreadMessageCount;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  /// Real comments, shares and profile links. Null on the mock app, which
  /// keeps the simple session-only comment box and share sheet.
  final PostInteractions? interactions;

  /// Called with a post's new comment count when comments change.
  final void Function(String postId, int count)? onCommentCountChanged;

  /// Deletes one of the current user's own posts. When null the menu has no
  /// delete item (the mock app).
  final ValueChanged<String>? onDeletePost;

  /// Called when the story viewer shows a story, so it can be marked seen.
  final ValueChanged<Story>? onStoryViewed;

  /// Pull-to-refresh. When null (the mock app) the feed does not refresh.
  final Future<void> Function()? onRefresh;

  /// Loads the next page when the list is scrolled near its end.
  final VoidCallback? onLoadMore;

  /// The feed tabs that come from the server, by API name (`following`,
  /// `media`), and how to load one (`more` asks for its next page). Both are
  /// null on the mock app, where the tabs filter the posts it has.
  final Map<String, ServerTabState>? serverTabs;
  final void Function(String filter, {bool more})? onLoadTab;

  /// Deletes one of my stories from the story viewer. Null on the mock app.
  final ValueChanged<Story>? onDeleteStory;

  /// Changes who can see one of my stories. Null on the mock app.
  final void Function(Story story, String privacy)? onChangeStoryPrivacy;

  /// Sends a quick emoji to the author of a story (server only).
  final void Function(Story story, String emoji)? onReactToStory;

  /// Plays the song of a story in the story viewer.
  final AudioPreview audio;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.posts,
    required this.stories,
    required this.savedPostIds,
    required this.onToggleLike,
    this.onReact,
    required this.onToggleSave,
    required this.onHidePost,
    required this.onUndoHidePost,
    required this.onOpenCreate,
    required this.onOpenStoryCreator,
    required this.onOpenMessages,
    this.unreadMessageCount = 0,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.interactions,
    this.onCommentCountChanged,
    this.onDeletePost,
    this.onStoryViewed,
    this.onRefresh,
    this.onLoadMore,
    this.serverTabs,
    this.onLoadTab,
    this.onDeleteStory,
    this.onChangeStoryPrivacy,
    this.onReactToStory,
    this.audio = const NoAudioPreview(),
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _showStoryViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            StoryViewerScreen(
              stories: widget.stories,
              initialIndex: initialIndex,
              onViewed: widget.onStoryViewed,
              currentUserId: widget.currentUser.id,
              onDelete: widget.onDeleteStory,
              onChangePrivacy: widget.onChangeStoryPrivacy,
              onReact: widget.onReactToStory,
              audio: widget.audio,
            ),
        transitionsBuilder:
            (routeContext, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
      ),
    );
  }

  List<Widget> _buildStoryItems(BuildContext context) {
    final orderedIndexes = <int>[];
    orderedIndexes.addAll(
      widget.stories
          .asMap()
          .entries
          .where((entry) => entry.value.user.id == widget.currentUser.id)
          .map((entry) => entry.key),
    );
    orderedIndexes.addAll(
      widget.stories
          .asMap()
          .entries
          .where((entry) => entry.value.user.id != widget.currentUser.id)
          .map((entry) => entry.key),
    );

    return [
      StoryItem(isAddButton: true, onTap: widget.onOpenStoryCreator),
      ...orderedIndexes.map((storyIndex) {
        final story = widget.stories[storyIndex];
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: StoryItem(
            story: story,
            onTap: () => _showStoryViewer(context, storyIndex),
          ),
        );
      }),
    ];
  }

  // Search is local UI state. The results are worked out from widget.posts
  // on every build, so they always match MainScreen's current posts.
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  HomeFeedFilter _feedFilter = HomeFeedFilter.forYou;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The server tab of the selected feed filter, or null when this filter
  /// works on the loaded posts (the mock app, and "Dành cho bạn").
  ServerTabState? get _serverTab {
    final name = _feedFilter.apiFilter;
    if (name == null || widget.onLoadTab == null) return null;
    return widget.serverTabs?[name] ?? const ServerTabState();
  }

  List<Post> _fromServerTab(List<Post> posts) {
    final ids = _serverTab!.ids;
    return ids == null
        ? const []
        : posts.where((post) => ids.contains(post.id)).toList();
  }

  /// widget.posts already excludes hidden posts (MainScreen removes them),
  /// so search can never bring a hidden post back.
  List<Post> get _searchResults {
    final searched = searchPosts(widget.posts, _searchQuery);
    if (_isSearching) return searched;
    switch (_feedFilter) {
      case HomeFeedFilter.forYou:
        return searched;
      case HomeFeedFilter.following:
        if (_serverTab != null) return _fromServerTab(searched);
        return searched
            .where(
              (post) =>
                  post.author.isFriend ||
                  post.author.id == widget.currentUser.id,
            )
            .toList();
      case HomeFeedFilter.media:
        if (_serverTab != null) return _fromServerTab(searched);
        return searched
            .where((post) => post.imageUrl != null || post.video != null)
            .toList();
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

  void _showMessage(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  void _toggleSave(BuildContext context, Post post) {
    final isSaved = widget.savedPostIds.contains(post.id);
    final authorName = post.author.name;
    widget.onToggleSave(post.id);
    _showMessage(
      context,
      SnackBar(
        content: Text(
          isSaved
              ? 'Đã bỏ lưu bài viết của $authorName'
              : 'Đã lưu bài viết của $authorName trong phiên này',
        ),
      ),
    );
  }

  void _showPostMenu(BuildContext context, Post post) {
    final isSaved = widget.savedPostIds.contains(post.id);
    final authorName = post.author.name;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void saveOrUnsave() {
          Navigator.pop(sheetContext);
          _toggleSave(context, post);
        }

        void hide() {
          Navigator.pop(sheetContext);
          widget.onHidePost(post.id);
          _showMessage(
            context,
            SnackBar(
              content: Text('Đã ẩn bài viết của $authorName khỏi bảng tin'),
              // An action normally keeps the SnackBar open until dismissed;
              // let this one close by itself like the others.
              persist: false,
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () => widget.onUndoHidePost(post.id),
              ),
            ),
          );
        }

        Future<void> delete() async {
          Navigator.pop(sheetContext);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Xóa bài viết này?'),
              content: const Text('Bài viết sẽ bị xóa khỏi tài khoản của bạn.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          widget.onDeletePost!(post.id);
          _showMessage(
            context,
            const SnackBar(content: Text('Đã xóa bài viết')),
          );
        }

        final canDelete =
            widget.onDeletePost != null &&
            post.author.id == widget.currentUser.id;
        final interactions = widget.interactions;
        final isMine = post.author.id == widget.currentUser.id;

        Future<void> changePrivacy() async {
          Navigator.pop(sheetContext);
          await changePostPrivacy(context, interactions!, post);
        }

        Future<void> report() async {
          Navigator.pop(sheetContext);
          await reportPost(context, interactions!, post);
        }

        Future<void> blockAuthor() async {
          Navigator.pop(sheetContext);
          await blockPostAuthor(context, interactions!, post);
        }

        return SafeArea(
          child: Wrap(
            children: [
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Xóa bài viết'),
                  onTap: delete,
                ),
              if (isMine && interactions?.changePrivacy != null)
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Đổi quyền riêng tư'),
                  onTap: changePrivacy,
                ),
              Semantics(
                button: true,
                toggled: isSaved,
                label: isSaved
                    ? 'Bỏ lưu bài viết của $authorName'
                    : 'Lưu bài viết của $authorName',
                onTap: saveOrUnsave,
                excludeSemantics: true,
                child: ListTile(
                  leading: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  title: Text(isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết'),
                  onTap: saveOrUnsave,
                ),
              ),
              Semantics(
                button: true,
                label: 'Ẩn bài viết của $authorName khỏi bảng tin',
                onTap: hide,
                excludeSemantics: true,
                child: ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Ẩn bài viết'),
                  onTap: hide,
                ),
              ),
              if (!isMine && interactions?.report != null)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Báo cáo bài viết'),
                  onTap: report,
                ),
              if (!isMine && interactions?.blockUser != null)
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: Text('Chặn $authorName'),
                  onTap: blockAuthor,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showComments(BuildContext context, Post post) {
    final interactions = widget.interactions;
    if (interactions != null) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => CommentsSheet(
          post: post,
          interactions: interactions,
          onCountChanged: (count) =>
              widget.onCommentCountChanged?.call(post.id, count),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${post.comments} bình luận',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Viết bình luận...',
                suffixIcon: IconButton(
                  tooltip: 'Gửi bình luận',
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bình luận đã được thêm trong phiên này'),
                      ),
                    );
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sharePost(BuildContext context, Post post) {
    final interactions = widget.interactions;
    if (interactions != null) {
      showShareSheet(
        context,
        post: post,
        interactions: interactions,
        onOpenMessages: widget.onOpenMessages,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Sao chép liên kết'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã chuẩn bị liên kết bài viết của ${post.author.name}',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('Gửi trong tin nhắn'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onOpenMessages();
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      centerTitle: false,
      titleSpacing: AppSpacing.lg + 4,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small brand mark: a rounded square with the initial.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'S',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SocialHub',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _openSearch,
          tooltip: 'Tìm kiếm bài viết',
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: widget.onToggleTheme,
          tooltip: widget.isDarkMode ? 'Chế độ sáng' : 'Chế độ tối',
          icon: AnimatedSwitcher(
            duration: AppMotion.medium,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              key: ValueKey(widget.isDarkMode),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onOpenMessages,
          tooltip: 'Tin nhắn',
          icon: widget.unreadMessageCount > 0
              ? Badge(
                  label: Text(
                    widget.unreadMessageCount > 99
                        ? '99+'
                        : '${widget.unreadMessageCount}',
                  ),
                  child: const Icon(Icons.message_rounded),
                )
              : const Icon(Icons.message_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: AppSpacing.lg),
          child: UserAvatar(imageUrl: widget.currentUser.avatarUrl, radius: 16),
        ),
      ],
    );
  }

  /// Same pattern as Explore: back arrow closes search, ✕ clears the text.
  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        onPressed: _closeSearch,
        tooltip: 'Đóng tìm kiếm',
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Semantics(
        label: 'Tìm kiếm bài viết trên bảng tin theo nội dung hoặc tác giả',
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
      ),
    );
  }

  /// "No posts" and "no search results" are different situations, so they
  /// get different messages.
  bool get _onServerTab => !_isSearching && _serverTab != null;

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_onServerTab) {
      final tab = _serverTab!;
      final name = _feedFilter.apiFilter!;
      if (tab.ids == null && tab.loading) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (tab.ids == null && tab.error != null) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tab.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              TextButton(
                onPressed: () => widget.onLoadTab!(name),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _feedFilter.emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    final noPostsAtAll = widget.posts.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noPostsAtAll ? Icons.feed_outlined : Icons.search_off_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            noPostsAtAll ? 'Chưa có bài viết' : 'Không tìm thấy bài viết',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            noPostsAtAll
                ? 'Bài viết mới sẽ xuất hiện ở đây.'
                : 'Thử từ khóa khác hoặc xóa tìm kiếm.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSaved = widget.savedPostIds.contains(post.id);
    return HoverableCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            post: post,
            onOpenProfile: widget.interactions?.onOpenProfile,
            trailing: IconButton(
              onPressed: () => _showPostMenu(context, post),
              tooltip: isSaved
                  ? 'Tùy chọn bài viết (đã lưu)'
                  : 'Tùy chọn bài viết',
              icon: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          if (post.hasMedia) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: PostMedia(post: post),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Transform.translate(
            // Lines the first icon up with the text above.
            offset: const Offset(-10, 0),
            child: PostActionBar(
              post: post,
              onLike: () => widget.onToggleLike(post.id),
              onReactionSelected: widget.onReact == null
                  ? null
                  : (reaction) => widget.onReact!(post.id, reaction.key),
              onComment: () => _showComments(context, post),
              onShare: () => _sharePost(context, post),
              isSaved: isSaved,
              onToggleSave: () => _toggleSave(context, post),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedFilterTabs(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in HomeFeedFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(filter.label),
                  selected: _feedFilter == filter,
                  showCheckmark: false,
                  selectedColor: palette.brand,
                  backgroundColor: palette.surface,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _feedFilter == filter
                        ? Colors.white
                        : palette.textSecondary,
                  ),
                  side: BorderSide(
                    color: _feedFilter == filter
                        ? palette.brand
                        : palette.border,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() => _feedFilter = filter);
                    final name = filter.apiFilter;
                    if (name != null) widget.onLoadTab?.call(name);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = colorScheme.onSurfaceVariant;
    final visiblePosts = _searchResults;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSearching ? _buildSearchAppBar() : _buildHomeAppBar(),
      body: SafeArea(
        child: _refreshable(
          CustomScrollView(
            physics: widget.onRefresh == null
                ? null
                : const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Stories and the composer are hidden while searching so the
              // results start at the top of the screen.
              if (!_isSearching) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      height: 98,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _buildStoryItems(context),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Tạo bài viết mới',
                      onTap: widget.onOpenCreate,
                      excludeSemantics: true,
                      child: PressableScale(
                        onTap: widget.onOpenCreate,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                          decoration: AppDecorations.card(
                            context,
                            radius: AppRadius.full,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                imageUrl: widget.currentUser.avatarUrl,
                                radius: 18,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  composerHint,
                                  style: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              _ComposerShortcut(
                                icon: Icons.image_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              _ComposerShortcut(
                                icon: Icons.sentiment_satisfied_alt_rounded,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildFeedFilterTabs(context)),
              ],
              if (visiblePosts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = visiblePosts[index];
                    return Padding(
                      key: ValueKey(post.id),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: FadeInUp(child: _buildPostCard(context, post)),
                    );
                  }, childCount: visiblePosts.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Wraps the feed in pull-to-refresh when the app can refresh it.
  Widget _refreshable(Widget child) {
    final onRefresh = widget.onRefresh;
    return LoadMoreListener(
      onLoadMore: _onServerTab
          ? () => widget.onLoadTab!(_feedFilter.apiFilter!, more: true)
          : widget.onLoadMore,
      child: onRefresh == null
          ? child
          : RefreshIndicator(
              onRefresh: () async {
                await onRefresh();
                if (_onServerTab) widget.onLoadTab!(_feedFilter.apiFilter!);
              },
              child: child,
            ),
    );
  }
}

/// The hint shown in the Home composer pill.
const composerHint = 'Chia sẻ điều mới với mọi người…';

/// Feed tabs shown above the Home post list.
enum HomeFeedFilter {
  forYou('Dành cho bạn', null, 'Chưa có bài viết'),
  following(
    'Đang theo dõi',
    'following',
    'Chưa có bài viết từ những người bạn theo dõi',
  ),
  media('Đa phương tiện', 'media', 'Chưa có bài viết nào có hình ảnh');

  final String label;

  /// The `filter` the server knows this tab by; null for the plain feed.
  final String? apiFilter;
  final String emptyText;
  const HomeFeedFilter(this.label, this.apiFilter, this.emptyText);
}

/// A small round icon inside the composer pill (decoration only; the whole
/// pill opens Create Post).
class _ComposerShortcut extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ComposerShortcut({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
