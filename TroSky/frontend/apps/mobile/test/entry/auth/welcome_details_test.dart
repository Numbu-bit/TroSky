import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/details_screen.dart';
import 'package:mobile/entry/auth/presentation/sign_in_screen.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import 'auth_helpers.dart';

void main() {
  group('S-04 Welcome', () {
    testWidgets('an invalid or foreign number stays on Welcome', (
      tester,
    ) async {
      await openWelcome(tester);
      for (final phone in ['0241', '+44 7911 123456']) {
        await enter(tester, 'XX XXX XXXX', phone);
        await tapVisible(tester, find.text('Continue'));
        expect(find.text('Enter a valid Ghana phone number.'), findsOneWidget);
        expect(find.byType(DetailsScreen), findsNothing);
      }
    });

    testWidgets('any Ghana form continues to Your details', (tester) async {
      await openDetails(tester, phone: '+233 55 123 4567');
      expect(find.byType(DetailsScreen), findsOneWidget);
    });

    testWidgets('Continue with Email opens Sign in on email', (tester) async {
      await openWelcome(tester);
      await tapVisible(tester, find.text('Continue with Email'));
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
    });

    testWidgets('Already have an account opens Sign in', (tester) async {
      await openWelcome(tester);
      await tapVisible(tester, link('Already have an account?'));
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('the driver link switches the mode, and back', (tester) async {
      final world = await openWelcome(tester);
      await tapVisible(tester, link('Sign up as a driver'));
      expect(world.modes.mode, AppMode.driver);
      expect(link('Signing up as a driver.'), findsOneWidget);

      await tapVisible(tester, link('Sign up as a passenger instead'));
      expect(world.modes.mode, AppMode.passenger);
    });

    testWidgets('the country prefix lists Ghana only', (tester) async {
      await openWelcome(tester);
      await tester.tap(find.text('+233'));
      await tester.pumpAndSettle();
      expect(find.text('Ghana (+233)'), findsOneWidget);
      expect(find.text('TroSky is only in Ghana for now.'), findsOneWidget);
    });
  });

  group('S-06 Your details', () {
    testWidgets('checks the fields before calling the backend', (tester) async {
      final world = await openDetails(tester);
      await submitDetails(tester, name: 'E', email: 'efua', password: 'kumasi');

      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(
        find.text('Your password needs all four of these.'),
        findsOneWidget,
      );
      expect(world.backend.outbox, isEmpty);
    });

    testWidgets('a non-Gmail address is refused on the email field', (
      tester,
    ) async {
      await openDetails(tester);
      await submitDetails(tester, email: 'efua@yahoo.com');
      expect(
        find.text('Use your Gmail address (@gmail.com, @googlemail.com).'),
        findsOneWidget,
      );
    });

    testWidgets('an email in use is shown on the email field', (tester) async {
      await openDetails(tester);
      await submitDetails(tester, email: 'ama.mensah@gmail.com');
      expect(
        find.text('This email already has a TroSky account.'),
        findsOneWidget,
      );
    });

    testWidgets('a number in use offers Sign in with it filled in', (
      tester,
    ) async {
      await openDetails(tester, phone: '0241234567');
      await submitDetails(tester);
      expect(
        find.text('This number already has a TroSky account.'),
        findsOneWidget,
      );

      await tapVisible(tester, link('Sign in'));
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('024 123 4567'), findsOneWidget);
    });

    testWidgets('success sends the code and opens S-07', (tester) async {
      final world = await openDetails(tester);
      await submitDetails(tester);

      expect(find.byType(VerifyCodeScreen), findsOneWidget);
      expect(
        find.text('Code sent by text to +233 55 ••• ••67'),
        findsOneWidget,
      );
      expect(world.backend.outbox.first.to, '+233551234567');
    });

    testWidgets('the password checklist follows the typing', (tester) async {
      await openDetails(tester);
      await enter(tester, 'At least 8 characters', 'kumasi');
      bool met(String rule) {
        final items = tester
            .widget<TroskyChecklist>(find.byType(TroskyChecklist))
            .items;
        return items
            .firstWhere(
              (item) => item.$1 == rule,
              orElse: () => throw StateError('no "$rule" in $items'),
            )
            .$2;
      }

      expect(met('A lower-case letter'), isTrue);
      expect(met('An upper-case letter'), isFalse);

      // The hint is gone once typed in; the password is the last field.
      await tester.enterText(find.byType(TextField).last, 'Kumasi2026');
      await tester.pump();
      expect(met('An upper-case letter'), isTrue);
      expect(met('A number'), isTrue);
      expect(met('At least 8 characters'), isTrue);
    });

    testWidgets('a double tap registers once', (tester) async {
      final world = await openDetails(tester);
      await enter(tester, 'e.g. Ama Mensah', 'Efua Owusu');
      await enter(tester, 'you@gmail.com', 'efua.owusu@gmail.com');
      await enter(tester, 'At least 8 characters', 'Kumasi2026');
      final button = find.text('Create account');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();

      final registrations = world.backend.outbox.where(
        (c) => c.purpose == OtpPurpose.registration,
      );
      expect(registrations, hasLength(1));
    });
  });
}
