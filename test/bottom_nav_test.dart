import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_learning/widgets/bottom_nav.dart';

Widget _buildNavigation({int unreadCount = 0, int selectedIndex = 0}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: SocialBottomNav(
        currentIndex: selectedIndex,
        unreadNotificationCount: unreadCount,
        onTap: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('bottom navigation exposes all destination semantics', (
    tester,
  ) async {
    await tester.pumpWidget(_buildNavigation());
    final semanticsHandle = tester.ensureSemantics();
    final semanticsText = tester
        .getSemantics(find.byType(NavigationBar))
        .toStringDeep();

    expect(find.byType(NavigationDestination), findsNWidgets(6));
    for (final label in SocialBottomNav.labels) {
      expect(semanticsText, contains(label));
    }
    semanticsHandle.dispose();
  });

  testWidgets('selected destination is exposed to accessibility tools', (
    tester,
  ) async {
    await tester.pumpWidget(_buildNavigation());
    final semanticsHandle = tester.ensureSemantics();

    final semanticsText = tester
        .getSemantics(find.byType(NavigationBar))
        .toStringDeep();
    expect(semanticsText, contains('isSelected'));
    semanticsHandle.dispose();
  });

  testWidgets('notification badge follows unread count', (tester) async {
    await tester.pumpWidget(_buildNavigation());
    final semanticsHandle = tester.ensureSemantics();
    expect(find.byType(Badge), findsNothing);

    await tester.pumpWidget(_buildNavigation(unreadCount: 3));
    expect(find.byType(Badge), findsOneWidget);
    final semanticsText = tester
        .getSemantics(find.byType(NavigationBar))
        .toStringDeep();
    expect(semanticsText, contains('Thông báo, 3 chưa đọc'));
    semanticsHandle.dispose();
  });

  testWidgets('tapping destinations reports each selected index', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: SocialBottomNav(
              currentIndex: selectedIndex,
              onTap: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    for (var index = 0; index < AppTab.values.length; index++) {
      await tester.tap(find.byKey(navDestinationKey(AppTab.values[index])));
      await tester.pump();
      expect(selectedIndex, index);
    }
  });

  testWidgets('inactive tabs are outlined and the selected tab is filled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildNavigation(selectedIndex: 1));

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsNothing);
  });
}
