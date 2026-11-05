import 'package:flutter/material.dart';
import 'package:flutter_learning/data/chat_stickers.dart';
import 'package:flutter_learning/data/quick_reactions.dart';

/// A sheet with the emojis the quick send button can use; returns the one
/// picked (null when closed).
Future<String?> showQuickReactionPicker(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _QuickReactionSheet(current: current),
  );
}

class _QuickReactionSheet extends StatefulWidget {
  final String current;

  const _QuickReactionSheet({required this.current});

  @override
  State<_QuickReactionSheet> createState() => _QuickReactionSheetState();
}

class _QuickReactionSheetState extends State<_QuickReactionSheet> {
  bool _showAll = false;
  int _selectedCategoryIndex = 0;
  late PageController _pageController;
  late final ScrollController _tabScrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedCategoryIndex);
    _tabScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedTab(int index) {
    if (!_tabScrollController.hasClients) return;
    final targetOffset = (index * 110.0) - 60.0;
    _tabScrollController.animateTo(
      targetOffset.clamp(0.0, _tabScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_showAll) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() => _showAll = false),
                      tooltip: 'Quay lại',
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tất cả biểu tượng cảm xúc',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Category Tab Selector (scrollable & auto-centered)
              SingleChildScrollView(
                controller: _tabScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < kEmojiCategories.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: _selectedCategoryIndex == i,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategoryIndex = i);
                              if (_pageController.hasClients) {
                                _pageController.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                              _scrollToSelectedTab(i);
                            }
                          },
                          avatar: Text(
                            kEmojiCategories[i].icon,
                            style: const TextStyle(fontSize: 16),
                          ),
                          label: Text(kEmojiCategories[i].name),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Swipable PageView for Emoji Grids
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (pageIndex) {
                    setState(() => _selectedCategoryIndex = pageIndex);
                    _scrollToSelectedTab(pageIndex);
                  },
                  itemCount: kEmojiCategories.length,
                  itemBuilder: (context, catIndex) {
                    final category = kEmojiCategories[catIndex];
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: category.emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = category.emojis[index];
                        final isCurrent = emoji == widget.current;
                        return InkWell(
                          onTap: () => Navigator.pop(context, emoji),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isCurrent
                                  ? colorScheme.primaryContainer
                                  : null,
                              border: isCurrent
                                  ? Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biểu tượng cảm xúc nhanh',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(widget.current, style: const TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Nút này thay nút gửi khi ô nhập trống. Cả hai người đều thấy.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emoji in kQuickReactions)
                  Semantics(
                    button: true,
                    selected: emoji == widget.current,
                    label: 'Dùng $emoji',
                    child: InkWell(
                      onTap: () => Navigator.pop(context, emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: emoji == widget.current
                              ? colorScheme.primaryContainer
                              : null,
                          border: emoji == widget.current
                              ? Border.all(color: colorScheme.primary)
                              : null,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  // A controller reattached later would restart at page 0.
                  _pageController.dispose();
                  _pageController = PageController(
                    initialPage: _selectedCategoryIndex,
                  );
                  _showAll = true;
                }),
                icon: const Icon(Icons.add_reaction_outlined, size: 20),
                label: const Text('Xem tất cả biểu tượng cảm xúc...'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
