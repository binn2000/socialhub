import 'package:flutter/material.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/services/social_api.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// The people the current user blocked, each with an "Bỏ chặn" button.
class BlockedUsersScreen extends StatefulWidget {
  final Future<List<UserModel>> Function() load;
  final Future<void> Function(String userId) onUnblock;

  const BlockedUsersScreen({
    super.key,
    required this.load,
    required this.onUnblock,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserModel>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await widget.load();
      if (!mounted) return;
      setState(() {
        _users = users;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.displayMessage);
    }
  }

  Future<void> _unblock(UserModel user) async {
    try {
      await widget.onUnblock(user.id);
      if (!mounted) return;
      setState(() => _users = _users!.where((u) => u.id != user.id).toList());
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.displayMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Người đã chặn',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: users == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _load();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
            )
          : users.isEmpty
          ? const Center(child: Text('Bạn chưa chặn ai'))
          : ListView(
              children: [
                for (final user in users)
                  ListTile(
                    leading: UserAvatar(imageUrl: user.avatarUrl, radius: 22),
                    title: Text(user.name),
                    subtitle: Text(user.username),
                    trailing: OutlinedButton(
                      onPressed: () => _unblock(user),
                      child: const Text('Bỏ chặn'),
                    ),
                  ),
              ],
            ),
    );
  }
}
