import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/screens/friends_screen.dart';

Future<void> _pumpFriends(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FriendsScreen(users: mockUsers, currentUser: currentUser),
    ),
  );
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

/// The friend button in the same row as [userName].
Finder _friendButton(String userName) => find.descendant(
  of: find.ancestor(of: find.text(userName), matching: find.byType(Row)).first,
  matching: find.byType(OutlinedButton),
);

final _otherUsers = mockUsers.where((user) => user.id != currentUser.id);

void main() {
  testWidgets('current user is not listed', (tester) async {
    await _pumpFriends(tester);

    expect(find.text(currentUser.name), findsNothing);
  });

  testWidgets('empty search shows every other user', (tester) async {
    await _pumpFriends(tester);

    for (final user in _otherUsers) {
      expect(find.text(user.name), findsOneWidget);
    }

    // Typing and clearing the search brings everyone back.
    await _search(tester, 'minh');
    await _search(tester, '');
    for (final user in _otherUsers) {
      expect(find.text(user.name), findsOneWidget);
    }
  });

  testWidgets('search ignores letter case', (tester) async {
    await _pumpFriends(tester);

    await _search(tester, 'MINH ÁNH');

    expect(find.text('Minh Ánh'), findsOneWidget);
    expect(find.text('Duy Khang'), findsNothing);
  });

  testWidgets('search matches part of a name', (tester) async {
    await _pumpFriends(tester);

    await _search(tester, 'huy');

    expect(find.text('Quang Huy'), findsOneWidget);
    expect(find.text('Minh Ánh'), findsNothing);
    expect(find.text('Bảo Trâm'), findsNothing);
  });

  testWidgets('search with no match shows the empty state', (tester) async {
    await _pumpFriends(tester);

    await _search(tester, 'không ai tên này');

    expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('clear button resets the search', (tester) async {
    await _pumpFriends(tester);
    await _search(tester, 'zzz');

    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pump();

    expect(find.text('Không tìm thấy người dùng'), findsNothing);
    expect(find.text('Minh Ánh'), findsOneWidget);
  });

  testWidgets('Thêm bạn → Đang chờ → Bạn bè', (tester) async {
    await _pumpFriends(tester);
    const userName = 'Bảo Trâm'; // Not a friend in the mock data.

    expect(
      find.descendant(
        of: _friendButton(userName),
        matching: find.text('Thêm bạn'),
      ),
      findsOneWidget,
    );

    await tester.tap(_friendButton(userName));
    await tester.pump();
    expect(
      find.descendant(
        of: _friendButton(userName),
        matching: find.text('Đang chờ'),
      ),
      findsOneWidget,
    );

    await tester.tap(_friendButton(userName));
    await tester.pump();
    expect(
      find.descendant(
        of: _friendButton(userName),
        matching: find.text('Bạn bè'),
      ),
      findsOneWidget,
    );

    // A confirmed friend button is disabled.
    expect(
      tester.widget<OutlinedButton>(_friendButton(userName)).enabled,
      isFalse,
    );
  });

  testWidgets('friend status survives searching', (tester) async {
    await _pumpFriends(tester);
    await tester.tap(_friendButton('Bảo Trâm'));
    await tester.pump();

    await _search(tester, 'trâm');
    await _search(tester, '');

    expect(
      find.descendant(
        of: _friendButton('Bảo Trâm'),
        matching: find.text('Đang chờ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the users it is given, not the mock list', (tester) async {
    final users = [currentUser, mockUsers[3]]; // Only Bảo Trâm besides you.
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(users: users, currentUser: currentUser),
      ),
    );

    expect(find.text('Bảo Trâm'), findsOneWidget);
    expect(find.text('Minh Ánh'), findsNothing);
    expect(find.text(currentUser.name), findsNothing);
  });

  testWidgets('sending friend requests does not change the users list', (
    tester,
  ) async {
    final users = List.of(mockUsers);
    final originalFriendFlags = [for (final user in users) user.isFriend];
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(users: users, currentUser: currentUser),
      ),
    );

    await tester.tap(_friendButton('Bảo Trâm'));
    await tester.pump();
    await tester.tap(_friendButton('Bảo Trâm'));
    await tester.pump();

    expect([for (final user in users) user.isFriend], originalFriendFlags);
  });
}
