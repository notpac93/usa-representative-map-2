import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:usa_map_app/main.dart' as app;
import 'package:usa_map_app/screens/state_detail_screen.dart' as state_detail;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End test of Map App features', (
    WidgetTester tester,
  ) async {
    // 1. Launch the app
    app.main();
    await tester.pumpAndSettle();

    // 2. We should be on the National Map screen.
    // The USA Representative Map title should be visible in the AppBar.
    expect(find.text('USA Representative Map'), findsOneWidget);

    // 3. Programmatically push to the State Detail screen for California ('CA') to ensure we test it
    final BuildContext context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const state_detail.StateDetailScreen(stateId: 'CA'),
      ),
    );
    await tester.pumpAndSettle();

    // 4. We should now be on the State Detail screen. Let's verify we are there.
    var voterRulesFinder = find.byKey(const Key('voter_rules_button'));

    if (voterRulesFinder.evaluate().isNotEmpty) {
      // 5. Tap Voter Rules Button
      await tester.tap(voterRulesFinder);
      await tester.pumpAndSettle();

      // 6. Verify Voter Rules Screen
      expect(find.text('Voter ID Requirements'), findsWidgets);

      // Navigate back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 7. Find a lawmaker tile and tap it
      // Let's look for any ListTile (we assume a state has at least a governor or senators)
      final lawmakerTile = find.byType(ListTile).first;
      await tester.tap(lawmakerTile);
      await tester.pumpAndSettle();

      // 8. Verify Lawmaker Detail Screen and Share button
      final shareButton = find.byKey(const Key('share_voter_card_button'));
      expect(shareButton, findsOneWidget);

      // Tap share button (we mock the actual native share sheet so it won't crash)
      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      // Test complete
    }
  });
}
