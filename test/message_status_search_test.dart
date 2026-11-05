import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/utils/chat_search.dart';
import 'package:flutter_learning/utils/message_status.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(
  String id,
  String text, {
  String sender = 'me',
  bool recalled = false,
}) => ChatMessage(
  id: id,
  senderId: sender,
  text: text,
  time: '1 phút',
  isRecalled: recalled,
);

void main() {
  group('sendState', () {
    test(
      'is sent, then delivered, then seen as the other person\'s markers move',
      () {
        expect(sendState('m3', null, null), SendState.sent);
        expect(sendState('m3', 'm2', null), SendState.sent);
        expect(sendState('m3', 'm3', null), SendState.delivered);
        expect(sendState('m3', 'm5', 'm2'), SendState.delivered);
        expect(sendState('m3', 'm5', 'm3'), SendState.seen);
        expect(sendState('m1', 'm5', 'm3'), SendState.seen);
      },
    );

    test('a message with a local id is still being sent', () {
      expect(sendState('message_1730000000', 'm9', 'm9'), SendState.sending);
    });
  });

  group('lastSeenOfMine', () {
    test('is the newest of my messages up to what the other person read', () {
      final list = [
        _msg('m1', 'a'),
        _msg('m2', 'b', sender: 'them'),
        _msg('m3', 'c'),
        _msg('m4', 'd'),
      ];
      expect(lastSeenOfMine(list, 'me', 'm3'), 'm3');
      expect(lastSeenOfMine(list, 'me', 'm2'), 'm1');
      expect(lastSeenOfMine(list, 'me', null), isNull);
    });

    test('skips a recalled message', () {
      final list = [_msg('m1', 'a'), _msg('m2', '', recalled: true)];
      expect(lastSeenOfMine(list, 'me', 'm2'), 'm1');
    });
  });

  group('in-chat search', () {
    test('ignores accents and case', () {
      expect(normalizeForSearch('Hà Nội, Đà Lạt'), 'ha noi, da lat');
      expect(messageMatches(_msg('m1', 'Hẹn ở Hà Nội nhé'), 'ha noi'), isTrue);
      expect(messageMatches(_msg('m2', 'Tối nay'), 'TOI'), isTrue);
      expect(messageMatches(_msg('m3', 'Tối nay'), '  '), isFalse);
    });

    test(
      'looks at what was written, not at quotes, stickers or recalled messages',
      () {
        expect(
          messageMatches(
            _msg('m1', '[reply:m0:Lan:số tài khoản]\nĐược rồi'),
            'tai khoan',
          ),
          isFalse, // only in the quote
        );
        expect(
          messageMatches(
            _msg('m1', '[reply:m0:Lan:số tài khoản]\nĐược rồi'),
            'duoc',
          ),
          isTrue,
        );
        expect(
          messageMatches(
            _msg('m2', '[sticker:3d_haha:https://fonts.gstatic.com/x.webp]'),
            'haha',
          ),
          isFalse,
        );
        expect(
          messageMatches(_msg('m3', 'bí mật', recalled: true), 'bi mat'),
          isFalse,
        );
      },
    );
  });
}
