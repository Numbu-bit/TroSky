@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/details_screen.dart';
import 'package:mobile/entry/auth/presentation/sign_in_screen.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:mobile/entry/auth/presentation/welcome_screen.dart';

import 'auth_helpers.dart';

/// S-04 to S-07 at 360 x 806, the TECNO BG6's logical size.
///
/// SVG icons decode off the test clock, hence runAsync; flutter_test draws
/// shadows unblurred unless `debugDisableShadows` is off. Emoji (🇬🇭, 🪪)
/// have no font in tests and show as empty space.
Future<void> _golden(WidgetTester tester, Type screen, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  debugDisableShadows = false;
  try {
    await expectLater(
      find.byType(screen),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('S-04 Welcome', (tester) async {
    await openWelcome(tester);
    await _golden(tester, WelcomeScreen, 'welcome');
  });

  testWidgets('S-05 Sign in', (tester) async {
    await openSignIn(tester);
    await _golden(tester, SignInScreen, 'sign_in');
  });

  testWidgets('S-06 Your details', (tester) async {
    await openDetails(tester);
    await enter(tester, 'At least 8 characters', 'Kumasi');
    FocusManager.instance.primaryFocus?.unfocus();
    await _golden(tester, DetailsScreen, 'details');
  });

  testWidgets('S-07 Code verification', (tester) async {
    await openDetails(tester);
    await submitDetails(tester);
    await enter(tester, '6-digit code', '123');
    await _golden(tester, VerifyCodeScreen, 'verify_code');
  });
}
