import 'package:flutter/material.dart';

/// One reaction type available for posts (Facebook-style multi-feeling bar).
class PostReaction {
  final String key;
  final String label;
  final String emoji;
  final Color color;

  const PostReaction({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

/// Standard 6 reactions: Like, Love, Haha, Wow, Sad, Angry
const List<PostReaction> kPostReactions = [
  PostReaction(
    key: 'like',
    label: 'Thích',
    emoji: '👍',
    color: Color(0xFF1877F2), // Facebook Blue
  ),
  PostReaction(
    key: 'love',
    label: 'Yêu thích',
    emoji: '❤️',
    color: Color(0xFFFA3E3E), // Rose Red
  ),
  PostReaction(
    key: 'haha',
    label: 'Haha',
    emoji: '😆',
    color: Color(0xFFF7B125), // Amber
  ),
  PostReaction(
    key: 'wow',
    label: 'Wow',
    emoji: '😮',
    color: Color(0xFFF7B125), // Amber
  ),
  PostReaction(
    key: 'sad',
    label: 'Buồn',
    emoji: '😢',
    color: Color(0xFFF7B125), // Amber
  ),
  PostReaction(
    key: 'angry',
    label: 'Phẫn nộ',
    emoji: '😡',
    color: Color(0xFFE24B26), // Deep Orange / Red
  ),
];

PostReaction? findPostReaction(String? key) {
  if (key == null) return null;
  for (final reaction in kPostReactions) {
    if (reaction.key == key) return reaction;
  }
  return null;
}
