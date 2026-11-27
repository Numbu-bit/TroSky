// Preferences tab (step 21/close-stubs-C):
//  - 7 toggles are rendered + 2 always-on indicators (Safety, Account).
//  - Each toggle PATCHes the right backend field.
//  - A 5xx server response reverts the optimistic toggle.
//  - The old "Coming soon" channel-only banner is gone.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/notifications/presentation/notifications_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeUser implements UserRepository {
  _FakeUser({NotificationPreferencesResponse? prefs})
    : _prefs =
          prefs ??
          const NotificationPreferencesResponse(
            pushEnabled: true,
            smsEnabled: true,
            emailEnabled: true,
            bookingUpdatesEnabled: true,
            paymentEnabled: true,
            promotionsEnabled: false,
            promotionalOptIn: false,
          );

  NotificationPreferencesResponse _prefs;
  bool shouldFail = false;
  final List<NotificationPreferencesUpdateRequest> patches = [];

  @override
  Future<Result<NotificationPreferencesResponse>>
  notificationPreferences() async => Ok(_prefs);

  @override
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
  ) async {
    patches.add(request);
    if (shouldFail) {
      return const Err(ServerFailure(code: 'INTERNAL', message: 'x'));
    }
    _prefs = NotificationPreferencesResponse(
      pushEnabled: request.pushEnabled ?? _prefs.pushEnabled,
      smsEnabled: request.smsEnabled ?? _prefs.smsEnabled,
      emailEnabled: request.emailEnabled ?? _prefs.emailEnabled,
      bookingUpdatesEnabled:
          request.bookingUpdatesEnabled ?? _prefs.bookingUpdatesEnabled,
      paymentEnabled: request.paymentEnabled ?? _prefs.paymentEnabled,
      promotionsEnabled: request.promotionsEnabled ?? _prefs.promotionsEnabled,
      promotionalOptIn: request.promotionalOptIn ?? _prefs.promotionalOptIn,
    );
    return Ok(_prefs);
  }

  // Unused in these tests.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(UserRepository repo) => ProviderScope(
  overrides: [userRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('en')],
    home: NotificationsScreen(),
  ),
);

Future<void> _openPrefs(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preferences'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Preferences tab shows channels + categories; no coming-soon banner',
    (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeUser();
      await tester.pumpWidget(_host(repo));
      await _openPrefs(tester);
      // Section headers.
      expect(find.text('CHANNELS'), findsOneWidget);
      expect(find.text('CATEGORIES'), findsOneWidget);
      // Channel toggles (4) + category toggles (3) + always-on (2).
      // Safety + Account are indicators, not toggles-with-handlers.
      expect(find.byType(Switch), findsNWidgets(9));
      // The old stub banner is gone.
      expect(
        find.textContaining('Per-category toggles are coming'),
        findsNothing,
      );
      // Always-on hints are visible.
      expect(find.text('SOS and trip emergencies. Always on.'), findsOneWidget);
    },
  );

  testWidgets('toggling booking_updates PATCHes the right key', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeUser();
    await tester.pumpWidget(_host(repo));
    await _openPrefs(tester);
    // Tap the Switch next to "Bookings & trips".
    final row = find.ancestor(
      of: find.text('Bookings & trips'),
      matching: find.byType(Row),
    );
    final toggle = find.descendant(of: row, matching: find.byType(Switch));
    await tester.tap(toggle.first);
    await tester.pumpAndSettle();
    expect(repo.patches.length, 1);
    expect(repo.patches.single.bookingUpdatesEnabled, isFalse);
  });

  testWidgets('a 5xx response reverts the optimistic toggle', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeUser()..shouldFail = true;
    await tester.pumpWidget(_host(repo));
    await _openPrefs(tester);
    final row = find.ancestor(
      of: find.text('Push notifications'),
      matching: find.byType(Row),
    );
    final toggle = find.descendant(of: row, matching: find.byType(Switch));
    final before = (tester.widget<Switch>(toggle.first)).value;
    await tester.tap(toggle.first);
    await tester.pumpAndSettle();
    final after = tester.widget<Switch>(
      find.descendant(of: row, matching: find.byType(Switch)).first,
    );
    expect(
      after.value,
      before,
      reason: 'Optimistic toggle must revert on failure',
    );
  });
}
