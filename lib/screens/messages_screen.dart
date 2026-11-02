import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/music_track.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/models/user_note.dart';
import 'package:flutter_learning/screens/chat_screen.dart';
import 'package:flutter_learning/services/audio_preview.dart';
import 'package:flutter_learning/services/social_api.dart' show ApiException;
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/notes_row.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Width threshold at which Messenger switches to a 2-column Desktop layout
/// (conversation sidebar on the left + active chat on the right).
const double kDesktopMessengerBreakpoint = 900;

class MessagesScreen extends StatefulWidget {
  final List<Conversation> conversations;
  final Future<void> Function(Conversation) onOpenConversation;

  /// Notifies when [conversations] changed behind this screen's back (the
  /// list was polled). Null on the mock app.
  final Listenable? refresh;

  /// Friends the user can start a chat with. With [onStartConversation] it
  /// adds the "Tin nhắn mới" button; both are null on the mock app.
  final List<UserModel> Function()? friends;
  final Future<void> Function(UserModel friend)? onStartConversation;

  /// Searches conversations on the server by the other person's name or
  /// username, which also finds old ones that were not loaded. The results
  /// are added to [conversations]. Null on the mock app.
  final Future<List<Conversation>> Function(String query)?
  onSearchConversations;

  /// The notes row above the conversations: the notes to show (the list is
  /// updated in place, like [conversations]), how to share or remove mine.
  /// All null on the mock app, which has no notes.
  final List<UserNote>? notes;
  final Future<void> Function(String text, MusicTrack? track, String privacy)?
  onSetNote;
  final Future<void> Function()? onDeleteNote;

  /// Finding and previewing songs for notes (server only).
  final Future<List<MusicTrack>> Function(String query)? onSearchMusic;
  final AudioPreview audio;

  /// Used by the 2-column Desktop chat pane.
  final UserModel? currentUser;
  final void Function(
    String conversationId,
    String text, {
    List<String>? attachmentPaths,
  })?
  onSendMessage;
  final ValueChanged<Conversation>? onSelectDesktopConversation;
  final Future<String?> Function()? onPickAttachment;
  final void Function(bool typing)? onTyping;

  const MessagesScreen({
    super.key,
    required this.conversations,
    required this.onOpenConversation,
    this.refresh,
    this.friends,
    this.onStartConversation,
    this.onSearchConversations,
    this.notes,
    this.onSetNote,
    this.onDeleteNote,
    this.onSearchMusic,
    this.audio = const NoAudioPreview(),
    this.currentUser,
    this.onSendMessage,
    this.onSelectDesktopConversation,
    this.onPickAttachment,
    this.onTyping,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedConversationId;

  // Server search (only with onSearchConversations).
  Timer? _debounce;
  List<Conversation> _serverMatches = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_onConversationsChanged);
    if (widget.conversations.isNotEmpty) {
      _selectedConversationId = widget.conversations.first.id;
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onConversationsChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  void _onQueryChanged(String value) {
    setState(() => _searchQuery = value);
    if (widget.onSearchConversations == null) return;

    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _serverMatches = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), _searchOnServer);
  }

