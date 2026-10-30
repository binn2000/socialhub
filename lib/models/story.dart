import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';

class Story {
  final String id;
  final UserModel user;
  final String? imageUrl;
  final String? text;
  final bool isViewed;
  final List<Color> gradientColors;

  const Story({
    required this.id,
    required this.user,
    this.imageUrl,
    this.text,
    required this.isViewed,
    required this.gradientColors,
  });

  Story copyWith({bool? isViewed}) => Story(
    id: id,
    user: user,
    imageUrl: imageUrl,
    text: text,
    isViewed: isViewed ?? this.isViewed,
    gradientColors: gradientColors,
  );
}
