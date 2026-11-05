import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/data/mock_data.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/screens/chat_detail_screen.dart';
import 'package:flutter_learning/services/social_api.dart' show MediaPage;

void main() {
  final currentUser = mockUsers[0];
  final partner = mockUsers[1];

  const message = ChatMessage(
    id: 'msg_1',
    senderId: 'user_2',
    text: 'Xin chào',
    time: '10:00',
    attachments: [
      ChatAttachment(
        id: 'att_1',
        type: 'image',
        url: 'https://example.com/img1.jpg',
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 10240,
      ),
      ChatAttachment(
        id: 'att_2',
        type: 'file',
        url: 'https://example.com/doc.pdf',
        name: 'doc.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 20480,
      ),
    ],
  );

  final conversation = Conversation(
    id: 'conv_1',
    user: partner,
    lastMessage: 'Xin chào',
    time: '10:00',
    unreadCount: 0,
    messages: [message],
  );

  Widget screen({
    Conversation? chat,
    String theme = 'blue',
    ValueChanged<String>? onTheme,
    VoidCallback? onSearch,
    Future<MediaPage> Function({required bool images, String? cursor})? load,
    String? pinned,
  }) => MaterialApp(
    home: ChatDetailScreen(
      conversationOf: () => chat ?? conversation,
      currentUser: currentUser,
      themeIdOf: () => theme,
      pinnedIdOf: () => pinned,
      onThemeChanged: onTheme ?? (_) {},
      onOpenSearch: onSearch,
      loadMedia: load,
    ),
  );

  testWidgets('renders partner info, quick actions and the three tabs', (
    tester,
  ) async {
    var searchOpened = false;
    await tester.pumpWidget(screen(onSearch: () => searchOpened = true));

    expect(find.text('Chi tiết hội thoại'), findsOneWidget);
    expect(find.text(partner.name), findsOneWidget);
    expect(find.text('Tìm kiếm'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Ảnh (1)'), findsOneWidget);
    expect(find.text('File & Tệp (1)'), findsOneWidget);
    expect(find.textContaining('Đã ghim'), findsOneWidget);

    await tester.tap(find.text('Tìm kiếm'));
    await tester.pumpAndSettle();
    expect(searchOpened, isTrue);
  });

  testWidgets('a recalled message no longer lists its pictures and files', (
    tester,
  ) async {
    final recalled = Conversation(
      id: 'conv_1',
      user: partner,
      lastMessage: '',
      time: '10:00',
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: message.id,
          senderId: message.senderId,
          text: '',
          time: message.time,
          attachments: message.attachments,
          isRecalled: true,
        ),
      ],
    );
    await tester.pumpWidget(screen(chat: recalled));

    expect(find.text('Ảnh (0)'), findsOneWidget);
    expect(find.text('File & Tệp (0)'), findsOneWidget);
  });

  testWidgets('with a server the lists come from the media endpoint, paged', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      screen(
        // The loaded messages hold nothing: older pictures are only on the server.
        chat: Conversation(
          id: 'conv_1',
          user: partner,
          lastMessage: '',
          time: '',
          unreadCount: 0,
          messages: const [],
        ),
        load: ({required images, cursor}) async {
          requests.add('${images ? 'image' : 'file'}:${cursor ?? '-'}');
          if (!images) return const MediaPage();
          return const MediaPage(
            items: [
              ChatAttachment(
                id: '9',
                type: 'image',
                url: 'https://example.com/old.jpg',
                name: 'old.jpg',
                mimeType: 'image/jpeg',
                sizeBytes: 1,
              ),
            ],
            nextCursor: 'more',
          );
        },
      ),
    );
    await tester.pump();

    expect(requests, containsAll(['image:-', 'file:-']));
    // "1+" says there are more pages.
    expect(find.text('Ảnh (1+)'), findsOneWidget);
  });

  testWidgets('choosing a theme reports its id', (tester) async {
    String? chosen;
    await tester.pumpWidget(screen(onTheme: (id) => chosen = id));

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồng tím'));
    await tester.pumpAndSettle();

    expect(chosen, 'purple');
  });

  testWidgets('the pinned tab shows what was written, not the reply envelope', (
    tester,
  ) async {
    final pinnedChat = Conversation(
      id: 'conv_1',
      user: partner,
      lastMessage: '',
      time: '',
      unreadCount: 0,
      messages: const [
        ChatMessage(
          id: 'p1',
          senderId: 'user_2',
          text: '[reply:m0:Lan:Chào]\nHẹn 8 giờ nhé',
          time: '10:00',
        ),
      ],
    );
    await tester.pumpWidget(screen(chat: pinnedChat, pinned: 'p1'));

    await tester.tap(find.textContaining('Đã ghim'));
    await tester.pumpAndSettle();

    expect(find.text('Hẹn 8 giờ nhé'), findsOneWidget);
    expect(find.textContaining('[reply:'), findsNothing);
    // Nothing scrolls the chat to a message here, so there is no dead button.
    expect(find.text('Xem trong đoạn chat'), findsNothing);
  });
}
