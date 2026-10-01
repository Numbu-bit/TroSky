import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/debug/design_gallery.dart';
import 'package:trosky_ui/trosky_ui.dart';

void main() {
  testWidgets('the debug gallery builds every section', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: TroskyTheme.light(), home: const DesignGallery()),
    );
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
