import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/chat_stickers.dart';

void main() {
  group('Chat Emojis and Stickers Data', () {
    test('contains populated emoji categories and sticker packs', () {
      expect(kEmojiCategories.length, greaterThanOrEqualTo(5));
      expect(kStickerPacks.length, greaterThanOrEqualTo(4));
      expect(kStickerPacks[0].stickers.length, greaterThanOrEqualTo(8));
    });

    test('detects and parses sticker messages correctly', () {
      const stickerPayload =
          '[sticker:3d_haha:https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/512.webp]';
      expect(isStickerMessage(stickerPayload), isTrue);
      expect(isStickerMessage('Xin chào bạn!'), isFalse);
      expect(isStickerMessage(null), isFalse);

      final parsed = parseStickerMessage(stickerPayload);
      expect(parsed, isNotNull);
      expect(parsed?.id, '3d_haha');
      expect(parsed?.url, contains('1f602/512.webp'));
    });

    test('a reply shows only what was written in a preview', () {
      expect(
        formatMessagePreview('[reply:m1:Lan:Bạn khỏe không?]\nMình khỏe'),
        'Mình khỏe',
      );
      expect(
        formatMessagePreview(
          '[reply:m1:Lan:Xin chào]\n[sticker:3d_haha:https://x/y.webp]',
        ),
        '[Nhãn dán]',
      );
      expect(
        formatMessagePreview('[reply:m1:Lan:Xin chào]\n'),
        'Đã trả lời một tin nhắn',
      );
    });

    test('formats message preview for sticker messages', () {
      const stickerPayload =
          '[sticker:3d_love:https://example.com/sticker.webp]';
      expect(formatMessagePreview(stickerPayload), '[Nhãn dán]');
      expect(
        formatMessagePreview('Hẹn gặp lại chiều nay'),
        'Hẹn gặp lại chiều nay',
      );
      expect(formatMessagePreview(null), '');
    });

    test('a sticker is found by id, never by the address in the message', () {
      expect(findStickerById('3d_haha')?.url, contains('1f602/512.webp'));
      expect(findStickerById('no_such_sticker'), isNull);
      // A message can carry any address; only the id is used.
      final parsed = parseStickerMessage(
        '[sticker:3d_haha:https://evil.example/x.png]',
      );
      expect(parsed?.id, '3d_haha');
      expect(findStickerById(parsed!.id)?.url, isNot(contains('evil')));
    });

    test('every sticker has its own id and a Noto emoji address', () {
      final ids = [
        for (final pack in kStickerPacks)
          for (final sticker in pack.stickers) sticker.id,
      ];
      expect(ids.toSet().length, ids.length);
      for (final pack in kStickerPacks) {
        for (final sticker in pack.stickers) {
          expect(
            sticker.url,
            startsWith('https://fonts.gstatic.com/s/e/notoemoji/'),
          );
        }
      }
    });
  });
}
