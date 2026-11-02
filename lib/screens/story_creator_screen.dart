import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/widgets/privacy_sheet.dart';
import 'package:flutter_learning/widgets/track_picker.dart';
import 'package:flutter_learning/models/user.dart';

class StoryCreatorScreen extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<Story> onStoryCreated;

  /// Opens the photo library and returns the chosen file's path. When null
  /// the story is text on a coloured background only.
  final Future<String?> Function()? onPickPhoto;

  /// Finds songs to put under the story (server only, null hides the
  /// button) and plays their previews.
  final Future<List<MusicTrack>> Function(String query)? onSearchMusic;
  final AudioPreview audio;

  /// Offers the "Ai xem được" choice (server only; the mock has no audience).
  final bool showPrivacy;

  const StoryCreatorScreen({
    super.key,
    required this.currentUser,
    required this.onStoryCreated,
    this.onPickPhoto,
    this.onSearchMusic,
    this.audio = const NoAudioPreview(),
    this.showPrivacy = false,
  });

  @override
  State<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends State<StoryCreatorScreen> {
  final TextEditingController _controller = TextEditingController();
  int _selectedColor = 0;
  String? _photoPath;
  MusicTrack? _track;
  String _privacy = 'Bạn bè';

  static const _backgrounds = [
    [Color(0xFF5D6BFF), Color(0xFF9B8CFF)],
    [Color(0xFFFF7043), Color(0xFFFFC107)],
    [Color(0xFF00B894), Color(0xFF26C6DA)],
    [Color(0xFFE84393), Color(0xFF6C5CE7)],
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final path = await widget.onPickPhoto!();
    if (path == null || !mounted) return;
    setState(() => _photoPath = path);
  }

  Future<void> _pickTrack() async {
    final track = await showTrackPicker(
      context,
      search: widget.onSearchMusic!,
      audio: widget.audio,
    );
    if (track != null && mounted) setState(() => _track = track);
  }

  Future<void> _pickPrivacy() async {
    final label = await showPrivacySheet(context, current: _privacy);
    if (label != null && mounted) setState(() => _privacy = label);
  }

  void _publish() {
    final text = _controller.text.trim();
    if (text.isEmpty && _photoPath == null) return;
    widget.onStoryCreated(
      Story(
        id: 'story_${DateTime.now().millisecondsSinceEpoch}',
        user: widget.currentUser,
        imageUrl: _photoPath,
        text: text.isEmpty ? null : text,
        isViewed: false,
        gradientColors: _backgrounds[_selectedColor],
        track: _track,
        privacy: _privacy,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _backgrounds[_selectedColor];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          tooltip: 'Đóng',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Tạo tin',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3D4DD8),
                foregroundColor: Colors.white,
              ),
              onPressed: _publish,
              child: const Text('Chia sẻ'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.62,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      image: _photoPath == null
                          ? null
                          : DecorationImage(
                              image: FileImage(File(_photoPath!)),
                              fit: BoxFit.cover,
                            ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          maxLines: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Viết gì đó...',
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showPrivacy)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(
                      privacyOptions.firstWhere((o) => o.$1 == _privacy).$2,
                      size: 18,
                    ),
                    label: Text('Ai xem được: $_privacy'),
                    tooltip: 'Chọn người xem tin',
                    onPressed: _pickPrivacy,
                  ),
                ),
              ),
            if (_track != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: InputChip(
                  avatar: const Icon(Icons.music_note_rounded, size: 18),
                  label: Text(
                    '${_track!.title} · ${_track!.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteButtonTooltipMessage: 'Bỏ nhạc',
                  onDeleted: () => setState(() => _track = null),
                  onPressed: _pickTrack,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  ...List.generate(_backgrounds.length, (index) {
                    void select() => setState(() => _selectedColor = index);
                    return Semantics(
                      button: true,
                      selected: index == _selectedColor,
                      label: 'Màu nền ${index + 1}',
                      onTap: select,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: select,
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _backgrounds[index],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: index == _selectedColor
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (widget.onPickPhoto != null ||
                      widget.onSearchMusic != null)
                    const Spacer(),
                  if (widget.onSearchMusic != null)
                    IconButton(
                      tooltip: _track == null ? 'Thêm nhạc' : 'Đổi nhạc',
                      onPressed: _pickTrack,
                      icon: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.onPickPhoto != null) ...[
                    if (_photoPath != null)
                      IconButton(
                        tooltip: 'Xóa ảnh',
                        onPressed: () => setState(() => _photoPath = null),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    IconButton(
                      tooltip: _photoPath == null ? 'Chọn ảnh' : 'Đổi ảnh',
                      onPressed: _pickPhoto,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
