import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('the debug gallery opens and builds every section', (
    tester,
  ) async {
    await tester.pumpWidget(const TroskyMobileApp());
    await tester.tap(find.text('Design gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buttons'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gallery-motion')),
      800,
      // The first Scrollable is the page; the backdrop row scrolls sideways.
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('gallery-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Motion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
