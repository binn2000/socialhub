import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/user.dart';

/// A short text a person shares for 24 hours ("Ghi chú").
class UserNote {
  final UserModel user;
  final String text;

  /// When it was shared, as people read it ("5 phút trước").
  final String time;

  /// The song attached to the note, if any. [text] may then be empty.
  final MusicTrack? track;

  /// Who can see it ("Bạn bè", "Công khai", "Chỉ mình tôi").
  final String privacy;

  const UserNote({
    required this.user,
    required this.text,
    this.time = '',
    this.track,
    this.privacy = 'Bạn bè',
  });

  /// The most characters a note can have (the server checks it too).
  static const maxLength = 60;
}
