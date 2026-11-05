import 'package:flutter/material.dart';
import 'package:flutter_learning/data/chat_stickers.dart';
import 'package:flutter_learning/models/chat_theme.dart';
import 'package:flutter_learning/models/message.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/services/social_api.dart'
    show ApiException, MediaPage;
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/image_viewer.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Conversation details: the person, the bubble theme, and every picture, file
/// and the pinned message of the chat.
///
/// This is a separate route, so it cannot see the chat's state by itself: it
/// reads the current values through [conversationOf] / [themeIdOf] and rebuilds
/// when [refresh] fires (polling, a theme change, a recall).
class ChatDetailScreen extends StatefulWidget {
  final Conversation Function() conversationOf;
  final UserModel currentUser;
  final String Function() themeIdOf;
  final String? Function() pinnedIdOf;

  /// Mock app only: messages the chat hid or took back in its own state. With a
  /// server the messages say it themselves (`isRecalled`).
  final Set<String> deletedMessageIds;
  final Set<String> unsentMessageIds;
  final ValueChanged<String> onThemeChanged;
  final Listenable? refresh;

  /// Server only: pages of all pictures / files. Without it the lists are built
  /// from the messages that are loaded (the mock app).
  final Future<MediaPage> Function({required bool images, String? cursor})?
  loadMedia;
  final VoidCallback? onOpenSearch;

  /// Scrolls the chat to a message. The button is hidden when it is null.
  final ValueChanged<String>? onJumpToMessage;

