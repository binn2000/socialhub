import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/models/user.dart';

class StoryCreatorScreen extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<Story> onStoryCreated;

  /// Opens the photo library and returns the chosen file's path. When null
  /// the story is text on a coloured background only.
  final Future<String?> Function()? onPickPhoto;

  const StoryCreatorScreen({
    super.key,
    required this.currentUser,
    required this.onStoryCreated,
    this.onPickPhoto,
  });

  @override
  State<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends State<StoryCreatorScreen> {
  final TextEditingController _controller = TextEditingController();
  int _selectedColor = 0;
  String? _photoPath;

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
        title: const Text(
          'Tạo tin',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
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
                    ),
                    child: Center(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLines: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Viết gì đó...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
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
                  if (widget.onPickPhoto != null) ...[
                    const Spacer(),
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
