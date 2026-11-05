import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_learning/data/chat_interactions.dart';
import 'package:flutter_learning/data/chat_stickers.dart';
import 'package:flutter_learning/models/chat_theme.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/utils/chat_search.dart';
import 'package:flutter_learning/utils/message_status.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/image_viewer.dart';
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

  /// Server only. Without them reactions, recalls and deletions are kept in
  /// this screen alone (the mock app).
  /// [emoji] null takes my reaction back.
  final Future<void> Function(String messageId, String? emoji)?
  onReactToMessage;
  final Future<void> Function(String messageId)? onRecallMessage;
  final Future<void> Function(String messageId)? onHideMessage;

  /// Pins a message for both people, or removes the pin (server only; without
  /// them the pin is kept in this screen alone, as in the mock app).
  final Future<void> Function(String messageId)? onPinMessage;
  final Future<void> Function()? onUnpinMessage;

  /// Sends a text to another conversation, for "Chuyển tiếp".
  final void Function(String conversationId, String text)? onSendMessageTo;

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
    this.onReactToMessage,
    this.onRecallMessage,
    this.onHideMessage,
    this.onSendMessageTo,
    this.onPinMessage,
    this.onUnpinMessage,
    this.isPartnerTyping = false,
    this.onTyping,
    this.refresh,
    this.embedded = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _pendingAttachmentPaths = [];
  int _shownMessageCount = 0;
  bool _showPicker = false;
  int _pickerTab = 0; // 0: Emojis, 1: Stickers
  String _selectedEmojiCategoryId = 'smileys';
  String _selectedStickerPackId = 'pack_animated_3d';

  // Reply / Quote state
  QuotedMessage? _replyingTo;

  // Reactions state: messageId -> { emoji: count }
  final Map<String, Map<String, int>> _messageReactions = {};
  // userReactions: messageId -> myEmoji
  final Map<String, String> _userReactions = {};

  // Unsent and deleted message tracking
  final Set<String> _unsentMessageIds = {};
  final Set<String> _deletedMessageIds = {};

  // In-chat search state
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentSearchMatchIndex = 0;

  // Pinned message state
  String? _pinnedMessageId;

  // Chat theme state
  String _chatThemeId = 'blue';

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
    _searchController.dispose();
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

  /// The server keeps the pin and the delivered / seen markers.
  bool get _serverState => widget.onPinMessage != null;

  String? _pinnedId(Conversation c) =>
      _serverState ? c.pinnedMessage?.id : _pinnedMessageId;

  Future<void> _togglePin(Conversation c, ChatMessage message) async {
    final unpin = _pinnedId(c) == message.id;
    if (_serverState) {
      await (unpin
          ? widget.onUnpinMessage!()
          : widget.onPinMessage!(message.id));
    } else {
      setState(() => _pinnedMessageId = unpin ? null : message.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          unpin
              ? 'Đã bỏ ghim tin nhắn'
              : (_serverState
                    ? 'Đã ghim tin nhắn cho cả hai người'
                    : 'Đã ghim tin nhắn lên đầu cuộc trò chuyện'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Ticks under one of my messages; the other person's small avatar marks
  /// the last one they have seen.
  Widget _sendStatus(
    ChatMessage message,
    Conversation conversation,
    String? lastSeenId,
    ColorScheme colorScheme,
    AppPalette palette,
  ) {
    final state = sendState(
      message.id,
      conversation.partnerDeliveredId,
      conversation.partnerReadId,
    );
    final grey = palette.textSecondary.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: switch (state) {
            SendState.sending => 'Đang gửi',
            SendState.sent => 'Đã gửi',
            SendState.delivered => 'Đã nhận',
            SendState.seen => 'Đã xem',
          },
          child: Icon(
            state == SendState.sending
                ? Icons.access_time_rounded
                : (state == SendState.sent
                      ? Icons.done_rounded
                      : Icons.done_all_rounded),
            size: 14,
            color: state == SendState.seen ? colorScheme.primary : grey,
          ),
        ),
        if (message.id == lastSeenId) ...[
          const SizedBox(width: 4),
          UserAvatar(imageUrl: conversation.user.avatarUrl, radius: 7),
          const SizedBox(width: 2),
          Text(
            'Đã xem',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  bool _isUnsent(ChatMessage m) =>
      m.isRecalled || _unsentMessageIds.contains(m.id);

  Map<String, int> _reactionsOf(ChatMessage m) =>
      widget.onReactToMessage != null
      ? m.reactions
      : (_messageReactions[m.id] ?? const {});

  String? _myReactionOf(ChatMessage m) =>
      widget.onReactToMessage != null ? m.myReaction : _userReactions[m.id];

  void _toggleReaction(String msgId, String emoji) {
    final onReact = widget.onReactToMessage;
    if (onReact != null) {
      final message = _conversation.messages
          .where((m) => m.id == msgId)
          .firstOrNull;
      // Choosing my own reaction again takes it back.
      onReact(msgId, message?.myReaction == emoji ? null : emoji);
      return;
    }
    setState(() {
      final currentMyRx = _userReactions[msgId];
      final rxMap = _messageReactions[msgId] ?? <String, int>{};

      if (currentMyRx == emoji) {
        // Remove reaction
        if ((rxMap[emoji] ?? 0) > 1) {
          rxMap[emoji] = rxMap[emoji]! - 1;
        } else {
          rxMap.remove(emoji);
        }
        _userReactions.remove(msgId);
      } else {
        // Change from previous emoji
        if (currentMyRx != null && (rxMap[currentMyRx] ?? 0) > 0) {
          if (rxMap[currentMyRx]! > 1) {
            rxMap[currentMyRx] = rxMap[currentMyRx]! - 1;
          } else {
            rxMap.remove(currentMyRx);
          }
        }
        rxMap[emoji] = (rxMap[emoji] ?? 0) + 1;
        _userReactions[msgId] = emoji;
      }
      _messageReactions[msgId] = rxMap;
    });
  }

  /// "Chuyển tiếp": the text goes to another conversation the person picks.
  void _forwardMessage(String text) {
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa thể chuyển tiếp ảnh hoặc tệp')),
      );
      return;
    }
    final others = widget.conversations
        .where((c) => c.id != widget.conversationId)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Chuyển tiếp tin nhắn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (others.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không có cuộc trò chuyện nào khác'),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in others)
                        ListTile(
                          leading: UserAvatar(
                            imageUrl: c.user.avatarUrl,
                            radius: 18,
                          ),
                          title: Text(c.user.name),
                          trailing: const Icon(Icons.send_rounded),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            widget.onSendMessageTo!(c.id, text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã chuyển tiếp cho ${c.user.name}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startReply(ChatMessage message, String senderName) {
    final parsed = parseChatMessageReply(message.text);
    final isSticker = parseStickerMessage(parsed.cleanText) != null;
    final snippet = isSticker
        ? '[Nhãn dán 3D]'
        : (parsed.cleanText.isNotEmpty
              ? parsed.cleanText
              : (message.attachments.isNotEmpty
                    ? '[Tệp tin/Ảnh]'
                    : 'Tin nhắn'));

    setState(() {
      _replyingTo = QuotedMessage(
        id: message.id,
        senderName: senderName,
        text: snippet,
      );
    });
  }

  void _showMessageActionSheet(
    BuildContext context,
    ChatMessage message,
    String senderName,
    bool isMine,
  ) {
    final parsed = parseChatMessageReply(message.text);
    final cleanText = parsed.cleanText;
    final colorScheme = Theme.of(context).colorScheme;
    final myRx = _myReactionOf(message);

    showModalBottomSheet<void>(
      context: context,
      // The sheet has a reaction bar and up to eight actions: let it grow and
      // scroll on a short screen instead of overflowing.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Reaction Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: kChatMessageReactions.map((emoji) {
                        final isSelected = myRx == emoji;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _toggleReaction(message.id, emoji);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.reply_rounded,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Trả lời tin nhắn'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startReply(message, senderName);
                  },
                ),
                if (cleanText.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: const Text('Sao chép văn bản'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Clipboard.setData(ClipboardData(text: cleanText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép tin nhắn'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: const Text('Chuyển tiếp'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (widget.onSendMessageTo != null) {
                      _forwardMessage(cleanText);
                      return;
                    }
                    if (cleanText.isNotEmpty) {
                      _messageController.text = cleanText;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã đưa nội dung vào ô soạn thảo để chuyển tiếp',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    _pinnedId(_conversation) == message.id
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: Colors.amber,
                  ),
                  title: Text(
                    _pinnedId(_conversation) == message.id
                        ? 'Bỏ ghim tin nhắn'
                        : 'Ghim tin nhắn',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _togglePin(_conversation, message);
                  },
                ),
                if (isMine)
                  ListTile(
                    leading: const Icon(
                      Icons.undo_rounded,
                      color: Colors.amber,
                    ),
                    title: const Text('Thu hồi tin nhắn'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      final onRecall = widget.onRecallMessage;
                      if (onRecall != null) {
                        onRecall(message.id);
                      } else {
                        setState(() {
                          _unsentMessageIds.add(message.id);
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã thu hồi tin nhắn'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Xóa ở phía tôi',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final onHide = widget.onHideMessage;
                    if (onHide != null) {
                      onHide(message.id);
                    } else {
                      setState(() {
                        _deletedMessageIds.add(message.id);
                      });
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa tin nhắn ở phía bạn'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachmentPaths.isEmpty) return;

    final attachments = List<String>.from(_pendingAttachmentPaths);
    final finalPayload = _replyingTo != null && text.isNotEmpty
        ? buildChatMessageReplyPayload(_replyingTo!, text)
        : text;

    widget.onSendMessage(
      finalPayload,
      attachmentPaths: attachments.isEmpty ? null : attachments,
    );
    _messageController.clear();
    setState(() {
      _pendingAttachmentPaths.clear();
      _showPicker = false;
      _replyingTo = null;
    });
  }

  void _sendSticker(StickerItem sticker) {
    var payload = '[sticker:${sticker.id}:${sticker.url}]';
    if (_replyingTo != null) {
      payload = buildChatMessageReplyPayload(_replyingTo!, payload);
    }
    widget.onSendMessage(payload);
    setState(() {
      _showPicker = false;
      _replyingTo = null;
    });
  }

  void _openSharedMediaSheet(BuildContext context) {
    final conversation = _conversation;
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);

    final mediaAttachments = <ChatAttachment>[];
    final fileAttachments = <ChatAttachment>[];

    for (final m in conversation.messages) {
      if (_deletedMessageIds.contains(m.id) ||
          _unsentMessageIds.contains(m.id)) {
        continue;
      }
      for (final att in m.attachments) {
        if (att.isImage) {
          mediaAttachments.add(att);
        } else {
          fileAttachments.add(att);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Thông tin hội thoại',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Center(
                            child: Column(
                              children: [
                                UserAvatar(
                                  imageUrl: conversation.user.avatarUrl,
                                  radius: 36,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  conversation.user.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  conversation.user.isOnline
                                      ? 'Đang trực tuyến'
                                      : (conversation.user.lastSeenAt != null
                                            ? 'Hoạt động ${conversation.user.lastSeenAt}'
                                            : 'Ngoại tuyến'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: conversation.user.isOnline
                                        ? palette.success
                                        : palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'CHỦ ĐỀ ĐOẠN CHAT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: ChatThemes.all.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, idx) {
                                final themeOption = ChatThemes.all[idx];
                                final isSelected =
                                    themeOption.id == _chatThemeId;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _chatThemeId = themeOption.id;
                                    });
                                    setSheetState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã đổi chủ đề sang ${themeOption.name}',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: themeOption.gradient,
                                          color: themeOption.primaryColor,
                                          border: isSelected
                                              ? Border.all(
                                                  color: colorScheme.onSurface,
                                                  width: 2.5,
                                                )
                                              : null,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: themeOption
                                                        .primaryColor
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        themeOption.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          TabBar(
                            labelColor: colorScheme.primary,
                            unselectedLabelColor: palette.textSecondary,
                            indicatorColor: colorScheme.primary,
                            tabs: [
                              Tab(
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 20,
                                ),
                                text: 'Ảnh (${mediaAttachments.length})',
                              ),
                              Tab(
                                icon: const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 20,
                                ),
                                text: 'Tài liệu (${fileAttachments.length})',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 320,
                            child: TabBarView(
                              children: [
                                mediaAttachments.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.photo_outlined,
                                              size: 48,
                                              color: palette.textSecondary
                                                  .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Chưa có ảnh nào được gửi',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        itemCount: mediaAttachments.length,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 6,
                                              mainAxisSpacing: 6,
                                            ),
                                        itemBuilder: (context, i) {
                                          final att = mediaAttachments[i];
                                          return GestureDetector(
                                            onTap: () => showImageViewer(
                                              context,
                                              att.url,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                att.url,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      color: palette.border,
                                                      child: const Icon(
                                                        Icons
                                                            .broken_image_rounded,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                fileAttachments.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.description_outlined,
                                              size: 48,
                                              color: palette.textSecondary
                                                  .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Chưa có tệp tài liệu nào',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: fileAttachments.length,
                                        itemBuilder: (context, i) {
                                          final att = fileAttachments[i];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.insert_drive_file_rounded,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            title: Text(
                                              att.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              att.formattedSize,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final conversation = _conversation;
    final selectedTheme = ChatThemes.findById(_chatThemeId);
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
        title: GestureDetector(
          onTap: () => _openSharedMediaSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Row(
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
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _showSearch ? 'Đóng tìm kiếm' : 'Tìm kiếm tin nhắn',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Thông tin hội thoại, chủ đề & tệp chia sẻ',
            onPressed: () => _openSharedMediaSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final visibleMessages = conversation.messages
                .where((m) => !_deletedMessageIds.contains(m.id))
                .toList();

            final matchingMessages = _searchQuery.isEmpty
                ? <ChatMessage>[]
                : visibleMessages
                      .where((m) => messageMatches(m, _searchQuery))
                      .toList();

            // The server sends the pinned message itself (it can be older than what is
            // loaded); the mock app pins one of the loaded messages.
            ChatMessage? pinnedMessage;
            if (_serverState) {
              pinnedMessage = conversation.pinnedMessage;
            } else if (_pinnedMessageId != null) {
              for (final m in visibleMessages) {
                if (m.id == _pinnedMessageId) {
                  pinnedMessage = m;
                  break;
                }
              }
            }

            final lastSeenId = lastSeenOfMine(
              visibleMessages,
              widget.currentUser.id,
              conversation.partnerReadId,
            );

            ChatMessage? lastMyMessage;
            for (final m in visibleMessages.reversed) {
              if (m.senderId == widget.currentUser.id && !_isUnsent(m)) {
                lastMyMessage = m;
                break;
              }
            }

            return Column(
              children: [
                if (_showSearch)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(
                        bottom: BorderSide(
                          color: palette.border.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                                _currentSearchMatchIndex = 0;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm tin nhắn...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          Text(
                            matchingMessages.isNotEmpty
                                ? '${_currentSearchMatchIndex + 1}/${matchingMessages.length}'
                                : '0/0',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 20,
                            ),
                            onPressed: matchingMessages.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _currentSearchMatchIndex =
                                          (_currentSearchMatchIndex -
                                              1 +
                                              matchingMessages.length) %
                                          matchingMessages.length;
                                    });
                                  },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),
                            onPressed: matchingMessages.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _currentSearchMatchIndex =
                                          (_currentSearchMatchIndex + 1) %
                                          matchingMessages.length;
                                    });
                                  },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _showSearch = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                if (pinnedMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.push_pin_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đang hiển thị tin nhắn đã ghim',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tin nhắn đã ghim (${pinnedMessage.senderId == widget.currentUser.id ? 'Bạn' : conversation.user.name})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                                Text(
                                  parseChatMessageReply(
                                        pinnedMessage.text,
                                      ).cleanText.isNotEmpty
                                      ? parseChatMessageReply(
                                          pinnedMessage.text,
                                        ).cleanText
                                      : 'Đính kèm tệp / Nhãn dán',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          tooltip: 'Bỏ ghim',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          onPressed: () =>
                              _togglePin(conversation, pinnedMessage!),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: visibleMessages.isEmpty && !widget.isPartnerTyping
                      ? Center(
                          child: Text(
                            'Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            ...visibleMessages.map((message) {
                              final isMine =
                                  message.senderId == widget.currentUser.id;
                              final senderName = isMine
                                  ? 'Chính bạn'
                                  : conversation.user.name;
                              final isUnsent = _isUnsent(message);
                              final myRx = _myReactionOf(message);
                              final rxMap = _reactionsOf(message);
                              final rxEntries = rxMap.entries
                                  .where((e) => e.value > 0)
                                  .toList();

                              if (isUnsent) {
                                return Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: palette.border.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.undo_rounded,
                                          size: 14,
                                          color: palette.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Tin nhắn đã được thu hồi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: palette.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final parsedReply = parseChatMessageReply(
                                message.text,
                              );
                              final parsedSticker = parseStickerMessage(
                                parsedReply.cleanText,
                              );
                              final sticker = parsedSticker == null
                                  ? null
                                  : findStickerById(parsedSticker.id);

                              final Widget messageBubble;

                              if (parsedSticker != null) {
                                messageBubble = Column(
                                  crossAxisAlignment: isMine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (parsedReply.replyTo != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: colorScheme.primary,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              parsedReply.replyTo!.senderName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            Text(
                                              parsedReply.replyTo!.text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: sticker == null
                                              ? const SizedBox(
                                                  width: 125,
                                                  height: 60,
                                                  child: Center(
                                                    child: Text('[Nhãn dán]'),
                                                  ),
                                                )
                                              : Image.network(
                                                  sticker.url,
                                                  width: 125,
                                                  height: 125,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(
                                                        Icons
                                                            .sentiment_satisfied_alt_rounded,
                                                        size: 48,
                                                      ),
                                                ),
                                        ),
                                        if (rxEntries.isNotEmpty)
                                          Positioned(
                                            bottom: -6,
                                            right: isMine ? 2 : null,
                                            left: isMine ? null : 2,
                                            child: InkWell(
                                              onTap: () => _toggleReaction(
                                                message.id,
                                                myRx ?? '❤️',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                                  border: Border.all(
                                                    color: palette.border,
                                                    width: 0.6,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ...rxEntries.map(
                                                      (e) => Text(
                                                        e.key,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${rxEntries.fold(0, (acc, e) => acc + e.value)}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: palette
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            message.time,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: palette.textSecondary
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          if (isMine && _serverState) ...[
                                            const SizedBox(width: 4),
                                            _sendStatus(
                                              message,
                                              conversation,
                                              lastSeenId,
                                              colorScheme,
                                              palette,
                                            ),
                                          ],
                                          if (isMine && !_serverState) ...[
                                            const SizedBox(width: 4),
                                            if (message.id ==
                                                lastMyMessage?.id) ...[
                                              if (conversation.user.isOnline)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    UserAvatar(
                                                      imageUrl: conversation
                                                          .user
                                                          .avatarUrl,
                                                      radius: 7,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      'Đã xem',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Icon(
                                                  Icons.done_all_rounded,
                                                  size: 14,
                                                  color: colorScheme.primary,
                                                ),
                                            ] else
                                              Icon(
                                                Icons.done_all_rounded,
                                                size: 14,
                                                color: palette.textSecondary
                                                    .withValues(alpha: 0.5),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                messageBubble = Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.75,
                                      ),
                                      decoration: isMine
                                          ? BoxDecoration(
                                              color: selectedTheme.primaryColor,
                                              gradient: selectedTheme.gradient,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.md,
                                                  ),
                                            )
                                          : AppDecorations.card(context),
                                      child: Column(
                                        crossAxisAlignment: isMine
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (parsedReply.replyTo != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isMine
                                                    ? Colors.white.withValues(
                                                        alpha: 0.18,
                                                      )
                                                    : colorScheme
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border(
                                                  left: BorderSide(
                                                    color: isMine
                                                        ? Colors.white
                                                        : colorScheme.primary,
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.reply_rounded,
                                                        size: 12,
                                                        color: isMine
                                                            ? Colors.white70
                                                            : colorScheme
                                                                  .primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        parsedReply
                                                            .replyTo!
                                                            .senderName,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isMine
                                                              ? Colors.white
                                                              : colorScheme
                                                                    .primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    parsedReply.replyTo!.text,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isMine
                                                          ? Colors.white70
                                                          : palette
                                                                .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (message
                                              .attachments
                                              .isNotEmpty) ...[
                                            _buildAttachments(
                                              message.attachments,
                                              isMine,
                                            ),
                                            if (parsedReply
                                                .cleanText
                                                .isNotEmpty)
                                              const SizedBox(height: 6),
                                          ],
                                          if (parsedReply.cleanText.isNotEmpty)
                                            Text(
                                              parsedReply.cleanText,
                                              style: TextStyle(
                                                color: isMine
                                                    ? colorScheme.onPrimary
                                                    : colorScheme.onSurface,
                                              ),
                                            ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                message.time,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMine
                                                      ? colorScheme.onPrimary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : palette.textSecondary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                ),
                                              ),
                                              if (isMine && _serverState) ...[
                                                const SizedBox(width: 4),
                                                _sendStatus(
                                                  message,
                                                  conversation,
                                                  lastSeenId,
                                                  colorScheme,
                                                  palette,
                                                ),
                                              ],
                                              if (isMine && !_serverState) ...[
                                                const SizedBox(width: 4),
                                                if (message.id ==
                                                    lastMyMessage?.id) ...[
                                                  if (conversation
                                                      .user
                                                      .isOnline)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        UserAvatar(
                                                          imageUrl: conversation
                                                              .user
                                                              .avatarUrl,
                                                          radius: 7,
                                                        ),
                                                        const SizedBox(
                                                          width: 2,
                                                        ),
                                                        Text(
                                                          'Đã xem',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: colorScheme
                                                                .onPrimary,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  else
                                                    Icon(
                                                      Icons.done_all_rounded,
                                                      size: 14,
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                                ] else
                                                  Icon(
                                                    Icons.done_all_rounded,
                                                    size: 14,
                                                    color: colorScheme.onPrimary
                                                        .withValues(alpha: 0.6),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (rxEntries.isNotEmpty)
                                      Positioned(
                                        bottom: -8,
                                        right: isMine ? 4 : null,
                                        left: isMine ? null : 4,
                                        child: InkWell(
                                          onTap: () => _toggleReaction(
                                            message.id,
                                            myRx ?? '❤️',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.12),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: palette.border,
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ...rxEntries.map(
                                                  (e) => Text(
                                                    e.key,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${rxEntries.fold(0, (acc, e) => acc + e.value)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        palette.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }

                              return Dismissible(
                                key: ValueKey('swipe_${message.id}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  _startReply(message, senderName);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Icon(
                                    Icons.reply_rounded,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                child: Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    child: GestureDetector(
                                      onLongPress: () =>
                                          _showMessageActionSheet(
                                            context,
                                            message,
                                            senderName,
                                            isMine,
                                          ),
                                      child: messageBubble,
                                    ),
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
                if (_showPicker) _buildPicker(context),
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
                                      child: Image.file(
                                        File(p),
                                        fit: BoxFit.cover,
                                      ),
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
                if (_replyingTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      border: Border(
                        top: BorderSide(color: palette.border, width: 0.5),
                        left: BorderSide(
                          color: colorScheme.primary,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Đang trả lời ${_replyingTo!.senderName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                              Text(
                                _replyingTo!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _replyingTo = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Hủy trả lời',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                      ],
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
                        tooltip: 'Chèn biểu tượng cảm xúc & nhãn dán',
                        onPressed: () =>
                            setState(() => _showPicker = !_showPicker),
                        icon: Icon(
                          _showPicker
                              ? Icons.keyboard_alt_outlined
                              : Icons.sentiment_satisfied_alt_rounded,
                          color: _showPicker
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
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
                        backgroundColor: selectedTheme.primaryColor,
                        foregroundColor: selectedTheme.textColor,
                        elevation: 0,
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);

    final currentEmojiCat = kEmojiCategories.firstWhere(
      (c) => c.id == _selectedEmojiCategoryId,
      orElse: () => kEmojiCategories.first,
    );

    final currentStickerPack = kStickerPacks.firstWhere(
      (p) => p.id == _selectedStickerPackId,
      orElse: () => kStickerPacks.first,
    );

    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: palette.border, width: 0.8)),
      ),
      child: Column(
        children: [
          // Top Segment Control: Emojis vs Stickers + Close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _pickerTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _pickerTab == 0
                                ? colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _pickerTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('😀', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Biểu tượng',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _pickerTab == 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _pickerTab == 0
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pickerTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _pickerTab == 1
                                ? colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _pickerTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                'Nhãn dán 3D',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _pickerTab == 1
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _pickerTab == 1
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Đóng',
                  onPressed: () => setState(() => _showPicker = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Body: Either Emoji list or Sticker packs list
          Expanded(
            child: _pickerTab == 0
                ? Column(
                    children: [
                      // Emoji Category Selector Row
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: kEmojiCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, idx) {
                            final cat = kEmojiCategories[idx];
                            final isSelected =
                                cat.id == _selectedEmojiCategoryId;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedEmojiCategoryId = cat.id,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.15,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cat.icon,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      // Emojis Grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: currentEmojiCat.emojis.length,
                          itemBuilder: (context, idx) {
                            final emoji = currentEmojiCat.emojis[idx];
                            return InkWell(
                              onTap: () => _insertEmoji(emoji),
                              borderRadius: BorderRadius.circular(10),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Sticker Packs Selector Row
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          itemCount: kStickerPacks.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final pack = kStickerPacks[idx];
                            final isSelected =
                                pack.id == _selectedStickerPackId;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedStickerPackId = pack.id,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.15,
                                        )
                                      : colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      pack.icon,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      pack.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      // Stickers Grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: currentStickerPack.stickers.length,
                          itemBuilder: (context, idx) {
                            final stk = currentStickerPack.stickers[idx];
                            return InkWell(
                              onTap: () => _sendSticker(stk),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Image.network(
                                      stk.url,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.sentiment_satisfied_alt_rounded,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stk.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyFileLink(ChatAttachment attachment) async {
    await Clipboard.setData(ClipboardData(text: attachment.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã sao chép liên kết tệp')));
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
                ? GestureDetector(
                    onTap: () => showImageViewer(context, att.url),
                    child: Semantics(
                      button: true,
                      label: 'Xem ảnh ${att.name}',
                      child: ClipRRect(
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
                      ),
                    ),
                  )
                : Semantics(
                    button: att.url.startsWith('http'),
                    label: 'Tệp ${att.name}, ${att.formattedSize}',
                    child: InkWell(
                      // Opening a file needs a package the project does not
                      // use yet, so tapping copies its link instead.
                      onTap: att.url.startsWith('http')
                          ? () => _copyFileLink(att)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
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
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 24,
                            ),
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
