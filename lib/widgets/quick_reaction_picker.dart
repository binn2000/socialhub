import 'package:flutter/material.dart';
import 'package:flutter_learning/data/quick_reactions.dart';

/// A sheet with the emojis the quick send button can use; returns the one
/// picked (null when closed).
Future<String?> showQuickReactionPicker(
  BuildContext context, {
  required String current,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biểu tượng cảm xúc nhanh',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Nút này thay nút gửi khi ô nhập trống. Cả hai người đều thấy.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emoji in kQuickReactions)
                  Semantics(
                    button: true,
                    selected: emoji == current,
                    label: 'Dùng $emoji',
                    child: InkWell(
                      onTap: () => Navigator.pop(sheetContext, emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: emoji == current
                              ? colorScheme.primaryContainer
                              : null,
                          border: emoji == current
                              ? Border.all(color: colorScheme.primary)
                              : null,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
