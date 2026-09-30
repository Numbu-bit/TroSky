import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

int _activeDot(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

Widget _dots({bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: LoadingDots(
        step: Duration(milliseconds: 500),
        semanticsLabel: 'Loading',
      ),
    ),
  ),
);

void main() {
  testWidgets('the white dot steps 1 → 2 → 3 and starts over', (tester) async {
    await tester.pumpWidget(_dots());
    expect(_activeDot(tester), 0);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_activeDot(tester), 1);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_activeDot(tester), 2);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_activeDot(tester), 0);
  });

  testWidgets('reduce motion keeps the first dot white', (tester) async {
    await tester.pumpWidget(_dots(reduceMotion: true));

    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(_activeDot(tester), 0);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('turning reduce motion on mid-cycle stops the dots', (
    tester,
  ) async {
    await tester.pumpWidget(_dots());
    await tester.pump(const Duration(milliseconds: 600));
    expect(_activeDot(tester), 1);

    await tester.pumpWidget(_dots(reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_activeDot(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('screen readers hear the label, not page numbers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_dots());

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Page')), findsNothing);
    semantics.dispose();
  });
}