  Future<void> _searchOnServer() async {
    final query = _searchQuery.trim();
    try {
      final found = await widget.onSearchConversations!(query);
      // A newer search replaced this one while it was running.
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _serverMatches = found;
        _searching = false;
        _searchError = null;
      });
    } on ApiException catch (error) {
      if (!mounted || _searchQuery.trim() != query) return;
      setState(() {
        _searching = false;
        _searchError = error.displayMessage;
      });
    }
  }

  /// The loaded conversations that match (name or last message), plus the
  /// ones the server found by name or username that were not loaded.
  List<Conversation> get _filteredConversations {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return widget.conversations;
    final local = widget.conversations
        .where(
          (c) =>
              c.user.name.toLowerCase().contains(q) ||
              c.lastMessage.toLowerCase().contains(q),
        )
        .toList();
    final known = {for (final c in local) c.id};
    return [
      ...local,
      for (final c in _serverMatches)
        if (!known.contains(c.id)) c,
    ];
  }

  Future<void> _openConversation(
    Conversation conversation, {
    required bool isDesktop,
  }) async {
    if (isDesktop &&
        widget.currentUser != null &&
        widget.onSendMessage != null) {
      setState(() => _selectedConversationId = conversation.id);
      widget.onSelectDesktopConversation?.call(conversation);
      return;
    }
    await widget.onOpenConversation(conversation);
    if (mounted) setState(() {});
  }

  Future<void> _pickFriend() async {
    final friend = await showModalBottomSheet<UserModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final friends = widget.friends!();
        return SafeArea(
          child: friends.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Bạn chưa có bạn bè để nhắn tin'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final friend in friends)
                      ListTile(
                        leading: UserAvatar(
                          imageUrl: friend.avatarUrl,
                          radius: 20,
                        ),
                        title: Text(friend.name),
                        onTap: () => Navigator.pop(sheetContext, friend),
                      ),
                  ],
                ),
        );
      },
    );
    if (friend == null || !mounted) return;
    await widget.onStartConversation!(friend);
    if (mounted) setState(() {});
  }

  Widget _buildConversationList(
    BuildContext context, {
    required bool isDesktop,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredConversations;

    return Column(
      children: [
        if (widget.notes != null &&
            widget.onSetNote != null &&
            widget.onDeleteNote != null &&
            widget.currentUser != null &&
            widget.onStartConversation != null)
          NotesRow(
            notes: widget.notes!,
            currentUser: widget.currentUser!,
            onSetNote: widget.onSetNote!,
            onDeleteNote: widget.onDeleteNote!,
            onReply: widget.onStartConversation!,
            searchMusic: widget.onSearchMusic,
            audio: widget.audio,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm cuộc trò chuyện',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm hội thoại',
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
        ),
        if (_searching && filtered.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: _searching
                      ? const CircularProgressIndicator()
                      : Text(
                          _searchError ?? 'Không tìm thấy cuộc trò chuyện',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    final isSelected =
                        isDesktop && conversation.id == _selectedConversationId;
                    return Semantics(
                      button: true,
                      label:
                          'Mở cuộc trò chuyện với ${conversation.user.name}, ${conversation.lastMessage}',
                      child: PressableScale(
                        onTap: () => _openConversation(
                          conversation,
                          isDesktop: isDesktop,
                        ),
                        child: HoverableCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          borderColor: isSelected ? colorScheme.primary : null,
                          child: Row(
                            children: [
                              UserAvatar(
                                imageUrl: conversation.user.avatarUrl,
                                radius: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.user.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          conversation.time,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      conversation.lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (conversation.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    conversation.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= kDesktopMessengerBreakpoint &&
        widget.currentUser != null &&
        widget.onSendMessage != null;
    final activeId =
        _selectedConversationId ??
        (widget.conversations.isNotEmpty
            ? widget.conversations.first.id
            : null);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (widget.onStartConversation != null)
            IconButton(
              tooltip: 'Tin nhắn mới',
              onPressed: _pickFriend,
              icon: const Icon(Icons.edit_square),
            ),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: palette.border),
                        ),
                      ),
                      child: _buildConversationList(context, isDesktop: true),
                    ),
                  ),
                  Expanded(
                    child: activeId == null || widget.conversations.isEmpty
                        ? Center(
                            child: Text(
                              'Chọn một cuộc trò chuyện để bắt đầu',
                              style: TextStyle(color: palette.textSecondary),
                            ),
                          )
                        : ChatScreen(
                            key: ValueKey(activeId),
                            conversations: widget.conversations,
                            conversationId: activeId,
                            currentUser: widget.currentUser!,
                            onSendMessage: (text, {attachmentPaths}) =>
                                widget.onSendMessage!(
                                  activeId,
                                  text,
                                  attachmentPaths: attachmentPaths,
                                ),
                            onPickAttachment: widget.onPickAttachment,
                            onTyping: widget.onTyping,
                            refresh: widget.refresh,
                            embedded: true,
                          ),
                  ),
                ],
              )
            : _buildConversationList(context, isDesktop: false),
      ),
    );
  }
}
