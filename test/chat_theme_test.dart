import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/models/chat_theme.dart';

void main() {
  group('ChatThemes', () {
    test(
      'contains 5 standard themes including blue, purple, sunset, midnight, emerald',
      () {
        final ids = ChatThemes.all.map((t) => t.id).toList();
        expect(
          ids,
          containsAll(['blue', 'purple', 'sunset', 'midnight', 'emerald']),
        );
      },
    );

    test('default theme is blue', () {
      expect(ChatThemes.defaultTheme.id, 'blue');
      expect(ChatThemes.findById(null).id, 'blue');
      expect(ChatThemes.findById('non_existent').id, 'blue');
    });

    test('findById returns matching theme', () {
      final purple = ChatThemes.findById('purple');
      expect(purple.id, 'purple');
      expect(purple.name, 'Hồng tím');
      expect(purple.gradient, isNotNull);

      final sunset = ChatThemes.findById('sunset');
      expect(sunset.id, 'sunset');
      expect(sunset.name, 'Hoàng hôn');
    });
  });
}
