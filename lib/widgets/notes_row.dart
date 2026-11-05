import 'package:flutter/material.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_note.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/privacy_sheet.dart';
import 'package:flutter_learning/widgets/track_picker.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// The row of notes above the conversation list: my own note first (or a
/// button to write one), then my friends' notes. Tapping a friend's note
/// answers it with a message.
class NotesRow extends StatelessWidget {
  final List<UserNote> notes;
  final UserModel currentUser;

  /// Shares (or replaces) my note; throws [ApiException] when refused.
  final Future<void> Function(String text, MusicTrack? track, String privacy)
  onSetNote;
  final Future<void> Function() onDeleteNote;
  final ValueChanged<UserModel> onReply;

  /// Sends a quick emoji to the author of a note (server only).
  final void Function(UserModel user, String emoji)? onReact;

  /// Finding and previewing a song for a note.
  final Future<List<MusicTrack>> Function(String query)? searchMusic;
  final AudioPreview audio;

  const NotesRow({
    super.key,
    required this.notes,
    required this.currentUser,
    required this.onSetNote,
    required this.onDeleteNote,
    required this.onReply,
    this.onReact,
    this.searchMusic,
    this.audio = const NoAudioPreview(),
  });

  @override
  Widget build(BuildContext context) {
    UserNote? mine;
    final others = <UserNote>[];
    for (final note in notes) {
      if (note.user.id == currentUser.id) {
        mine = note;
      } else {
        others.add(note);
      }
    }

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _NoteItem(
            user: currentUser,
            text: mine == null ? null : _shown(mine),
            hasTrack: mine?.track != null,
            label: 'Ghi chú của bạn',
            semantics: mine == null
                ? 'Chia sẻ ghi chú của bạn'
                : 'Ghi chú của bạn: ${_shown(mine)}. Bấm để sửa',
            onTap: () => showNoteSheet(
              context,
              current: mine,
              onSave: onSetNote,
              onDelete: onDeleteNote,
              searchMusic: searchMusic,
              audio: audio,
            ),
          ),
          for (final note in others)
            _NoteItem(
              user: note.user,
              text: _shown(note),
              hasTrack: note.track != null,
              label: note.user.name,
              semantics:
                  'Ghi chú của ${note.user.name}: ${_shown(note)}. Bấm để xem và tương tác',
              onTap: () => _showNoteDetail(context, note),
            ),
        ],
      ),
    );
  }
}

/// What a note's bubble shows: the text, or the song when there is no text.
String noteBubbleText(UserNote note) =>
    note.text.isNotEmpty ? note.text : (note.track?.title ?? '');

extension on NotesRow {
  String _shown(UserNote note) => noteBubbleText(note);

  Future<void> _showNoteDetail(BuildContext context, UserNote note) =>
      showNoteDetail(
        context,
        note,
        audio: audio,
        onReply: onReply,
        onReact: onReact,
      );
}

/// A note with quick reactions: who shared it, text, song player (if any),
/// quick emoji reaction bar and a "Nhắn tin" button.
Future<void> showNoteDetail(
  BuildContext context,
  UserNote note, {
  required AudioPreview audio,
  ValueChanged<UserModel>? onReply,
  void Function(UserModel user, String emoji)? onReact,
}) {
  final track = note.track;
  if (track != null) {
    playPreview(context, audio, track.previewUrl);
  }
  const quickEmojis = ['❤️', '🔥', '😂', '😍', '🙌', '💯', '👀', '👏'];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(imageUrl: note.user.avatarUrl, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.user.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '@${note.user.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (note.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(note.text, style: const TextStyle(fontSize: 15)),
              ),
            ],
            if (track != null) ...[
              const SizedBox(height: 12),
              TrackCard(track: track, audio: audio),
            ],
            if (onReact != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Thả cảm xúc nhanh',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final emoji in quickEmojis)
                      InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onReact(note.user, emoji);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (onReply != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onReply(note.user);
                  },
                  child: Text('Nhắn tin cho ${note.user.name}'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ).whenComplete(audio.stop);
}

