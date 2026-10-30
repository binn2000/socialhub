import 'package:flutter/material.dart';
import 'package:flutter_learning/services/social_api.dart';

/// Enter the 6-digit code mailed at registration (or ask for a new one).
/// Pops with `true` once the email is confirmed.
class VerifyEmailScreen extends StatefulWidget {
  final SocialApi api;
  final String email;

  const VerifyEmailScreen({super.key, required this.api, this.email = ''});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.api.requestEmailVerification();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = 'Đã gửi mã mới';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.displayMessage;
      });
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.api.verifyEmail(_code.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Xác thực email')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.email.isEmpty
                    ? 'Nhập mã 6 số đã gửi tới email của bạn.'
                    : 'Nhập mã 6 số đã gửi tới ${widget.email}.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã xác thực',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                    ? null
                    : 'Mã gồm 6 chữ số',
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: colorScheme.error)),
              if (_info != null) Text(_info!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: const Text('Xác nhận'),
              ),
              TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Gửi lại mã'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
