import 'package:flutter/material.dart';
import 'package:flutter_learning/services/social_api.dart';

/// Two steps: ask for a mailed code, then enter it with a new password.
/// Pops with `true` once the password was changed.
class ForgotPasswordScreen extends StatefulWidget {
  final SocialApi api;
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.api,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() call) async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _sendCode() => _run(() async {
    await widget.api.requestPasswordReset(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = true;
    });
  });

  Future<void> _reset() => _run(() async {
    await widget.api.resetPassword(
      email: _email.text.trim(),
      code: _code.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _codeSent
                    ? 'Nếu email này có tài khoản, chúng tôi đã gửi mã 6 số. '
                          'Nhập mã và mật khẩu mới.'
                    : 'Nhập email của tài khoản, chúng tôi sẽ gửi mã xác nhận.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                readOnly: _codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Vui lòng nhập email' : null,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mã xác nhận',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                      ? null
                      : 'Mã gồm 6 chữ số',
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').length < 8
                      ? 'Mật khẩu cần ít nhất 8 ký tự'
                      : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Đặt lại mật khẩu' : 'Gửi mã'),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Gửi lại mã'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
