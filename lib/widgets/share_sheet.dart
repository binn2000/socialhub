import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/post_interactions.dart';

/// The share sheet used when a server records shares: the link really goes to
/// the clipboard and each action is counted.
void showShareSheet(
  BuildContext context, {
  required Post post,
  required PostInteractions interactions,
  required VoidCallback onOpenMessages,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Sao chép liên kết'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await Clipboard.setData(
                ClipboardData(text: 'socialhub://posts/${post.id}'),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã sao chép liên kết bài viết của ${post.author.name}',
                    ),
                  ),
                );
              interactions.sharePost(post.id, 'link');
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: const Text('Gửi trong tin nhắn'),
            onTap: () {
              Navigator.pop(sheetContext);
              interactions.sharePost(post.id, 'message');
              onOpenMessages();
            },
          ),
        ],
      ),
    ),
  );
}
