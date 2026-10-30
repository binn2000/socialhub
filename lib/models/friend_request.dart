import 'package:flutter_learning/models/user.dart';

/// A pending friend request sent to the current user.
class FriendRequest {
  final String id;
  final UserModel sender;
  final String time;

  const FriendRequest({
    required this.id,
    required this.sender,
    required this.time,
  });
}
