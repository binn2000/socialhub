import 'package:flutter/material.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

/// The bottom navigation tabs, in display order. MainScreen's screen list and
/// the icons and labels below must follow this same order. Messages is opened
/// from Home and is not a tab.
enum AppTab { home, explore, friends, createPost, notifications, profile }

/// Key of a tab's destination, so tests can tap a tab without depending on
/// which icon (outlined or filled) it shows right now.
Key navDestinationKey(AppTab tab) => ValueKey('nav-${tab.name}');

class SocialBottomNav extends StatelessWidget {
  final int currentIndex;
  final int unreadNotificationCount;
  final ValueChanged<int> onTap;

  const SocialBottomNav({
    super.key,
    required this.currentIndex,
    this.unreadNotificationCount = 0,
    required this.onTap,
  });

  /// Outlined when not selected, filled when selected.
  static const icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.people_alt_outlined,
    Icons.add_rounded,
    Icons.notifications_none_rounded,
    Icons.person_outline_rounded,
  ];
  static const selectedIcons = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.people_alt_rounded,
    Icons.add_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];
  static const labels = [
    'Trang chủ',
    'Khám phá',
    'Bạn bè',
    'Tạo bài viết',
    'Thông báo',
    'Hồ sơ',
  ];

  Widget _buildIcon(AppPalette palette, AppTab tab, {required bool selected}) {
    final index = tab.index;
    final iconData = selected ? selectedIcons[index] : icons[index];
    if (tab == AppTab.createPost) {
      // The create button is the one brand-colored shape in the bar.
      return Container(
        width: 40,
        height: 32,
        decoration: BoxDecoration(
          color: palette.brand,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(iconData, color: Colors.white, size: 22),
      );
    }
    final icon = Icon(iconData);
    if (tab == AppTab.notifications && unreadNotificationCount > 0) {
      return Badge(label: Text('$unreadNotificationCount'), child: icon);
    }
    return icon;
  }

  NavigationDestination _buildDestination(AppPalette palette, AppTab tab) {
    final label = tab == AppTab.notifications && unreadNotificationCount > 0
        ? '${labels[tab.index]}, $unreadNotificationCount chưa đọc'
        : labels[tab.index];
    return NavigationDestination(
      key: navDestinationKey(tab),
      icon: Semantics(
        label: label,
        child: _buildIcon(palette, tab, selected: false),
      ),
      selectedIcon: Semantics(
        label: label,
        child: _buildIcon(palette, tab, selected: true),
      ),
      label: label,
      tooltip: labels[tab.index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border, width: 0.5)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        animationDuration: AppMotion.medium,
        // The create button carries its own shape, so the pill indicator is
        // hidden for it.
        indicatorColor: currentIndex == AppTab.createPost.index
            ? Colors.transparent
            : palette.brandSoft,
        destinations: [
          for (final tab in AppTab.values) _buildDestination(palette, tab),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
    );
  }
}
