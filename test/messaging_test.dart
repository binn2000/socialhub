import 'package:flutter/material.dart';
import 'package:flutter_learning/data/chat_stickers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/main.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/screens/chat_screen.dart';

Future<void> _openMessages(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.message_rounded).first);
  await tester.pumpAndSettle();
  expect(find.text('Tin nhắn'), findsOneWidget);
}

Future<void> _openConversation(
  WidgetTester tester,
  String participantName,
) async {
  await tester.tap(find.text(participantName).first);
  await tester.pumpAndSettle();
}

Future<void> _returnToMessages(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening an unread conversation marks it as read', (
    tester,
  ) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);

    expect(find.text('2'), findsOneWidget);
    await _openConversation(tester, 'Minh Ánh');
    await _returnToMessages(tester);

    expect(find.text('2'), findsNothing);
  });

  testWidgets('opening a read conversation does not create unread state', (
    tester,
  ) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);

    await _openConversation(tester, 'Duy Khang');
    await _returnToMessages(tester);

    expect(
      find.text('Cậu có muốn tham gia buổi review sáng mai không?'),
      findsOneWidget,
    );
    expect(find.text('0'), findsNothing);
  });

  testWidgets('sending updates the correct conversation preview', (
    tester,
  ) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    await _openConversation(tester, 'Minh Ánh');

    const messageText = 'Tin nhắn mới trong cuộc trò chuyện';
    await tester.enterText(find.byType(TextField), messageText);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text(messageText), findsOneWidget);
    await _returnToMessages(tester);

    expect(find.text(messageText), findsOneWidget);
    await _openConversation(tester, 'Minh Ánh');
    expect(find.text(messageText), findsOneWidget);
  });

  testWidgets('messages remain isolated between conversations', (tester) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    await _openConversation(tester, 'Minh Ánh');

    const messageText = 'Chỉ thuộc cuộc trò chuyện đầu tiên';
    await tester.enterText(find.byType(TextField), messageText);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await _returnToMessages(tester);

    await _openConversation(tester, 'Duy Khang');
    expect(find.text(messageText), findsNothing);
  });

  testWidgets('empty messages are ignored', (tester) async {
    var sendCount = 0;
    final emptyConversation = Conversation(
      id: 'empty',
      user: mockUsers[1],
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          conversations: [emptyConversation],
          conversationId: emptyConversation.id,
          currentUser: currentUser,
          onSendMessage: (_, {attachmentPaths}) => sendCount++,
        ),
      ),
    );

    // Only spaces: still nothing to send, so the 👍 button stays.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(sendCount, 0);
    expect(
      find.text('Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện.'),
      findsOneWidget,
    );
  });

  testWidgets('a long press on the quick button chooses another emoji', (
    tester,
  ) async {
    final sent = <String>[];
    final chat = Conversation(
      id: 'c',
      user: mockUsers[1],
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          conversations: [chat],
          conversationId: chat.id,
          currentUser: currentUser,
          onSendMessage: (text, {attachmentPaths}) => sent.add(text),
        ),
      ),
    );

    await tester.longPress(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'));
    await tester.pumpAndSettle();
    expect(find.text('Biểu tượng cảm xúc nhanh'), findsOneWidget);
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();

    expect(
      find.text('Đã đổi biểu tượng cảm xúc nhanh thành 🔥'),
      findsOneWidget,
    );
    // The message covers the input bar for a moment.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gửi 🔥 (giữ để đổi biểu tượng)'));
    await tester.pump();
    expect(sent, ['🔥']);
  });

  testWidgets(
    'a long press allows choosing from all emojis beyond the presets',
    (tester) async {
      final sent = <String>[];
      final chat = Conversation(
        id: 'c',
        user: mockUsers[1],
        lastMessage: '',
        time: '',
        unreadCount: 0,
        messages: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversations: [chat],
            conversationId: chat.id,
            currentUser: currentUser,
            onSendMessage: (text, {attachmentPaths}) => sent.add(text),
          ),
        ),
      );

      await tester.longPress(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'));
      await tester.pumpAndSettle();
      expect(find.text('Xem tất cả biểu tượng cảm xúc...'), findsOneWidget);
      await tester.tap(find.text('Xem tất cả biểu tượng cảm xúc...'));
      await tester.pumpAndSettle();
      expect(find.text('Tất cả biểu tượng cảm xúc'), findsOneWidget);

      // Pick an emoji from the full list, e.g. '😁'
      await tester.tap(find.text('😁'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đã đổi biểu tượng cảm xúc nhanh thành 😁'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi 😁 (giữ để đổi biểu tượng)'));
      await tester.pump();
      expect(sent, ['😁']);
    },
  );

  testWidgets('the emoji categories of the quick picker can be swiped', (
    tester,
  ) async {
    final chat = Conversation(
      id: 'c',
      user: mockUsers[1],
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          conversations: [chat],
          conversationId: chat.id,
          currentUser: currentUser,
          onSendMessage: (text, {attachmentPaths}) {},
        ),
      ),
    );

    Future<void> openAll() async {
      await tester.tap(find.text('Xem tất cả biểu tượng cảm xúc...'));
      await tester.pumpAndSettle();
    }

    await tester.longPress(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'));
    await tester.pumpAndSettle();
    await openAll();
    final second = kEmojiCategories[1].emojis.first;
    expect(find.text(second), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(second), findsWidgets);

    // Back to the presets and again: the grid must match the selected chip.
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await openAll();
    expect(find.text(second), findsWidgets);
  });

  testWidgets('the emoji categories of the message picker can be swiped', (
    tester,
  ) async {
    final chat = Conversation(
      id: 'c',
      user: mockUsers[1],
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          conversations: [chat],
          conversationId: chat.id,
          currentUser: currentUser,
          onSendMessage: (text, {attachmentPaths}) {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Chèn biểu tượng cảm xúc & nhãn dán'));
    await tester.pumpAndSettle();
    final second = kEmojiCategories[1].emojis.first;
    expect(find.text(second), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(second), findsWidgets);
  });

  testWidgets('an empty box offers a quick 👍 instead of the send button', (
    tester,
  ) async {
    final sent = <String>[];
    final chat = Conversation(
      id: 'c',
      user: mockUsers[1],
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          conversations: [chat],
          conversationId: chat.id,
          currentUser: currentUser,
          onSendMessage: (text, {attachmentPaths}) => sent.add(text),
        ),
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsNothing);
    await tester.tap(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'));
    await tester.pump();
    expect(sent, ['👍']);

    // Writing something brings the send button back.
    await tester.enterText(find.byType(TextField), 'Chào');
    await tester.pump();
    expect(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'), findsNothing);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, ['👍', 'Chào']);
    expect(find.byTooltip('Gửi 👍 (giữ để đổi biểu tượng)'), findsOneWidget);
  });

  testWidgets('sending updates the conversation time', (tester) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    expect(find.text('10:42'), findsOneWidget);

    await _openConversation(tester, 'Minh Ánh');
    await tester.enterText(find.byType(TextField), 'Cập nhật giờ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await _returnToMessages(tester);

    expect(find.text('10:42'), findsNothing);
    expect(find.text('Vừa xong'), findsOneWidget);
  });

  testWidgets('sending leaves other conversations unchanged', (tester) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    await _openConversation(tester, 'Minh Ánh');

    await tester.enterText(find.byType(TextField), 'Chỉ cho Minh Ánh');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await _returnToMessages(tester);

    for (final conversation in mockConversations.skip(1)) {
      expect(find.text(conversation.lastMessage), findsOneWidget);
      expect(find.text(conversation.time), findsOneWidget);
    }
    // Bảo Trâm's unread badge is untouched.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('whitespace-only message is ignored in the app', (tester) async {
    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    await _openConversation(tester, 'Duy Khang');

    await tester.enterText(find.byType(TextField), '    ');
    await tester.pump();
    // Spaces are nothing to send: the send button is not even offered.
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _returnToMessages(tester);

    expect(
      find.text('Cậu có muốn tham gia buổi review sáng mai không?'),
      findsOneWidget,
    );
    expect(find.text('Vừa xong'), findsNothing);
  });

  testWidgets('chatting does not modify mockConversations', (tester) async {
    final original = mockConversations.first;

    await tester.pumpWidget(const SocialHubApp());
    await _openMessages(tester);
    await _openConversation(tester, 'Minh Ánh');
    await tester.enterText(find.byType(TextField), 'Không đổi dữ liệu mock');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(mockConversations.first, same(original));
    expect(mockConversations.first.unreadCount, 2);
    expect(mockConversations.first.messages, hasLength(3));
  });
}
