import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/screens/delete_account_dialog.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  /// Lets the user pick and upload a new photo, and returns its URL (or null
  /// when nothing was chosen). The button is hidden when this is null.
  final Future<String?> Function()? onChangeAvatar;

  /// Deletes the account with the password; throws ApiException when it is
  /// refused. The button is hidden when this is null (the offline app).
  final Future<void> Function(String password)? onDeleteAccount;

  /// Opens the list of blocked people (server only).
  final VoidCallback? onOpenBlocked;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.onChangeAvatar,
    this.onDeleteAccount,
    this.onOpenBlocked,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late String _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.user.avatarUrl;
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final url = await widget.onChangeAvatar!();
    if (url == null || !mounted) return;
    setState(() => _avatarUrl = url);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updatedUser = widget.user.copyWith(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: _avatarUrl,
    );
    Navigator.pop(context, updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: 'Lưu thay đổi hồ sơ',
              child: FilledButton(onPressed: _save, child: const Text('Lưu')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Semantics(
                  label: 'Ảnh đại diện hiện tại',
                  child: UserAvatar(imageUrl: _avatarUrl, radius: 48),
                ),
              ),
              if (widget.onChangeAvatar != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _changeAvatar,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Đổi ảnh đại diện'),
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tên',
                  hintText: 'Nhập tên của bạn',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tên không được để trống';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Tiểu sử',
                  hintText: 'Giới thiệu ngắn về bạn',
                  border: const OutlineInputBorder(),
                  helperText: 'Có thể để trống',
                  helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              if (widget.onOpenBlocked != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Người đã chặn'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenBlocked,
                ),
              ],
              if (widget.onDeleteAccount != null) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => showDeleteAccountDialog(
                    context,
                    onDelete: widget.onDeleteAccount!,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xóa tài khoản'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