  const ChatDetailScreen({
    super.key,
    required this.conversationOf,
    required this.currentUser,
    required this.themeIdOf,
    required this.pinnedIdOf,
    this.deletedMessageIds = const {},
    this.unsentMessageIds = const {},
    required this.onThemeChanged,
    this.refresh,
    this.loadMedia,
    this.onOpenSearch,
    this.onJumpToMessage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _MediaList {
  List<ChatAttachment> items = [];
  String? next;
  bool loading = false;
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _images = _MediaList();
  final _files = _MediaList();
  final _rebuild = ValueNotifier<int>(0);
  String _signature = '';

  Conversation get _conversation => widget.conversationOf();

  /// Changes when a picture or file arrives or a message is recalled.
  String _signatureOf(Conversation c) => [
    for (final m in c.messages)
      if (m.isRecalled || m.attachments.isNotEmpty)
        '${m.id}${m.isRecalled ? 'r' : ''}',
  ].join(',');

  @override
  void initState() {
    super.initState();
    _signature = _signatureOf(_conversation);
    widget.refresh?.addListener(_onRefresh);
    if (widget.loadMedia != null) {
      _loadFirst(images: true);
      _loadFirst(images: false);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onRefresh);
    _rebuild.dispose();
    super.dispose();
  }

  void _onRefresh() {
    final signature = _signatureOf(_conversation);
    if (signature != _signature && widget.loadMedia != null) {
      _signature = signature;
      _loadFirst(images: true);
      _loadFirst(images: false);
    }
    _rebuild.value++;
  }

  Future<void> _loadFirst({required bool images}) async {
    final list = images ? _images : _files;
    try {
      final page = await widget.loadMedia!(images: images);
      if (!mounted) return;
      list.items = page.items;
      list.next = page.nextCursor;
    } on ApiException {
      // Keep what is shown; the next change tries again.
    }
    if (mounted) _rebuild.value++;
  }

  Future<void> _loadMore({required bool images}) async {
    final list = images ? _images : _files;
    if (list.next == null || list.loading) return;
    list.loading = true;
    _rebuild.value++;
    try {
      final page = await widget.loadMedia!(images: images, cursor: list.next);
      if (!mounted) return;
      list.items = [...list.items, ...page.items];
      list.next = page.nextCursor;
    } on ApiException {
      // The button stays, so the person can try again.
    }
    list.loading = false;
    if (mounted) _rebuild.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rebuild,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final conversation = _conversation;
    final partner = conversation.user;
    final themeId = widget.themeIdOf();
    final pinnedId = widget.pinnedIdOf();

    var mediaAttachments = _images.items;
    var fileAttachments = _files.items;
    ChatMessage? pinnedMessage;

    for (final m in conversation.messages) {
      if (m.id == pinnedId && !m.isRecalled) pinnedMessage = m;
    }
    // The pin as the server sends it, when that message is not loaded.
    pinnedMessage ??= conversation.pinnedMessage;

    if (widget.loadMedia == null) {
      // Mock app: only what is loaded, minus what the chat hid or took back.
      mediaAttachments = [];
      fileAttachments = [];
      for (final m in conversation.messages) {
        if (m.isRecalled ||
            widget.deletedMessageIds.contains(m.id) ||
            widget.unsentMessageIds.contains(m.id)) {
          continue;
        }
        for (final att in m.attachments) {
          (att.isImage ? mediaAttachments : fileAttachments).add(att);
        }
      }
      if (pinnedMessage != null &&
          (widget.deletedMessageIds.contains(pinnedMessage.id) ||
              widget.unsentMessageIds.contains(pinnedMessage.id))) {
        pinnedMessage = null;
      }
    }
    String count(_MediaList list, List<ChatAttachment> shown) =>
        '${shown.length}${widget.loadMedia != null && list.next != null ? '+' : ''}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chi tiết hội thoại',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // 1. Partner Profile Card (Always fixed on top, never scrolled away)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    UserAvatar(imageUrl: partner.avatarUrl, radius: 34),
                    const SizedBox(height: 8),
                    Text(
                      partner.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partner.isOnline
                          ? 'Đang hoạt động'
                          : (partner.lastSeenAt != null
                                ? 'Hoạt động ${partner.lastSeenAt}'
                                : 'Đang ngoại tuyến'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: partner.isOnline
                            ? palette.success
                            : palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildQuickAction(
                          context,
                          icon: Icons.search_rounded,
                          label: 'Tìm kiếm',
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenSearch?.call();
                          },
                        ),
                        const SizedBox(width: 24),
                        _buildQuickAction(
                          context,
                          icon: Icons.palette_outlined,
                          label: 'Chủ đề',
                          onTap: () {
                            _showThemePickerDialog(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // 2. Chat Theme Preview Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.color_lens_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Chủ đề: ${ChatThemes.findById(themeId).name}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ChatThemes.all.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final themeOption = ChatThemes.all[idx];
                            final isSelected = themeOption.id == themeId;
                            return GestureDetector(
                              onTap: () {
                                widget.onThemeChanged(themeOption.id);
                                _rebuild.value++;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã đổi chủ đề sang ${themeOption.name}',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: themeOption.gradient,
                                  color: themeOption.primaryColor,
                                  border: isSelected
                                      ? Border.all(
                                          color: colorScheme.onSurface,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 3. Pinned TabBar (Fixed header for media tabs, never scrolls away)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(color: palette.border, width: 0.6),
                  ),
                ),
                child: TabBar(
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: palette.textSecondary,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: [
                    Tab(text: 'Ảnh (${count(_images, mediaAttachments)})'),
                    Tab(text: 'File & Tệp (${count(_files, fileAttachments)})'),
                    Tab(text: 'Đã ghim (${pinnedMessage != null ? 1 : 0})'),
                  ],
                ),
              ),

              // 4. TabBarView for Media Content (Full screen scrolling space)
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Photos & Videos 3-Column Grid
                    mediaAttachments.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.photo_library_outlined,
                            title: 'Chưa có ảnh nào',
                            subtitle:
                                'Ảnh được chia sẻ trong đoạn chat này sẽ xuất hiện tại đây.',
                            palette: palette,
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (widget.loadMedia != null &&
                                  n.metrics.extentAfter < 300) {
                                _loadMore(images: true);
                              }
                              return false;
                            },
                            child: GridView.builder(
                              padding: const EdgeInsets.all(4),
                              itemCount: mediaAttachments.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 3,
                                    mainAxisSpacing: 3,
                                  ),
                              itemBuilder: (context, idx) {
                                final att = mediaAttachments[idx];
                                return GestureDetector(
                                  onTap: () =>
                                      showImageViewer(context, att.url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      att.url,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: palette.border
                                                    .withValues(alpha: 0.5),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image_rounded,
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    // Tab 2: Files & Documents List
                    fileAttachments.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.insert_drive_file_outlined,
                            title: 'Chưa có tệp tài liệu nào',
                            subtitle:
                                'Tài liệu và tệp tin gửi trong đoạn chat sẽ được lưu tại đây.',
                            palette: palette,
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (widget.loadMedia != null &&
                                  n.metrics.extentAfter < 300) {
                                _loadMore(images: false);
                              }
                              return false;
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: fileAttachments.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: palette.border, height: 1),
                              itemBuilder: (context, idx) {
                                final att = fileAttachments[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    att.formattedSize,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    // Tab 3: Pinned Message Tab
                    pinnedMessage == null
                        ? _buildEmptyState(
                            icon: Icons.push_pin_outlined,
                            title: 'Chưa có tin nhắn được ghim',
                            subtitle:
                                'Nhấn giữ tin nhắn bất kỳ để ghim lên đầu cuộc trò chuyện.',
                            palette: palette,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.push_pin_rounded,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Tin nhắn đang ghim',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        formatMessagePreview(
                                              pinnedMessage.text,
                                            ).isNotEmpty
                                            ? formatMessagePreview(
                                                pinnedMessage.text,
                                              )
                                            : '[Tệp tin đính kèm]',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (widget.onJumpToMessage != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              widget.onJumpToMessage?.call(
                                                pinnedMessage!.id,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Xem trong đoạn chat',
                                            ),
                                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppPalette palette,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 54,
              color: palette.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn chủ đề cuộc trò chuyện',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...ChatThemes.all.map((t) {
                    final isSelected = t.id == widget.themeIdOf();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: t.gradient,
                          color: t.primaryColor,
                        ),
                      ),
                      title: Text(
                        t.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        widget.onThemeChanged(t.id);
                        _rebuild.value++;
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
