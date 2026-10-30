import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/privacy_sheet.dart';
import 'package:flutter_learning/widgets/report_sheet.dart';

// The report / block / change-audience actions of a post, shared by the Home
// menu, Explore's details and the post detail screen so they behave the same.

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Lets the author pick a new audience. Returns the new label when the
/// server accepted it, otherwise null (nothing chosen, or refused: the app
/// already explained why).
Future<String?> changePostPrivacy(
  BuildContext context,
  PostInteractions interactions,
  Post post,
) async {
  final label = await showPrivacySheet(context, current: post.privacy);
  if (label == null || !context.mounted) return null;
  final changed = await interactions.changePrivacy!(post.id, label);
  if (!changed || !context.mounted) return null;
  _say(context, 'Đã đổi quyền riêng tư thành "$label"');
  return label;
}

Future<void> reportPost(
  BuildContext context,
  PostInteractions interactions,
  Post post,
) => showReportSheet(
  context,
  what: 'bài viết',
  send: (reason, details) =>
      interactions.report!('post', post.id, reason, details),
);

/// Asks, then blocks the post's author. Returns true when they are blocked.
Future<bool> blockPostAuthor(
  BuildContext context,
  PostInteractions interactions,
  Post post,
) async {
  final name = post.author.name;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Chặn $name?'),
      content: const Text(
        'Hai bạn sẽ không thấy bài viết của nhau và không nhắn tin hay kết '
        'bạn được.',
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
  if (confirmed != true || !context.mounted) return false;

  try {
    await interactions.blockUser!(post.author);
    if (context.mounted) _say(context, 'Đã chặn $name');
    return true;
  } on ApiException catch (error) {
    if (context.mounted) _say(context, error.displayMessage);
    return false;
  }
}

/// A "⋯" menu with the post's moderation actions: change audience for your
/// own posts, report and block for other people's. Nothing is shown when the
/// app offers none of them (the mock app).
class PostModerationMenu extends StatelessWidget {
  final Post post;
  final PostInteractions interactions;

  /// The author's new audience label, after the server accepted it.
  final ValueChanged<String>? onPrivacyChanged;

  /// Called after the author was blocked, to leave the screen.
  final VoidCallback? onBlocked;

  const PostModerationMenu({
    super.key,
    required this.post,
    required this.interactions,
    this.onPrivacyChanged,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = post.author.id == interactions.currentUserId;
    final canChange = isMine && interactions.changePrivacy != null;
    final canReport = !isMine && interactions.report != null;
    final canBlock = !isMine && interactions.blockUser != null;
    if (!canChange && !canReport && !canBlock) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn bài viết',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (value) async {
        switch (value) {
          case 'privacy':
            final label = await changePostPrivacy(context, interactions, post);
            if (label != null) onPrivacyChanged?.call(label);
          case 'report':
            await reportPost(context, interactions, post);
          case 'block':
            if (await blockPostAuthor(context, interactions, post)) {
              onBlocked?.call();
            }
        }
      },
      itemBuilder: (_) => [
        if (canChange)
          const PopupMenuItem(
            value: 'privacy',
            child: Text('Đổi quyền riêng tư'),
          ),
        if (canReport)
          const PopupMenuItem(value: 'report', child: Text('Báo cáo bài viết')),
        if (canBlock)
          PopupMenuItem(
            value: 'block',
            child: Text('Chặn ${post.author.name}'),
          ),
      ],
    );
  }
}
