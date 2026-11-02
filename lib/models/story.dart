import 'package:flutter/material.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/user.dart';

class Story {
  final String id;
  final UserModel user;
  final String? imageUrl;
  final String? text;
  final bool isViewed;
  final List<Color> gradientColors;

  /// When it was posted, as people read it ("5 phút trước").
  final String time;

  /// The song attached to the story (server only), with its preview.
  final MusicTrack? track;

  /// Who can see it, as the label people read ("Bạn bè", "Công khai",
  /// "Chỉ mình tôi"), like [Post.privacy].
  final String privacy;

  const Story({
    required this.id,
    required this.user,
    this.imageUrl,
    this.text,
    required this.isViewed,
    required this.gradientColors,
    this.time = 'Vừa xong',
    this.track,
    this.privacy = 'Bạn bè',
  });

  Story copyWith({UserModel? user, bool? isViewed, String? privacy}) => Story(
    id: id,
    user: user ?? this.user,
    imageUrl: imageUrl,
    text: text,
    isViewed: isViewed ?? this.isViewed,
    gradientColors: gradientColors,
    time: time,
    track: track,
    privacy: privacy ?? this.privacy,
  );
}