class _NoteItem extends StatelessWidget {
  final UserModel user;
  final String? text;
  final bool hasTrack;
  final String label;
  final String semantics;
  final VoidCallback onTap;

  const _NoteItem({
    required this.user,
    required this.text,
    this.hasTrack = false,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              // The bubble sits above the avatar; without a note my own item
              // shows a "+" prompt in its place.
              Container(
                height: 38,
                width: 76,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: text == null ? palette.brandSoft : palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: palette.border),
                ),
                child: text == null
                    ? Icon(Icons.add_rounded, size: 18, color: palette.brand)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasTrack)
                            Icon(
                              Icons.music_note_rounded,
                              size: 12,
                              color: palette.brand,
                            ),
                          Flexible(
                            child: Text(
                              text!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 4),
              UserAvatar(imageUrl: user.avatarUrl, radius: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Writes, replaces or removes my note. [current] is the text I have now.
Future<void> showNoteSheet(
  BuildContext context, {
  required UserNote? current,
  required Future<void> Function(String text, MusicTrack? track, String privacy)
  onSave,
  required Future<void> Function() onDelete,
  Future<List<MusicTrack>> Function(String query)? searchMusic,
  AudioPreview audio = const NoAudioPreview(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NoteForm(
      current: current,
      onSave: onSave,
      onDelete: onDelete,
      searchMusic: searchMusic,
      audio: audio,
    ),
  ).whenComplete(audio.stop);
}

class _NoteForm extends StatefulWidget {
  final UserNote? current;
  final Future<void> Function(String text, MusicTrack? track, String privacy)
  onSave;
  final Future<void> Function() onDelete;
  final Future<List<MusicTrack>> Function(String query)? searchMusic;
  final AudioPreview audio;

  const _NoteForm({
    required this.current,
    required this.onSave,
    required this.onDelete,
    required this.searchMusic,
    required this.audio,
  });

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current?.text,
  );
  late MusicTrack? _track = widget.current?.track;
  late String _privacy = widget.current?.privacy ?? 'Bạn bè';
  bool _busy = false;
  String? _error;

  Future<void> _pickPrivacy() async {
    final label = await showPrivacySheet(context, current: _privacy);
    if (label != null && mounted) setState(() => _privacy = label);
  }

  Future<void> _pickTrack() async {
    final track = await showTrackPicker(
      context,
      search: widget.searchMusic!,
      audio: widget.audio,
    );
    if (track != null && mounted) setState(() => _track = track);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = _controller.text.trim();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ghi chú', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Bạn bè sẽ thấy ghi chú này trong 24 giờ.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: UserNote.maxLength,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Chia sẻ điều gì đó...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.searchMusic != null) ...[
                if (_track == null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickTrack,
                    icon: const Icon(Icons.music_note_rounded),
                    label: const Text('Thêm nhạc'),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: TrackArtwork(url: _track!.artworkUrl),
                    title: Text(_track!.title, maxLines: 1),
                    subtitle: Text(_track!.artist, maxLines: 1),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: widget.audio.playing,
                          builder: (context, playingUrl, _) {
                            final isPlaying = playingUrl == _track!.previewUrl;
                            return IconButton(
                              tooltip: isPlaying ? 'Dừng nghe thử' : 'Nghe thử',
                              onPressed: () => isPlaying
                                  ? widget.audio.stop()
                                  : playPreview(
                                      context,
                                      widget.audio,
                                      _track!.previewUrl,
                                    ),
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                size: 32,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Bỏ nhạc',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _track = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    onTap: _busy ? null : _pickTrack,
                  ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  privacyOptions
                      .firstWhere((option) => option.$1 == _privacy)
                      .$2,
                ),
                title: const Text('Ai xem được ghi chú'),
                subtitle: Text(_privacy),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _pickPrivacy,
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: colorScheme.error)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy || (text.isEmpty && _track == null)
                      ? null
                      : () => _run(() => widget.onSave(text, _track, _privacy)),
                  child: Text(widget.current == null ? 'Chia sẻ' : 'Cập nhật'),
                ),
              ),
              if (widget.current != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _busy ? null : () => _run(widget.onDelete),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text('Xóa ghi chú'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
