import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/chat_interactions.dart';

void main() {
  group('Chat interactions tests', () {
    test('contains standard 6 reaction emojis', () {
      expect(kChatMessageReactions.length, 6);
      expect(kChatMessageReactions, ['❤️', '👍', '😂', '😮', '😢', '😡']);
    });

    test('builds and parses reply envelope payload cleanly', () {
      const quoted = QuotedMessage(
        id: 'msg_999',
        senderName: 'Minh Ánh',
        text: 'Bạn có khỏe không?',
      );
      const replyText = 'Mình khỏe lắm, cảm ơn bạn!';

      final payload = buildChatMessageReplyPayload(quoted, replyText);
      expect(payload, contains('[reply:msg_999:Minh Ánh:Bạn có khỏe không?]'));
      expect(payload, contains('Mình khỏe lắm, cảm ơn bạn!'));

      final parsed = parseChatMessageReply(payload);
      expect(parsed.replyTo, isNotNull);
      expect(parsed.replyTo!.id, 'msg_999');
      expect(parsed.replyTo!.senderName, 'Minh Ánh');
      expect(parsed.replyTo!.text, 'Bạn có khỏe không?');
      expect(parsed.cleanText, replyText);
    });

    test('parses normal text without reply envelope', () {
      const normal = 'Xin chào buổi sáng!';
      final parsed = parseChatMessageReply(normal);
      expect(parsed.replyTo, isNull);
      expect(parsed.cleanText, normal);
    });
  });
}
