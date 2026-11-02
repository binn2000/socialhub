import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Plays the 30-second song previews. The app only talks to this interface,
/// so tests and the offline mock use [NoAudioPreview] (no sound, no plugin).
abstract class AudioPreview {
  /// The preview address that is playing now, or null.
  ValueListenable<String?> get playing;

  /// Plays [url] from the start, replacing what played before. With [loop]
  /// it repeats until [stop] (a story keeps its song going). Returns false
  /// when the clip could not be played.
  Future<bool> play(String url, {bool loop = false});

  Future<void> stop();

  void dispose();
}

class NoAudioPreview implements AudioPreview {
  const NoAudioPreview();

  static final _nothing = ValueNotifier<String?>(null);

  @override
  ValueListenable<String?> get playing => _nothing;

  @override
  Future<bool> play(String url, {bool loop = false}) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Real playback with the just_audio plugin.
class JustAudioPreview implements AudioPreview {
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<String?> _playing = ValueNotifier(null);
  StreamSubscription<PlayerState>? _subscription;

  JustAudioPreview() {
    _subscription = _player.playerStateStream.listen((state) {
      // A preview that ended on its own is not "playing" any more.
      if (state.processingState == ProcessingState.completed) {
        _playing.value = null;
      }
    });
  }

  @override
  ValueListenable<String?> get playing => _playing;

  @override
  Future<bool> play(String url, {bool loop = false}) async {
    try {
      _playing.value = url;
      await _player.setUrl(url);
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _player.seek(Duration.zero);
      // Not awaited: play() only completes when the clip ends.
      unawaited(_player.play());
      return true;
    } catch (error) {
      // No network, an unplayable clip, or the app was started without the
      // audio plugin (hot restart after adding it): say so, do not stay silent.
      debugPrint('Preview did not play: $error');
      _playing.value = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _playing.value = null;
    try {
      await _player.stop();
    } catch (_) {
      // Nothing was loaded.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _player.dispose();
    _playing.dispose();
  }
}

/// Plays a preview and, when it cannot be played, tells the user instead of
/// staying silent.
Future<void> playPreview(
  BuildContext context,
  AudioPreview audio,
  String url, {
  bool loop = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (await audio.play(url, loop: loop)) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Không phát được bản nghe thử. Kiểm tra mạng và âm lượng, '
          'hoặc cài lại ứng dụng.',
        ),
      ),
    );
}
