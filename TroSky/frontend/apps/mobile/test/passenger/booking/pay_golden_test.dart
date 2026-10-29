@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/trosky_mobile_app.dart';
import 'package:mobile/passenger/booking/application/pay_controller.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../search/search_helpers.dart';
import 'payment_helpers.dart';

/// Paying (Step 15) at the design frame, 390 x 844, in mock mode: P-07's
/// pay section, the method sheet, Approve on your phone (P-08) and the
/// outcomes (P-09). The whole app is captured, so sheets show over Payment.
/// The derived ones are copied to `design/<ID>/derived/`.
void _goldenTest(
  String description,
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(TroskyMobileApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  });
}

const Size _frame = Size(390, 844);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _momo(WidgetTester tester) async {
  await _tap(tester, 'Change');
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is TroskyPayMethodOption && w.title == 'MTN MoMo',
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addNumber(WidgetTester tester, String number) async {
  await _tap(tester, 'Change');
  await _tap(tester, '+ Add an MTN MoMo number');
  await tester.enterText(find.byType(TextField), number);
  await _tap(tester, 'Use this number');
}

void main() {
  _goldenTest('P-07: paying with a saved MTN MoMo number', 'pay_momo_390', (
    tester,
  ) async {
    await acceptedPayment(tester, size: _frame);
    await _momo(tester);
  });

  _goldenTest(
    'Pay with: the wallet, a saved number, add one',
    'pay_sheet_390',
    (tester) async {
      await acceptedPayment(tester, size: _frame);
      await _tap(tester, 'Change');
    },
  );

  _goldenTest(
    'Pay with: the wallet too low, a new number not valid',
    'pay_sheet_add_390',
    (tester) async {
      final world = morning();
      world.backend.setWalletBalance(MockBackend.passengerPhone, 5);
      await acceptedPayment(tester, world: world, size: _frame);
      await _tap(tester, 'Change');
      await _tap(tester, '+ Add an MTN MoMo number');
      await tester.enterText(find.byType(TextField), '024 12');
      await _tap(tester, 'Use this number');
      // The keyboard isn't drawn in a test.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
  );

  _goldenTest('P-08: approve on your phone', 'pay_approve_390', (tester) async {
    final (world, _) = await acceptedPayment(tester, size: _frame);
    world.backend.momoApproveAfter = const Duration(hours: 1);
    await _momo(tester);
    await _tap(tester, 'Pay ₵29.00');
    await waitFor(tester, world, const Duration(seconds: 12));
  });

  _goldenTest("P-08: I didn't get a prompt", 'pay_no_prompt_390', (
    tester,
  ) async {
    final (world, _) = await acceptedPayment(tester, size: _frame);
    world.backend.momoApproveAfter = const Duration(hours: 1);
    await _momo(tester);
    await _tap(tester, 'Pay ₵29.00');
    await _tap(tester, "I didn't get a prompt");
  });

  _goldenTest('P-09: paid', 'pay_success_390', (tester) async {
    final (world, _) = await acceptedPayment(tester, size: _frame);
    await _momo(tester);
    await _tap(tester, 'Pay ₵29.00');
    await waitFor(tester, world, paymentSyncEvery);
  });

  _goldenTest('P-09: declined, seats still held', 'pay_failed_390', (
    tester,
  ) async {
    final (world, _) = await acceptedPayment(tester, size: _frame);
    await _addNumber(tester, '0240000000');
    await _tap(tester, 'Pay ₵29.00');
    await waitFor(tester, world, paymentSyncEvery);
  });

  _goldenTest('P-09: the time ran out', 'pay_timed_out_390', (tester) async {
    final (world, booking) = await acceptedPayment(tester, size: _frame);
    await _addNumber(tester, '0249999999');
    await _tap(tester, 'Pay ₵29.00');
    world.now = booking.expiresAt!;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Time ran out'), findsOneWidget);
  });
}
