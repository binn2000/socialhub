import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/user.dart';

/// How the current user is related to another user.
enum Friendship { none, pendingOutgoing, pendingIncoming, friends, self }

/// Another user's profile page: the user, how we are related, their posts.
class UserProfile {
  final UserModel user;
  final Friendship friendship;

  /// The pending request when [friendship] is pendingOutgoing or
  /// pendingIncoming.
  final String? requestId;
  final List<Post> posts;

  /// True when the current user blocked this person.
  final bool isBlocked;

  final bool isFollowing;
  final bool followsYou;
  final int followersCount;
  final int followingCount;

  const UserProfile({
    required this.user,
    required this.friendship,
    this.requestId,
    required this.posts,
    this.isBlocked = false,
    this.isFollowing = false,
    this.followsYou = false,
    this.followersCount = 0,
    this.followingCount = 0,
  });
}
