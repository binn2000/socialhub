import 'package:flutter/foundation.dart';
import 'package:flutter_learning/models/comment.dart';
import 'package:flutter_learning/models/user.dart';

/// What the post card needs from the app to show real comments, record
/// shares and open profiles. Null on the mock app, where the card keeps its
/// simple session-only behaviour.
class PostInteractions {
  final String currentUserId;
  final Future<List<Comment>> Function(String postId) loadComments;
  final Future<({Comment comment, int commentsCount})> Function(
    String postId,
    String text,
  )
  addComment;
  final Future<void> Function(String postId, String commentId) deleteComment;
  final Future<void> Function(String postId, String target) sharePost;
  final ValueChanged<UserModel> onOpenProfile;

  /// Report a post, comment or user; block a user; change the privacy of one
  /// of our own posts. The first two are errors for the caller to show.
  final Future<void> Function(
    String targetType,
    String targetId,
    String reason,
    String? details,
  )?
  report;
  final Future<void> Function(UserModel user)? blockUser;

  /// Returns false when the server refused (the app already explained why).
  final Future<bool> Function(String postId, String privacyLabel)?
  changePrivacy;

  const PostInteractions({
    required this.currentUserId,
    required this.loadComments,
    required this.addComment,
    required this.deleteComment,
    required this.sharePost,
    required this.onOpenProfile,
    this.report,
    this.blockUser,
    this.changePrivacy,
  });
}
