import 'package:flutter/material.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final List<Conversation> conversations;
  final String conversationId;
  final UserModel currentUser;
  final ValueChanged<String> onSendMessage;

  /// Notifies when [conversations] changed behind this screen's back (new
  /// messages arriving by polling). Null on the mock app.
  final Listenable? refresh;

  /// True when rendered inside the right pane of the desktop Messenger view
  /// (hides the back arrow).
  final bool embedded;

  const ChatScreen({
    super.key,
    required this.conversations,
    required this.conversationId,
    required this.currentUser,
    required this.onSendMessage,
    this.refresh,
    this.embedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _quickEmojis = ['😊', '❤️', '👍', '🎉', '🔥', '😂', '👏', '✨'];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _shownMessageCount = 0;
  bool _showEmojiBar = false;

  Conversation get _conversation => widget.conversations.firstWhere(
    (conversation) => conversation.id == widget.conversationId,
    orElse: () => widget.conversations.first,
  );

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_onConversationsChanged);
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onConversationsChanged);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  /// Keeps the newest message in view when messages are added.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    _messageController.value = TextEditingValue(
      text: '$text$emoji',
      selection: TextSelection.collapsed(offset: text.length + emoji.length),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text);
    _messageController.clear();
    setState(() => _showEmojiBar = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final conversation = _conversation;
    if (conversation.messages.length != _shownMessageCount) {
      _shownMessageCount = conversation.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Quay lại danh sách tin nhắn',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Row(
          children: [
            UserAvatar(imageUrl: conversation.user.avatarUrl, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Đang hoạt động',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: palette.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: conversation.messages.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: conversation.messages.map((message) {
                        final isMine =
                            message.senderId == widget.currentUser.id;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: isMine
                                ? BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  )
                                : AppDecorations.card(context),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                // onPrimary stays readable in dark mode,
                                // where primary is a light color.
                                color: isMine
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (_showEmojiBar)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    top: BorderSide(color: palette.border, width: 0.5),
                  ),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final emoji in _quickEmojis)
                      InkWell(
                        onTap: () => _insertEmoji(emoji),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: palette.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Chèn biểu tượng cảm xúc',
                    onPressed: () =>
                        setState(() => _showEmojiBar = !_showEmojiBar),
                    icon: Icon(
                      _showEmojiBar
                          ? Icons.keyboard_alt_outlined
                          : Icons.sentiment_satisfied_alt_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Nhắn tin...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    onPressed: _sendMessage,
                    tooltip: 'Gửi tin nhắn',
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
