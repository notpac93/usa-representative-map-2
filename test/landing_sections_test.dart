import 'dart:convert';
import 'dart:io';
import 'package:usa_map_app/data/federal_officials.dart';
import 'package:usa_map_app/services/federal_officials_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/widgets/congress_scroll_section.dart';
import 'package:usa_map_app/widgets/executive_section_card.dart';
import 'package:usa_map_app/widgets/judicial_section_card.dart';

void main() {
  setUp(() {
    final registry = jsonDecode(
      File('assets/data/federal_sources.json').readAsStringSync(),
    );
    final sources = (registry['sources'] as List)
        .map((x) => FederalSource.fromJson(x))
        .toList();
    FederalOfficialsService.instance.snapshot = FederalSnapshot.decode(
      File('assets/data/federal_officials.json').readAsStringSync(),
      sources,
    );
  });
  group('LandingScreen 3-Branch Federal Dashboard Tests', () {
    testWidgets(
      'Mobile home exposes verified federal records without side sections',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => MapDataProvider(),
            child: const MaterialApp(home: LandingScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Your Representatives'), findsOneWidget);
        expect(
          find.byKey(const Key('federal_officials_directory_mobile')),
          findsOneWidget,
        );
        expect(find.text('Find My Reps'), findsOneWidget);
        expect(find.byType(CongressScrollSection), findsNothing);
        expect(find.byType(ExecutiveSectionCard), findsNothing);
        expect(find.byType(JudicialSectionCard), findsNothing);
      },
    );

    testWidgets(
      'Desktop / iPad view (>= 950px) renders firm Congress, Executive, and Judicial sections',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => MapDataProvider(),
            child: const MaterialApp(home: LandingScreen()),
          ),
        );
        await tester.pump();

        // Core search exists
        expect(find.text('Find Your Representatives'), findsOneWidget);
        expect(
          find.byKey(const Key('landing-contact-congress-button')),
          findsOneWidget,
        );

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
        expect(find.textContaining('Leadership'), findsOneWidget);
        expect(find.text('Mike Johnson'), findsWidgets);
      },
    );

    testWidgets('Congress scroll section edge buttons maneuver scroll offset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find maneuver right (forward) button
      final forwardBtn = find.byTooltip('Scroll right');
      expect(forwardBtn, findsOneWidget);

      await tester.tap(forwardBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Find maneuver left (backward) button
      final backwardBtn = find.byTooltip('Scroll left');
      expect(backwardBtn, findsOneWidget);

      await tester.tap(backwardBtn);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets(
      'iPad landscape view (1024x768) renders edge-docked sections cleanly without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => MapDataProvider(),
            child: const MaterialApp(home: LandingScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CongressScrollSection), findsOneWidget);
        expect(find.byType(ExecutiveSectionCard), findsOneWidget);
        expect(find.byType(JudicialSectionCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Tapping Donald J. Trump opens PresidentDetailScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final trumpCard = find.text('Donald J. Trump');
      expect(trumpCard, findsOneWidget);

      await tester.tap(trumpCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining('President of the United States'),
        findsWidgets,
      );
    });

    testWidgets(
      'Tapping the vice president opens the verified serving profile',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => MapDataProvider(),
            child: const MaterialApp(home: LandingScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final vanceCard = find.text('JD Vance');
        expect(vanceCard, findsOneWidget);

        await tester.tap(vanceCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Vice President of the United States · United States'),
          findsOneWidget,
        );
        expect(find.text('Serving now'), findsOneWidget);
        expect(
          find.text('Official sources and service history'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping a Supreme Court Justice opens their LawmakerDetailScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => MapDataProvider(),
            child: const MaterialApp(home: LandingScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final robertsCard = find.text('Roberts');
        expect(robertsCard, findsOneWidget);

        await tester.tap(robertsCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('John G. Roberts Jr.'), findsWidgets);
        expect(find.textContaining('Chief Justice'), findsWidgets);
      },
    );
  });
}
