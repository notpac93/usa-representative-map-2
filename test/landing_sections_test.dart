import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/widgets/congress_scroll_section.dart';
import 'package:usa_map_app/widgets/executive_section_card.dart';
import 'package:usa_map_app/widgets/judicial_section_card.dart';

void main() {
  group('LandingScreen 3-Branch Federal Dashboard Tests', () {
    testWidgets('Mobile view (< 950px) renders clean centered search without side sections',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Find Your Representatives'), findsOneWidget);
      expect(find.byType(CongressScrollSection), findsNothing);
      expect(find.byType(ExecutiveSectionCard), findsNothing);
      expect(find.byType(JudicialSectionCard), findsNothing);
    });

    testWidgets('Desktop / iPad view (>= 950px) renders firm Congress, Executive, and Judicial sections',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );
      await tester.pump();

      // Core search exists
      expect(find.text('Find Your Representatives'), findsOneWidget);

      // Firm sections exist
      expect(find.byType(CongressScrollSection), findsOneWidget);
      expect(find.byType(ExecutiveSectionCard), findsOneWidget);
      expect(find.byType(JudicialSectionCard), findsOneWidget);

      // Executive content
      expect(find.text('Executive Branch'), findsWidgets);
      expect(find.text('Donald J. Trump'), findsOneWidget);
      expect(find.text('JD Vance'), findsOneWidget);

      // Judicial content
      expect(find.text('Judicial Branch'), findsWidgets);
      expect(find.text('Roberts'), findsOneWidget);
      expect(find.text('Thomas'), findsOneWidget);

      // Congress content
      expect(find.text('Congress'), findsOneWidget);
      expect(find.text('Leadership'), findsOneWidget);
      expect(find.text('Mike Johnson'), findsWidgets);
    });

    testWidgets('Congress scroll section edge buttons maneuver scroll offset',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find maneuver down (forward) button
      final forwardBtn = find.byIcon(Icons.keyboard_arrow_down);
      expect(forwardBtn, findsOneWidget);

      await tester.tap(forwardBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Find maneuver up (backward) button
      final backwardBtn = find.byIcon(Icons.keyboard_arrow_up);
      expect(backwardBtn, findsOneWidget);

      await tester.tap(backwardBtn);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('iPad landscape view (1024x768) renders edge-docked sections cleanly without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CongressScrollSection), findsOneWidget);
      expect(find.byType(ExecutiveSectionCard), findsOneWidget);
      expect(find.byType(JudicialSectionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
