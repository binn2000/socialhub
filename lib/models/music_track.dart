/// A song with a 30-second preview, from the Apple Music catalogue.
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String previewUrl;

  /// Where the song is on Apple Music (the previews are for listening, so the
  /// app always offers this link next to the player).
  final String? appleMusicUrl;

  /// The same song on Spotify, when the server could find it.
  final String? spotifyUrl;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.previewUrl,
    this.artworkUrl,
    this.appleMusicUrl,
    this.spotifyUrl,
  });
}
