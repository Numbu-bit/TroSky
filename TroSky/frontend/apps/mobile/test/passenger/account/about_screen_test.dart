// Step 21/B2 fix: About screen replaces the Profile "Coming soon"
// stub. Shows tagline + version + Terms/Privacy/Licenses rows.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/account/presentation/about_screen.dart';

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
    home: AboutScreen(),
  ),
);

void main() {
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
          if (call.method == 'getAll') {
            return {
              'appName': 'TroSky',
              'packageName': 'com.trosky.app',
              'version': '0.2.0',
              'buildNumber': '42',
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  testWidgets('About screen shows tagline + rows', (tester) async {
    final tel = _Tel();
    await tester.pumpWidget(_host(tel));
    await tester.pumpAndSettle();
    expect(find.text('About TroSky'), findsOneWidget);
    expect(
      find.text('Ghanaian shared transport, one tap away.'),
      findsOneWidget,
    );
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);
  });

  testWidgets('About screen emits profile_about_opened', (tester) async {
    final tel = _Tel();
    await tester.pumpWidget(_host(tel));
    await tester.pumpAndSettle();
    expect(tel.events.any((e) => e.name == 'profile_about_opened'), isTrue);
  });

  testWidgets('Licenses row opens licenses + emits analytics', (tester) async {
    final tel = _Tel();
    await tester.pumpWidget(_host(tel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open-source licenses'));
    await tester.pump();
    expect(tel.events.any((e) => e.name == 'about_licenses_tapped'), isTrue);
  });
}
