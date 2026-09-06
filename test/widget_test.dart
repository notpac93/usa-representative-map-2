// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:usa_map_app/main.dart';

void main() {
  testWidgets('Landing screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UsaMapApp());
    await tester.pumpAndSettle();

    // Verify that the landing screen renders title and buttons
    expect(find.text('Find Your Representatives'), findsOneWidget);
    expect(find.text('Executive Branch'), findsOneWidget);
    expect(find.text('Explore National Map'), findsOneWidget);
  });
}
