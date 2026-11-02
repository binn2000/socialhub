import 'package:flutter/material.dart';
import 'package:flutter_learning/data/legal_texts.dart';
import 'package:flutter_learning/screens/legal_screen.dart';
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

  /// Shows the About fields (location, work, school, website, birthday).
  /// Off on the mock app, which has nowhere to keep them.
  final bool editAbout;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.editAbout = false,
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
  late final TextEditingController _locationController;
  late final TextEditingController _hometownController;
  late final TextEditingController _workplaceController;
  late final TextEditingController _educationController;
  late final TextEditingController _websiteController;
  late String _birthday;
  late bool _showOnlineStatus;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.user.avatarUrl;
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
    _showOnlineStatus = widget.user.showOnlineStatus;
    final about = widget.user.about;
    _locationController = TextEditingController(text: about.location);
    _hometownController = TextEditingController(text: about.hometown);
    _workplaceController = TextEditingController(text: about.workplace);
    _educationController = TextEditingController(text: about.education);
    _websiteController = TextEditingController(text: about.website);
    _birthday = about.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _hometownController.dispose();
    _workplaceController.dispose();
    _educationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final url = await widget.onChangeAvatar!();
    if (url == null || !mounted) return;
    setState(() => _avatarUrl = url);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_birthday);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20),
      firstDate: DateTime(1900, 1, 2),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Chọn ngày sinh',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthday =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  String? _validateWebsite(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    return ok ? null : 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
  }

  Widget _aboutField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      controller: controller,
      maxLength: label == 'Website' ? 200 : 100,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final updatedUser = widget.user.copyWith(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: _avatarUrl,
      showOnlineStatus: _showOnlineStatus,
      about: widget.editAbout
          ? UserAbout(
              location: _locationController.text.trim(),
              hometown: _hometownController.text.trim(),
              workplace: _workplaceController.text.trim(),
              education: _educationController.text.trim(),
              website: _websiteController.text.trim(),
              birthday: _birthday,
            )
          : null,
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
              if (widget.editAbout) ...[
                const SizedBox(height: 24),
                Text(
                  'Giới thiệu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _aboutField(_locationController, 'Nơi sống'),
                _aboutField(_hometownController, 'Quê quán'),
                _aboutField(_workplaceController, 'Nơi làm việc'),
                _aboutField(_educationController, 'Học vấn'),
                _aboutField(
                  _websiteController,
                  'Website',
                  validator: _validateWebsite,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Sinh nhật'),
                  subtitle: Text(
                    _birthday.isEmpty
                        ? 'Chưa chọn'
                        : UserAbout(birthday: _birthday).birthdayLabel,
                  ),
                  onTap: _pickBirthday,
                  trailing: _birthday.isEmpty
                      ? const Icon(Icons.edit_calendar_outlined)
                      : IconButton(
                          tooltip: 'Xóa ngày sinh',
                          onPressed: () => setState(() => _birthday = ''),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.circle,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                title: const Text('Hiện trạng thái online'),
                subtitle: const Text(
                  'Cho phép bạn bè nhìn thấy khi bạn đang hoạt động',
                ),
                value: _showOnlineStatus,
                onChanged: (val) => setState(() => _showOnlineStatus = val),
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
              if (widget.editAbout) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Điều khoản sử dụng'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openLegal(context, termsOfService),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Chính sách quyền riêng tư'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openLegal(context, privacyPolicy),
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
