import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final List<Conversation> conversations;
  final String conversationId;
  final UserModel currentUser;
  final void Function(String text, {List<String>? attachmentPaths})
  onSendMessage;

  /// Optional photo/file picker callback.
  final Future<String?> Function()? onPickAttachment;

  /// Whether the partner in this conversation is currently typing.
  final bool isPartnerTyping;

  /// Notifies the server that the current user is typing or stopped typing.
  final void Function(bool isTyping)? onTyping;

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
    this.onPickAttachment,
    this.isPartnerTyping = false,
    this.onTyping,
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
  final List<String> _pendingAttachmentPaths = [];
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

  Future<void> _pickAttachment() async {
    if (widget.onPickAttachment == null) return;
    final path = await widget.onPickAttachment!();
    if (path == null || !mounted) return;
    setState(() {
      if (_pendingAttachmentPaths.length < 5 &&
          !_pendingAttachmentPaths.contains(path)) {
        _pendingAttachmentPaths.add(path);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachmentPaths.isEmpty) return;

    final attachments = List<String>.from(_pendingAttachmentPaths);
    widget.onSendMessage(
      text,
      attachmentPaths: attachments.isEmpty ? null : attachments,
    );
    _messageController.clear();
    setState(() {
      _pendingAttachmentPaths.clear();
      _showEmojiBar = false;
    });
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
                    conversation.user.isOnline
                        ? 'Đang hoạt động'
                        : (conversation.user.lastSeenAt != null
                              ? 'Hoạt động ${conversation.user.lastSeenAt}'
                              : 'Đang ngoại tuyến'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: conversation.user.isOnline
                          ? palette.success
                          : palette.textSecondary,
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
              child: conversation.messages.isEmpty && !widget.isPartnerTyping
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
                      children: [
                        ...conversation.messages.map((message) {
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
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: isMine
                                  ? BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    )
                                  : AppDecorations.card(context),
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (message.attachments.isNotEmpty) ...[
                                    _buildAttachments(
                                      message.attachments,
                                      isMine,
                                    ),
                                    if (message.text.isNotEmpty)
                                      const SizedBox(height: 6),
                                  ],
                                  if (message.text.isNotEmpty)
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        // onPrimary stays readable in dark mode,
                                        // where primary is a light color.
                                        color: isMine
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (widget.isPartnerTyping)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: AppDecorations.card(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TypingDots(color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${conversation.user.name} đang soạn tin...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
            if (_pendingAttachmentPaths.isNotEmpty)
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: Theme.of(context).cardColor,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachmentPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final p = _pendingAttachmentPaths[i];
                    final name = p.split('/').last;
                    return Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              p.endsWith('.jpg') ||
                                  p.endsWith('.png') ||
                                  p.endsWith('.jpeg')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(p), fit: BoxFit.cover),
                                )
                              : Center(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => setState(
                              () => _pendingAttachmentPaths.removeAt(i),
                            ),
                            child: const CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
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
                  if (widget.onPickAttachment != null)
                    IconButton(
                      tooltip: 'Đính kèm tệp hoặc ảnh',
                      onPressed: _pickAttachment,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (text) {
                        widget.onTyping?.call(text.isNotEmpty);
                      },
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
                  const SizedBox(width: 8),
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

  Widget _buildAttachments(List<ChatAttachment> attachments, bool isMine) {
    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        for (final att in attachments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: att.isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: att.url.startsWith('http')
                        ? Image.network(
                            att.url,
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image),
                          )
                        : Image.file(
                            File(att.url),
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image),
                          ),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.15)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                att.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                att.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMine
                                      ? Colors.white70
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }
}

/// 3 jumping dots typing animation.
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final t = (_controller.value - (index * 0.2)) % 1.0;
            final offset =
                -4.0 * (t > 0 && t < 0.5 ? (1 - (t - 0.25).abs() * 4) : 0);
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
