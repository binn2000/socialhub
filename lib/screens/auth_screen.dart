import 'package:flutter/material.dart';
import 'package:flutter_learning/data/legal_texts.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/screens/forgot_password_screen.dart';
import 'package:flutter_learning/screens/legal_screen.dart';
import 'package:flutter_learning/services/social_api.dart';

/// Sign in / sign up, shown when the app runs against a server and no saved
/// session exists.
class AuthScreen extends StatefulWidget {
  final SocialApi api;
  final ValueChanged<UserModel> onAuthenticated;

  /// A message to show above the form, for example "session expired".
  final String? notice;

  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.notice,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _acceptedTerms = false;
  bool _termsMissing = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final formOk = _formKey.currentState!.validate();
    if (_isRegister && !_acceptedTerms) setState(() => _termsMissing = true);
    if (!formOk || (_isRegister && !_acceptedTerms)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = _isRegister
          ? await widget.api.register(
              name: _name.text.trim(),
              username: _username.text.trim().toLowerCase(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (!mounted) return;
      widget.onAuthenticated(user);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _openForgotPassword() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          api: widget.api,
          initialEmail: _email.text.trim(),
        ),
      ),
    );
    if (changed != true || !mounted) return;
    setState(() {
      _password.clear();
      _error = null;
      _info = 'Đã đổi mật khẩu, hãy đăng nhập lại';
    });
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SocialHub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister
                          ? 'Tạo tài khoản mới'
                          : 'Đăng nhập để tiếp tục',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    if (widget.notice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.notice!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Tên cần ít nhất 2 ký tự'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên người dùng',
                          helperText: 'Chữ thường, số và dấu gạch dưới',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            RegExp(
                              r'^[a-zA-Z0-9_]{3,30}$',
                            ).hasMatch(value ?? '')
                            ? null
                            : 'Từ 3 đến 30 ký tự: chữ, số hoặc _',
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          _required(value, 'Vui lòng nhập email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          _isRegister && (value ?? '').length < 8
                          ? 'Mật khẩu cần ít nhất 8 ký tự'
                          : _required(value, 'Vui lòng nhập mật khẩu'),
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _acceptedTerms,
                        onChanged: (value) => setState(() {
                          _acceptedTerms = value ?? false;
                          _termsMissing = false;
                        }),
                        title: const Text('Tôi đồng ý với các điều khoản'),
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () => openLegal(context, termsOfService),
                            child: const Text('Điều khoản sử dụng'),
                          ),
                          TextButton(
                            onPressed: () => openLegal(context, privacyPolicy),
                            child: const Text('Chính sách quyền riêng tư'),
                          ),
                        ],
                      ),
                      if (_termsMissing)
                        Text(
                          'Bạn cần đồng ý với điều khoản để đăng ký',
                          style: TextStyle(color: colorScheme.error),
                        ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegister ? 'Đăng ký' : 'Đăng nhập'),
                    ),
                    if (!_isRegister)
                      TextButton(
                        onPressed: _busy ? null : _openForgotPassword,
                        child: const Text('Quên mật khẩu?'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                      child: Text(
                        _isRegister
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
