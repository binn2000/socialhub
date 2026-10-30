import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final String coverUrl;
  final String bio;
  final int mutualFriends;
  final bool isFriend;
  final Color accentColor;

  /// Whether the email address was confirmed. Only the signed-in user's
  /// own record can be false; everyone else (and the mock) counts as true.
  final bool emailVerified;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.coverUrl,
    required this.bio,
    required this.mutualFriends,
    required this.isFriend,
    required this.accentColor,
    this.emailVerified = true,
  });

  UserModel copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    bool? isFriend,
    bool? emailVerified,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      username: username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl,
      bio: bio ?? this.bio,
      mutualFriends: mutualFriends,
      isFriend: isFriend ?? this.isFriend,
      accentColor: accentColor,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
