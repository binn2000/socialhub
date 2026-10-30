import 'package:flutter/material.dart';

/// The three audiences of a post, as the labels the app already uses.
const privacyOptions = [
  ('Công khai', Icons.public_rounded),
  ('Bạn bè', Icons.people_alt_rounded),
  ('Chỉ mình tôi', Icons.lock_outline_rounded),
];

/// Lets the author pick who can see a post. Returns the chosen label, or
/// null when nothing changed.
Future<String?> showPrivacySheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Ai có thể xem bài viết này?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          for (final (label, icon) in privacyOptions)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: label == current ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.pop(sheetContext, label == current ? null : label),
            ),
        ],
      ),
    ),
  );
}
