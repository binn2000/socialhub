import 'package:flutter/material.dart';
import 'package:flutter_learning/services/social_api.dart';

/// Asks for the password before deleting the account. [onDelete] throws an
/// [ApiException] when the password is wrong; the dialog shows it and stays.
/// On success the caller leaves the screen, so the dialog does not pop itself.
Future<void> showDeleteAccountDialog(
  BuildContext context, {
  required Future<void> Function(String password) onDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DeleteAccountDialog(onDelete: onDelete),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  final Future<void> Function(String password) onDelete;

  const _DeleteAccountDialog({required this.onDelete});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty || _busy) {
      setState(() => _error = 'Vui lòng nhập mật khẩu');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete(_password.text);
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
    return AlertDialog(
      title: const Text('Xóa tài khoản?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hồ sơ, bài viết và tin nhắn của bạn sẽ biến mất và bạn bị đăng '
            'xuất ngay. Nhập mật khẩu để xác nhận.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: _busy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          child: const Text('Xóa tài khoản'),
        ),
      ],
    );
  }
}
