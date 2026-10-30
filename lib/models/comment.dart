import 'package:flutter_learning/models/user.dart';

class Comment {
  final String id;
  final String postId;
  final UserModel author;
  final String content;
  final String time;

  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.time,
  });
}
