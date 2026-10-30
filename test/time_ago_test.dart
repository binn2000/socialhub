import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/utils/time_ago.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);

  String ago(Duration d) =>
      timeAgo(now.subtract(d).toIso8601String(), now: now);

  test('formats recent times in Vietnamese', () {
    expect(ago(const Duration(seconds: 20)), 'Vừa xong');
    expect(ago(const Duration(minutes: 15)), '15 phút trước');
    expect(ago(const Duration(hours: 3)), '3 giờ trước');
    expect(ago(const Duration(hours: 30)), 'Hôm qua');
    expect(ago(const Duration(days: 4)), '4 ngày trước');
  });

  test('older times use a date and bad input gives an empty string', () {
    final text = ago(const Duration(days: 30));
    expect(text, matches(RegExp(r'^\d{2}/\d{2}/\d{4}$')));
    expect(timeAgo('not a date'), '');
  });
}
