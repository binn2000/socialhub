import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/post_parts.dart';

/// The posts the user saved, newest save first. Unsaving removes a post from
/// the list at once.
class SavedPostsScreen extends StatefulWidget {
  final Future<List<Post>> Function() load;

  /// Unsaves a post (the app also updates its own saved state).
  final ValueChanged<String> onUnsave;

  /// Opens an author's profile. Null when profiles are not available.
  final ValueChanged<UserModel>? onOpenProfile;

  const SavedPostsScreen({
    super.key,
    required this.load,
    required this.onUnsave,
    this.onOpenProfile,
  });

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Post>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await widget.load();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      // A failed refresh keeps the list that is already there.
      if (_posts == null) setState(() => _error = error.displayMessage);
    }
  }

  void _unsave(Post post) {
    setState(() => _posts = _posts?.where((p) => p.id != post.id).toList());
    widget.onUnsave(post.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final posts = _posts;

    Widget body;
    if (posts == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _load();
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
      );
    } else if (posts.isEmpty) {
      // Scrollable, so pulling down still refreshes an empty list.
      body = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Bạn chưa lưu bài viết nào',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn "Lưu bài viết" ở một bài để xem lại tại đây.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: posts.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _SavedPostCard(
            post: posts[index],
            onUnsave: () => _unsave(posts[index]),
            onOpenProfile: widget.onOpenProfile,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bài đã lưu')),
      body: SafeArea(child: body),
    );
  }
}

class _SavedPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onUnsave;
  final ValueChanged<UserModel>? onOpenProfile;

  const _SavedPostCard({
    required this.post,
    required this.onUnsave,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            post: post,
            showFeeling: false,
            onOpenProfile: onOpenProfile,
            trailing: IconButton(
              tooltip: 'Bỏ lưu bài viết',
              onPressed: onUnsave,
              icon: Icon(Icons.bookmark_rounded, color: colorScheme.primary),
            ),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(post.content, style: textTheme.bodyLarge),
          ],
          if (post.imageUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            PostMedia(post: post),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '${post.likes} lượt thích · ${post.comments} bình luận · '
            '${post.shares} lượt chia sẻ',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
