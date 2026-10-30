import 'package:flutter/material.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/report_sheet.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// The comments of one post: the list, a box to add one, and delete for the
/// comment's author and the post's author.
class CommentsSheet extends StatefulWidget {
  final Post post;
  final PostInteractions interactions;

  /// Called with the post's new comment count after a comment is added or
  /// removed, so the card behind the sheet stays correct.
  final ValueChanged<int> onCountChanged;

  const CommentsSheet({
    super.key,
    required this.post,
    required this.interactions,
    required this.onCountChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  List<Comment>? _comments;
  late int _count = widget.post.comments;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await widget.interactions.loadComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.displayMessage);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result = await widget.interactions.addComment(widget.post.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [result.comment, ...?_comments];
        _count = result.commentsCount;
        _sending = false;
        _controller.clear();
      });
      widget.onCountChanged(result.commentsCount);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _delete(Comment comment) async {
    try {
      await widget.interactions.deleteComment(widget.post.id, comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments?.where((c) => c.id != comment.id).toList();
        _count = _count > 0 ? _count - 1 : 0;
      });
      widget.onCountChanged(_count);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.displayMessage);
    }
  }

  bool _canDelete(Comment comment) {
    final me = widget.interactions.currentUserId;
    return comment.author.id == me || widget.post.author.id == me;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comments = _comments;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_count bình luận',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            // Short states get a fixed height: a Center would otherwise grow
            // to fill the whole 40% the list may use.
            child: comments == null
                ? SizedBox(
                    height: 96,
                    child: Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _load,
                              child: const Text('Thử lại'),
                            ),
                    ),
                  )
                : comments.isEmpty
                ? SizedBox(
                    height: 96,
                    child: Center(
                      child: Text(
                        'Chưa có bình luận nào',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => widget.interactions.onOpenProfile(
                                comment.author,
                              ),
                              customBorder: const CircleBorder(),
                              child: UserAvatar(
                                imageUrl: comment.author.avatarUrl,
                                radius: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.author.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(comment.content),
                                  Text(
                                    comment.time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (comment.author.id !=
                                    widget.interactions.currentUserId &&
                                widget.interactions.report != null)
                              IconButton(
                                tooltip: 'Báo cáo bình luận',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => showReportSheet(
                                  context,
                                  what: 'bình luận',
                                  send: (reason, details) =>
                                      widget.interactions.report!(
                                        'comment',
                                        comment.id,
                                        reason,
                                        details,
                                      ),
                                ),
                                icon: const Icon(Icons.flag_outlined),
                              ),
                            if (_canDelete(comment))
                              IconButton(
                                tooltip: 'Xóa bình luận',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _delete(comment),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null && comments != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: colorScheme.error)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Viết bình luận...',
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Gửi bình luận',
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                onPressed: _sending ? null : _send,
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
        ],
      ),
    );
  }
}
