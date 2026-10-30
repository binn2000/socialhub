import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';

class SocialNotification {
  final String id;
  final UserModel actor;
  final String description;
  final String time;
  final String type;
  final IconData icon;
  final Color iconColor;
  final bool isRead;
  final String? relatedContent;

  /// The post a like, comment or share is about (server only).
  final String? postId;

  const SocialNotification({
    required this.id,
    required this.actor,
    required this.description,
    required this.time,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    this.relatedContent,
    this.postId,
  });
}
