import 'package:flutter_learning/models/user.dart';

class Post {
  final String id;
  final UserModel author;
  final String content;
  final String? imageUrl;
  final String? imageId;
  final String? feeling;
  final String? privacy;
  final String createdAt;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isVideo;
  final String? videoDuration;

  const Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    this.imageId,
    this.feeling,
    this.privacy,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    this.isVideo = false,
    this.videoDuration,
  });

  /// Returns a copy with the given fields replaced. Only the fields the app
  /// changes today are listed, like UserModel.copyWith.
  Post copyWith({
    UserModel? author,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    String? privacy,
  }) {
    return Post(
      id: id,
      author: author ?? this.author,
      content: content,
      imageUrl: imageUrl,
      imageId: imageId,
      feeling: feeling,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isVideo: isVideo,
      videoDuration: videoDuration,
    );
  }
}
