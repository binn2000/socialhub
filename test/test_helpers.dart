import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/main.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';

// Bottom navigation tabs, in tab order.
const homeTab = AppTab.home;
const exploreTab = AppTab.explore;
const friendsTab = AppTab.friends;
const createTab = AppTab.createPost;
const notificationsTab = AppTab.notifications;
const profileTab = AppTab.profile;

Future<void> pumpSocialHub(WidgetTester tester) async {
  await tester.pumpWidget(const SocialHubApp());
  await tester.pumpAndSettle();
}

/// Taps a bottom navigation tab by its key (the icon changes between
/// outlined and filled, so it is not a stable thing to search for).
Future<void> tapTab(WidgetTester tester, AppTab tab) async {
  await tester.tap(find.byKey(navDestinationKey(tab)));
  await tester.pumpAndSettle();
}

Future<void> openMessagesFromHome(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.message_rounded));
  await tester.pumpAndSettle();
}

/// The vertical scroll view that is currently on screen.
Finder get visibleVerticalScrollable => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

// Home post menu ("...") helpers.

/// The "..." button on the Home card that shows [post].
Finder postMenuButton(Post post) => find.descendant(
  // The nearest Column around the post text is that post's card.
  of: find
      .ancestor(of: find.text(post.content), matching: find.byType(Column))
      .first,
  matching: find.byIcon(Icons.more_horiz_rounded),
);

Future<void> openPostMenu(WidgetTester tester, Post post) async {
  await tester.scrollUntilVisible(
    find.text(post.content),
    300,
    scrollable: visibleVerticalScrollable,
  );
  await tester.ensureVisible(postMenuButton(post));
  await tester.pumpAndSettle();
  await tester.tap(postMenuButton(post));
  await tester.pumpAndSettle();
}

Future<void> tapMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> closePostMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 20));
  await tester.pumpAndSettle();
}

Future<void> savePostFromMenu(WidgetTester tester, Post post) async {
  await openPostMenu(tester, post);
  await tapMenuItem(tester, 'Lưu bài viết');
}

Future<void> hidePostFromMenu(WidgetTester tester, Post post) async {
  await openPostMenu(tester, post);
  await tapMenuItem(tester, 'Ẩn bài viết');
}
