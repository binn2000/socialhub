import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

/// Shown next to every preview: the songs come from Apple Music and the
/// previews are only for listening.
const musicCredit = 'Nguồn nhạc: Apple Music · nghe thử 30 giây';

/// Lets the user search for a song and listen to its preview. Returns the
/// chosen song, or null when the sheet was closed.
Future<MusicTrack?> showTrackPicker(
  BuildContext context, {
  required Future<List<MusicTrack>> Function(String query) search,
  required AudioPreview audio,
}) async {
  final chosen = await showModalBottomSheet<MusicTrack>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TrackPicker(search: search, audio: audio),
  );
  await audio.stop();
  return chosen;
}

class _TrackPicker extends StatefulWidget {
  final Future<List<MusicTrack>> Function(String query) search;
  final AudioPreview audio;

  const _TrackPicker({required this.search, required this.audio});

  @override
  State<_TrackPicker> createState() => _TrackPickerState();
}

class _TrackPickerState extends State<_TrackPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MusicTrack>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    try {
      final tracks = await widget.search(query);
      // A newer search replaced this one while it was running.
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = tracks;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = null;
        _loading = false;
        _error = error.displayMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = _results;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm bài hát hoặc nghệ sĩ',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm bài hát',
                            onPressed: () {
                              _controller.clear();
                              _onChanged('');
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    musicCredit,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(child: _body(context, results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<MusicTrack>? results) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget message(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );

    if (_loading && (results == null || results.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            TextButton(onPressed: _search, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (results == null) return message('Gõ tên bài hát để tìm.');
    if (results.isEmpty) return message('Không tìm thấy bài hát');

    return ValueListenableBuilder<String?>(
      valueListenable: widget.audio.playing,
      builder: (context, playingUrl, _) => ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final track = results[index];
          final isPlaying = playingUrl == track.previewUrl;
          return ListTile(
            leading: TrackArtwork(url: track.artworkUrl),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(context, track),
            trailing: IconButton(
              tooltip: isPlaying ? 'Dừng nghe thử' : 'Nghe thử ${track.title}',
              onPressed: () => isPlaying
                  ? widget.audio.stop()
                  : playPreview(context, widget.audio, track.previewUrl),
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The small cover picture of a song, or a music note when it has none.
class TrackArtwork extends StatelessWidget {
  final String? url;
  final double size;

  const TrackArtwork({super.key, required this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fallback = Container(
      width: size,
      height: size,
      color: palette.brandSoft,
      child: Icon(Icons.music_note_rounded, color: palette.brand),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: url == null
          ? fallback
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// A song with a play button and its Apple Music / Spotify links (copied,
/// because opening links needs a package the project does not use yet).
class TrackCard extends StatelessWidget {
  final MusicTrack track;
  final AudioPreview audio;

  const TrackCard({super.key, required this.track, required this.audio});

  Future<void> _copy(BuildContext context, String link, String what) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã sao chép liên kết $what')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: audio.playing,
          builder: (context, playingUrl, _) {
            final isPlaying = playingUrl == track.previewUrl;
            return Row(
              children: [
                TrackArtwork(url: track.artworkUrl, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isPlaying ? 'Dừng nghe thử' : 'Nghe thử',
                  onPressed: () => isPlaying
                      ? audio.stop()
                      : playPreview(context, audio, track.previewUrl),
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    size: 40,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            if (track.appleMusicUrl != null)
              TextButton.icon(
                onPressed: () =>
                    _copy(context, track.appleMusicUrl!, 'Apple Music'),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Sao chép liên kết Apple Music'),
              ),
            if (track.spotifyUrl != null)
              TextButton.icon(
                onPressed: () => _copy(context, track.spotifyUrl!, 'Spotify'),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Sao chép liên kết Spotify'),
              ),
          ],
        ),
        Text(musicCredit, style: textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
