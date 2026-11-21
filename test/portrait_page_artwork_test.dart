import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/services/landing_portrait_service.dart';
import 'package:usa_map_app/widgets/portrait_page_artwork.dart';

void main() {
  final pool = List.generate(40, (i) => LandingPortrait(
    '$i', 'Member $i', 'assets/img/representatives/AK-nicholas-begich.jpg',
  ));
  Widget app({double expansion = 1, bool reduced = false, double inset = 0}) =>
      MaterialApp(home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced, viewInsets: EdgeInsets.only(bottom: inset)),
        child: SizedBox.expand(child: PortraitPageArtwork(
          pool: pool,
          expansion: expansion,
          portraits: const ColoredBox(key: Key('captured-trio'), color: Colors.red),
        )),
      ));
  Finder row(int i) => find.byKey(ValueKey('portrait-background-row-$i'));

  testWidgets('captured trio expands into rows covering the full screen', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(expansion: 0));
    expect(tester.getRect(row(0)), const Rect.fromLTWH(0, 0, 430, 932));
    final captured = tester.element(find.byKey(const Key('captured-trio')));
    await tester.pumpWidget(app());
    expect(identical(captured, tester.element(find.byKey(const Key('captured-trio')))), isTrue);
    expect(tester.getRect(row(0)).height, lessThan(240));
    final last = find.byType(RepaintBoundary).evaluate().where((e) =>
        e.widget.key.toString().contains('portrait-background-row-')).last;
    expect(tester.getRect(find.byElementPredicate((e) => identical(e, last))).bottom, greaterThanOrEqualTo(932));
    final initial = tester.getTopLeft(row(1));
    final portraitOrder = tester.widgetList<Image>(find.byType(Image))
        .map((image) => image.key).toList();
    expect(portraitOrder.toSet().length, portraitOrder.length);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 8));
    expect(tester.getTopLeft(row(1)), isNot(initial));
    for (var i = 0; i < 5; i++) {
      final bounds = tester.getRect(row(i));
      expect(bounds.left, lessThanOrEqualTo(0));
      expect(bounds.right, greaterThanOrEqualTo(430));
    }
    await tester.pumpWidget(app(inset: 340));
    expect(tester.widgetList<Image>(find.byType(Image))
        .map((image) => image.key).toList(), portraitOrder);
    final paused = tester.getTopLeft(row(1));
    await tester.pump(const Duration(seconds: 10));
    expect(tester.getTopLeft(row(1)), paused);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reduce Motion keeps the full portrait background still', (tester) async {
    await tester.pumpWidget(app(reduced: true));
    final start = tester.getTopLeft(row(1));
    await tester.pump(const Duration(seconds: 20));
    expect(tester.getTopLeft(row(1)), start);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
