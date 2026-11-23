import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/screens/find_reps_screen.dart';
import 'package:usa_map_app/services/landing_portrait_service.dart';
import 'package:usa_map_app/widgets/portrait_page_artwork.dart';

void main() {
  final pool = List.generate(
    40,
    (i) => LandingPortrait(
      '$i',
      'Member $i',
      'assets/img/representatives/AK-nicholas-begich.jpg',
    ),
  );
  Widget app({
    double expansion = 1,
    bool reduced = false,
    double inset = 0,
    bool finder = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduced,
        viewInsets: EdgeInsets.only(bottom: inset),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PortraitPageArtwork(
            pool: pool,
            expansion: expansion,
            portraits: const ColoredBox(
              key: Key('captured-trio'),
              color: Colors.red,
            ),
          ),
          if (finder) const FindRepsScreen(imageBackground: true),
        ],
      ),
    ),
  );
  Finder row(int i) => find.byKey(ValueKey('portrait-background-row-$i'));
  List<Key?> order(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.key)
      .toList();
  Future<void> warmPortrait(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(
      () => precacheImage(
        ResizeImage.resizeIfNeeded(360, null, AssetImage(pool.first.asset)),
        tester.element(find.byType(SizedBox).first),
      ),
    );
  }

  testWidgets('captured trio expands into a mosaic that drifts while typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(expansion: 0));
    expect(tester.getRect(row(0)), const Rect.fromLTWH(0, 0, 430, 932));
    final captured = tester.element(find.byKey(const Key('captured-trio')));
    await tester.pumpWidget(app());
    expect(
      identical(
        captured,
        tester.element(find.byKey(const Key('captured-trio'))),
      ),
      isTrue,
    );
    expect(tester.getRect(row(0)).height, lessThan(240));
    expect(tester.getRect(row(4)).bottom, greaterThanOrEqualTo(932));
    final initial = tester.getTopLeft(row(1));
    final portraits = order(tester);
    expect(portraits.toSet().length, portraits.length);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(row(1)), isNot(initial));
    await tester.pumpWidget(app(inset: 340));
    expect(order(tester), portraits);
    final typingPosition = tester.getTopLeft(row(1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(row(1)), isNot(typingPosition));
    for (var i = 0; i < 5; i++) {
      final bounds = tester.getRect(row(i));
      expect(bounds.left, lessThanOrEqualTo(0));
      expect(bounds.right, greaterThanOrEqualTo(430));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('portrait replacements preserve the centered search and typing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await warmPortrait(tester);
    await tester.pumpWidget(app(inset: 340, finder: true));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '926');
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final panel = find.byKey(const ValueKey('location-search-panel'));
    final center = tester.getCenter(panel);
    final portraits = order(tester);
    expect(tester.getRect(panel).bottom, lessThan(932 - 340));
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 900));
    // The captured row remains underneath the incoming photos until the fade ends.
    expect(find.byKey(const Key('captured-trio')), findsOneWidget);
    expect(order(tester), isNot(portraits));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('captured-trio')), findsNothing);
    final refreshed = order(tester);
    expect(refreshed.toSet().length, refreshed.length);
    expect(tester.getCenter(panel), center);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      editable,
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);
    expect(editable.widget.controller.text, '926');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motion keeps both drift and portrait changes still', (
    tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    final start = tester.getTopLeft(row(1));
    final portraits = order(tester);
    await tester.pump(const Duration(seconds: 24));
    expect(tester.getTopLeft(row(1)), start);
    expect(order(tester), portraits);
    expect(find.byKey(const Key('captured-trio')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
