import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/screens/find_reps_screen.dart';

void main() {
  for (final background in [false, true]) {
    testWidgets(
      'search retains focus and text through keyboard changes ($background)',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(home: FindRepsScreen(imageBackground: background)),
        );
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Find My Reps'),
          ),
          findsNothing,
        );
        expect(find.byKey(const Key('finder-page-title')), findsOneWidget);
        final original = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        await tester.enterText(find.byType(TextField), '926');
        for (final inset in [100.0, 250.0, 340.0, 0.0, 340.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();
          final current = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          expect(identical(original, current), isTrue);
          expect(current.widget.focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.hasAnyClients, isTrue);
          expect(current.widget.controller.text, '926');
        }
        await tester.enterText(find.byType(TextField), '92688');
        expect(find.text('92688'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
