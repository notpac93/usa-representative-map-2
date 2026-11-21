import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/services/landing_portrait_service.dart';
import 'package:usa_map_app/widgets/rotating_lawmaker_portraits.dart';

class _PortraitService extends LandingPortraitService {
  final portraits = List.generate(
    9,
    (i) => LandingPortrait(
      '$i',
      'Member $i',
      'assets/img/representatives/AK-nicholas-begich.jpg',
    ),
  );
  List<String> saved = [];
  @override
  Future<List<LandingPortrait>> loadPool() async => portraits;
  @override
  Future<List<String>> readPrevious() async => ['0', '1', '2'];
  @override
  Future<void> remember(List<LandingPortrait> portraits) async {
    saved = portraits.map((p) => p.id).toList();
  }
}

void main() {
  testWidgets(
    'crossfade keeps old portrait opaque until replacement is ready',
    (tester) async {
      final service = _PortraitService();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      await tester.runAsync(
        () => precacheImage(AssetImage(service.portraits.first.asset), context),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 176,
            child: RotatingLawmakerPortraits(service: service),
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(find.byType(Image), findsNWidgets(3));
      final initial = List<String>.of(service.saved);
      expect(initial.any(['0', '1', '2'].contains), isFalse);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(Image), findsNWidgets(4));
      final transition = tester.widget<FadeTransition>(
        find.byType(FadeTransition).last,
      );
      expect(transition.opacity.value, greaterThan(0));
      expect(transition.opacity.value, lessThan(1));
      expect(service.saved, initial);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(3));
      expect(service.saved, isNot(initial));
      expect(service.saved.toSet(), hasLength(3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capturing a tile freezes the current crossfade until return', (
    tester,
  ) async {
    final service = _PortraitService();
    final key = GlobalKey<RotatingLawmakerPortraitsState>();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => precacheImage(
        AssetImage(service.portraits.first.asset),
        tester.element(find.byType(SizedBox).first),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 176,
          child: RotatingLawmakerPortraits(key: key, service: service),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    final initial = List.of(service.saved);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    key.currentState!.pauseAndCapture();
    await tester.pump();
    final opacity = tester
        .widget<FadeTransition>(find.byType(FadeTransition).last)
        .opacity
        .value;
    await tester.pump(const Duration(seconds: 16));
    expect(service.saved, initial);
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).last)
          .opacity
          .value,
      opacity,
    );
    key.currentState!.resume();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(service.saved, isNot(initial));
    expect(find.byType(Image), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps startup selection still', (tester) async {
    final service = _PortraitService();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => precacheImage(
        AssetImage(service.portraits.first.asset),
        tester.element(find.byType(SizedBox).first),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            height: 176,
            child: RotatingLawmakerPortraits(service: service),
          ),
        ),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump();
    }
    final initial = List<String>.of(service.saved);
    expect(initial, hasLength(3));
    await tester.pump(const Duration(seconds: 24));
    expect(service.saved, initial);
    expect(
      find.descendant(
        of: find.byType(RotatingLawmakerPortraits),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
