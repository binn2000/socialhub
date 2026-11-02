import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  final UserModel currentUser;
  final void Function(
    String text,
    String feeling,
    String privacy,
    String? imageUrl,
    String? imageId,
  )
  onPostCreated;

  /// Opens the photo library and returns the chosen file's path. When set,
  /// "Thêm ảnh" picks a real photo (and the post is sent with it); when null
  /// it picks one of the mock images.
  final Future<String?> Function()? onPickPhoto;

  /// Whether a post is currently being uploaded to the server.
  final bool isSubmitting;

  const CreatePostScreen({
    super.key,
    required this.currentUser,
    required this.onPostCreated,
    this.onPickPhoto,
    this.isSubmitting = false,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  static const _defaultFeeling = 'Cảm thấy vui';
  static const _defaultPrivacy = 'Công khai';

  String _selectedFeeling = _defaultFeeling;
  String _selectedPrivacy = _defaultPrivacy;
  MockImageChoice? _selectedImage;
  String? _photoPath;
  String? _statusMessage;
  bool _statusIsError = false;

  /// Multiple photo paths when picked on a real device.
  final List<String> _photoPaths = [];

  bool get _hasImage =>
      _selectedImage != null || _photoPath != null || _photoPaths.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showValidationMessage() {
    setState(() {
      _statusMessage = 'Hãy thêm nội dung hoặc chọn một ảnh';
      _statusIsError = true;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Hãy thêm nội dung hoặc chọn một ảnh')),
      );
  }

  Future<void> _pickPhoto() async {
    final path = await widget.onPickPhoto!();
    if (path == null || !mounted) return;
    setState(() {
      _photoPath = path;
      if (!_photoPaths.contains(path)) {
        if (_photoPaths.length < 10) _photoPaths.add(path);
      }
    });
  }

  void _openMockImagePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn ảnh mock',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...mockImageChoices.map(
                  (image) => ListTile(
                    leading: MockImagePreview(image: image, size: 48),
                    title: Text(image.label),
                    trailing: _selectedImage == image
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedImage = image);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
                if (_selectedImage != null)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
                    title: const Text('Xóa ảnh đã chọn'),
                    onTap: () {
                      setState(() => _selectedImage = null);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitPost() {
    if (widget.isSubmitting) return;
    final text = _controller.text.trim();
    if (text.isEmpty && !_hasImage) {
      _showValidationMessage();
      return;
    }
    final primaryPath = _photoPaths.isNotEmpty
        ? _photoPaths.first
        : (_photoPath ?? _selectedImage?.assetPath);
    widget.onPostCreated(
      text,
      _selectedFeeling,
      _selectedPrivacy,
      primaryPath,
      _selectedImage?.id,
    );
    // This tab stays alive in MainScreen's IndexedStack, so start a fresh
    // form; otherwise the old post is still here and could be posted twice.
    _resetForm(statusMessage: 'Đã đăng bài viết thành công');
  }

  void _resetForm({String? statusMessage}) {
    setState(() {
      _controller.clear();
      _selectedFeeling = _defaultFeeling;
      _selectedPrivacy = _defaultPrivacy;
      _selectedImage = null;
      _photoPath = null;
      _photoPaths.clear();
      _statusMessage = statusMessage;
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tạo bài viết',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: widget.isSubmitting ? null : _submitPost,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đăng'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_statusMessage != null && !_statusIsError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: palette.success,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: palette.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  UserAvatar(
                    imageUrl: widget.currentUser.avatarUrl,
                    radius: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.public_rounded, size: 14),
                              const SizedBox(width: 4),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPrivacy,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Công khai',
                                      child: Text('Công khai'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Bạn bè',
                                      child: Text('Bạn bè'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Chỉ mình tôi',
                                      child: Text('Chỉ mình tôi'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedPrivacy = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Bạn đang nghĩ gì?',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppDecorations.card(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _photoPaths.length > 1
                          ? 'Đã chọn ${_photoPaths.length} ảnh'
                          : 'Thêm ảnh',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (widget.onPickPhoto != null) ...[
                      if (_photoPath != null || _photoPaths.isNotEmpty) ...[
                        TextButton(
                          onPressed: () => setState(() {
                            _photoPath = null;
                            _photoPaths.clear();
                          }),
                          child: const Text('Xóa ảnh'),
                        ),
                        TextButton(
                          onPressed: _pickPhoto,
                          child: Text(
                            _photoPaths.length > 1 ? '+ Thêm ảnh' : 'Đổi ảnh',
                          ),
                        ),
                      ],
                      if (_photoPath == null && _photoPaths.isEmpty)
                        TextButton(
                          onPressed: _pickPhoto,
                          child: const Text('Chọn ảnh'),
                        ),
                    ] else
                      TextButton(
                        onPressed: _openMockImagePicker,
                        child: Text(
                          _selectedImage == null ? 'Chọn ảnh mock' : 'Đổi ảnh',
                        ),
                      ),
                  ],
                ),
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 12),
                MockImagePreview(image: _selectedImage!, size: 220),
              ],
              if (_photoPaths.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final path = _photoPaths[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(path),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => setState(() {
                                _photoPaths.removeAt(idx);
                                if (_photoPath == path) {
                                  _photoPath = _photoPaths.isNotEmpty
                                      ? _photoPaths.first
                                      : null;
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else if (_photoPath != null) ...[
                const SizedBox(height: 12),
                _PhotoPreview(path: _photoPath!, height: 220),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppDecorations.card(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.mood_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cảm xúc',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedFeeling,
                      items: const [
                        DropdownMenuItem(
                          value: 'Cảm thấy vui',
                          child: Text('Cảm thấy vui'),
                        ),
                        DropdownMenuItem(
                          value: 'Hứng thú',
                          child: Text('Hứng thú'),
                        ),
                        DropdownMenuItem(
                          value: 'Hạnh phúc',
                          child: Text('Hạnh phúc'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedFeeling = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PostPreview(
                currentUser: widget.currentUser,
                text: _controller.text,
                feeling: _selectedFeeling,
                privacy: _selectedPrivacy,
                image: _selectedImage,
                photoPath: _photoPath,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  final UserModel currentUser;
  final String text;
  final String? feeling;
  final String? privacy;
  final MockImageChoice? image;
  final String? photoPath;

  const _PostPreview({
    required this.currentUser,
    required this.text,
    required this.feeling,
    required this.privacy,
    required this.image,
    required this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedText = text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(
        context,
        borderColor: colorScheme.outlineVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Xem trước', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatar(imageUrl: currentUser.avatarUrl, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentUser.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                Icons.public_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (feeling != null || privacy != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (feeling != null && feeling!.isNotEmpty)
                  'đang ${feeling!.toLowerCase()}',
                if (privacy != null && privacy!.isNotEmpty) privacy!,
              ].join(' · '),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          if (trimmedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(trimmedText),
          ],
          if (image != null) ...[
            const SizedBox(height: 12),
            MockImagePreview(image: image!, size: double.infinity),
          ],
          if (photoPath != null) ...[
            const SizedBox(height: 12),
            _PhotoPreview(path: photoPath!, height: 160),
          ],
          if (trimmedText.isEmpty && image == null && photoPath == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Bài viết sẽ hiển thị ở đây',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// A photo picked from the device, shown before it is posted.
class _PhotoPreview extends StatelessWidget {
  final String path;
  final double height;

  const _PhotoPreview({required this.path, required this.height});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: double.infinity,
          height: height,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
