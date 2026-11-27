// A11y test for Step 21/B F-1: the "Can't scan? Copy reference"
// IconButton exposes an accessible label for TalkBack / VoiceOver.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/trips/presentation/ticket_screen.dart';

void main() {
  testWidgets(
    'a11y: ticket copy-reference IconButton exposes a semantic label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(body: cantScanExpanderForTest('TRK-TEST-42')),
        ),
      );
      await tester.pumpAndSettle();
      // Expand to reveal the copy row.
      await tester.tap(find.text("Can't scan? Show code"));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Copy booking reference'), findsOneWidget);
    },
  );
}
