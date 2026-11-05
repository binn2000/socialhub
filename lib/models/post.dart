import 'package:flutter_learning/models/post_video.dart';
import 'package:flutter_learning/models/user.dart';

class Post {
  final String id;
  final UserModel author;
  final String content;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? imageId;
  final String? feeling;
  final String? privacy;
  final String createdAt;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;

  /// My reaction (`like`, `love`, `haha`, `wow`, `sad`, `angry`), null when
  /// not liked, and how many people used each one (server only).
  final String? reaction;
  final Map<String, int> reactionCounts;
  final bool isVideo;
  final String? videoDuration;

  /// A real video from the server (the mock posts only use [isVideo]).
  final PostVideo? video;

  const Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    this.imageUrls = const [],
    this.imageId,
    this.feeling,
    this.privacy,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    this.reaction,
    this.reactionCounts = const {},
    this.isVideo = false,
    this.videoDuration,
    this.video,
  });

  /// Whether the post shows a picture or a video.
  bool get hasMedia =>
      video != null ||
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      imageUrls.isNotEmpty;

  /// All image URLs associated with this post.
  List<String> get allImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }

  /// Returns a copy with the given fields replaced. Only the fields the app
  /// changes today are listed, like UserModel.copyWith.
  Post copyWith({
    UserModel? author,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    String? reaction,
    bool clearReaction = false,
    Map<String, int>? reactionCounts,
    String? privacy,
    List<String>? imageUrls,
    PostVideo? video,
  }) {
    return Post(
      id: id,
      author: author ?? this.author,
      content: content,
      imageUrl: imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      imageId: imageId,
      feeling: feeling,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      reactionCounts: reactionCounts ?? this.reactionCounts,
      isVideo: isVideo,
      videoDuration: videoDuration,
      video: video ?? this.video,
    );
  }
}
