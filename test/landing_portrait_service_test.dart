import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usa_map_app/services/landing_portrait_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pool = List.generate(
    12,
    (i) => LandingPortrait('$i', 'Member $i', '$i.jpg'),
  );

  test('startup excludes the previous trio across repeated launches', () async {
    SharedPreferences.setMockInitialValues({
      LandingPortraitService.preferenceKey: ['0', '1', '2'],
    });
    for (int launch = 0; launch < 30; launch++) {
      final service = LandingPortraitService();
      final previous = await service.readPrevious();
      final selection = LandingPortraitService.choose(
        pool,
        previous,
        random: Random(launch),
      );
      expect(selection, hasLength(3));
      expect(selection.map((p) => p.id).toSet(), hasLength(3));
      expect(selection.any((p) => previous.contains(p.id)), isFalse);
      await service.remember(selection);
      expect(
        await LandingPortraitService().readPrevious(),
        selection.map((p) => p.id).toList(),
      );
    }
  });

  test('small or empty pools never duplicate or crash', () {
    expect(LandingPortraitService.choose([], []), isEmpty);
    expect(
      LandingPortraitService.choose(pool.take(2).toList(), ['0', '1']),
      hasLength(2),
    );
    expect(LandingPortraitService.choose([pool[0], pool[0]], []), hasLength(1));
  });

  test(
    'roster-backed portrait pool uses bundled images and unique members',
    () async {
      final portraits = await LandingPortraitService().loadPool();
      expect(portraits.length, greaterThan(100));
      expect(portraits.map((p) => p.id).toSet().length, portraits.length);
      expect(portraits.every((p) => p.asset.startsWith('assets/img/')), isTrue);
    },
  );
}
