// Step 21/B2 fix: Language screen replaces the Profile "Coming soon"
// stub. Display-only today; English (en_GH) with a Current pill.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/presentation/language_screen.dart';

class _Tel implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

Widget _host(TelemetryService tel) => ProviderScope(
  overrides: [telemetryProvider.overrideWithValue(tel)],
  child: const MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('en')],
    home: LanguageScreen(),
  ),
);

void main() {
  testWidgets('Language screen renders English + Current pill', (tester) async {
    final tel = _Tel();
    await tester.pumpWidget(_host(tel));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('en_GH'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('More languages coming soon.'), findsOneWidget);
  });

  testWidgets('Language screen emits profile_language_opened', (tester) async {
    final tel = _Tel();
    await tester.pumpWidget(_host(tel));
    await tester.pumpAndSettle();
    expect(tel.events.any((e) => e.name == 'profile_language_opened'), isTrue);
  });
}
