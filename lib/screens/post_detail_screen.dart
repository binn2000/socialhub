import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/comments_sheet.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/post_moderation.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/skeleton.dart';

/// One post on its own, opened from a notification: the post, a like button
/// and its comments.
class PostDetailScreen extends StatefulWidget {
  final Future<Post> Function() load;
  final PostInteractions interactions;

  /// Likes or unlikes on the server (and in the app's own lists).
  final Future<void> Function(String postId, bool liked) onSetLiked;

  /// Deletes the post. Only offered for the current user's own posts.
  final Future<void> Function(String postId) onDelete;

  const PostDetailScreen({
    super.key,
    required this.load,
    required this.interactions,
    required this.onSetLiked,
    required this.onDelete,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final post = await widget.load();
      if (!mounted) return;
      setState(() {
        _post = post;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.displayMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLike() async {
    final post = _post!;
    final liked = !post.isLiked;
    setState(
      () => _post = post.copyWith(
        isLiked: liked,
        likes: liked ? post.likes + 1 : post.likes - 1,
      ),
    );

    try {
      await widget.onSetLiked(post.id, liked);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _post = post);
      _showError(error.displayMessage);
    }
  }

  Future<void> _confirmDelete() async {
    final post = _post!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bài viết này?'),
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
    if (confirmed != true || !mounted) return;

    try {
      await widget.onDelete(post.id);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) _showError(error.displayMessage);
    }
  }

  void _showComments() {
    final post = _post!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => CommentsSheet(
        post: post,
        interactions: widget.interactions,
        onCountChanged: (count) {
          if (mounted) setState(() => _post = _post?.copyWith(comments: count));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final isMine = post?.author.id == widget.interactions.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        actions: [
          if (post != null)
            PostModerationMenu(
              post: post,
              interactions: widget.interactions,
              onPrivacyChanged: (label) =>
                  setState(() => _post = _post?.copyWith(privacy: label)),
              onBlocked: () => Navigator.pop(context),
            ),
          if (post != null && isMine)
            IconButton(
              tooltip: 'Xóa bài viết',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: post == null
          ? (_error == null
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: PostCardSkeleton(),
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
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                PostHeader(
                  post: post,
                  showFeeling: false,
                  onOpenProfile: widget.interactions.onOpenProfile,
                ),
                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    post.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (post.imageUrl != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PostMedia(post: post),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: PostActionBar(
                        post: post,
                        onLike: _toggleLike,
                        onComment: _showComments,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${post.shares} lượt chia sẻ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
