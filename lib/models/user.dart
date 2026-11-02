import 'package:flutter/material.dart';

/// The "About" fields of a profile. Every field can be empty.
class UserAbout {
  final String location;
  final String hometown;
  final String workplace;
  final String education;
  final String website;

  /// `YYYY-MM-DD`, or empty.
  final String birthday;

  const UserAbout({
    this.location = '',
    this.hometown = '',
    this.workplace = '',
    this.education = '',
    this.website = '',
    this.birthday = '',
  });

  static const empty = UserAbout();

  bool get isEmpty =>
      location.isEmpty &&
      hometown.isEmpty &&
      workplace.isEmpty &&
      education.isEmpty &&
      website.isEmpty &&
      birthday.isEmpty;

  /// The birthday as people write it in Vietnam (`dd/MM/yyyy`), or empty.
  String get birthdayLabel {
    final parts = birthday.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : '';
  }

  UserAbout copyWith({
    String? location,
    String? hometown,
    String? workplace,
    String? education,
    String? website,
    String? birthday,
  }) => UserAbout(
    location: location ?? this.location,
    hometown: hometown ?? this.hometown,
    workplace: workplace ?? this.workplace,
    education: education ?? this.education,
    website: website ?? this.website,
    birthday: birthday ?? this.birthday,
  );
}

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

  /// Location, work, school... Empty for the mock app.
  final UserAbout about;

  /// Online presence & follow status.
  final bool isOnline;
  final String? lastSeenAt;
  final bool showOnlineStatus;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool followsYou;

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
    this.about = UserAbout.empty,
    this.isOnline = false,
    this.lastSeenAt,
    this.showOnlineStatus = true,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.followsYou = false,
  });

  UserModel copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    bool? isFriend,
    bool? emailVerified,
    String? coverUrl,
    UserAbout? about,
    bool? isOnline,
    String? lastSeenAt,
    bool? showOnlineStatus,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? followsYou,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      username: username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      mutualFriends: mutualFriends,
      isFriend: isFriend ?? this.isFriend,
      accentColor: accentColor,
      emailVerified: emailVerified ?? this.emailVerified,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      followsYou: followsYou ?? this.followsYou,
    );
  }
}
