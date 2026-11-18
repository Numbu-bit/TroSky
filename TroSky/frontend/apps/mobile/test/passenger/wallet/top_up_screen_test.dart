// Widget tests for P-18. Replaces the live PaymentRepository with a
// fake so the screen can submit without touching the network.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/wallet/domain/wallet_args.dart';
import 'package:mobile/passenger/wallet/presentation/top_up_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeRepo implements PaymentRepository {
  final List<(WalletTopupRequest req, String key)> topupCalls = [];

  @override
  Future<Result<PaymentResponse>> topUpWallet(
    WalletTopupRequest request, {
    required String idempotencyKey,
  }) async {
    topupCalls.add((request, idempotencyKey));
    return Err(const NetworkFailure(message: 'offline'));
  }

  @override
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  ) async => const Err(NetworkFailure());

  @override
  Future<Result<void>> deleteMethod(String methodId) async =>
      const Err(NetworkFailure());

  @override
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<List<PaymentMethodResponse>>> methods() async =>
      const Err(NetworkFailure());

  @override
  Future<Result<PaymentResponse>> pay(
    String bookingId,
    PayBookingRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<PaymentResponse>> sync(String paymentId) async =>
      const Err(NetworkFailure());

  @override
  Future<Result<Paginated<WalletTransactionResponse>>> transactions({
    WalletReferenceType? referenceType,
    int limit = 20,
    int offset = 0,
  }) async =>
      Ok(Paginated(items: const [], total: 0, limit: limit, offset: offset));

  @override
  Future<Result<PaymentMethodResponse>> updateMethod(
    String methodId,
    PaymentMethodUpdateRequest request,
  ) async => const Err(NetworkFailure());

  @override
  Future<Result<WalletResponse>> wallet() async => const Err(NetworkFailure());
}

class _RecordingTelemetry implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

PaymentMethodResponse _method() => PaymentMethodResponse(
  id: 'm1',
  channel: PaymentChannel.mtnMomo,
  maskedNumber: '024 *** 8821',
  label: null,
  isDefault: true,
  createdAt: DateTime.utc(2026, 11, 1),
);

Widget _host({required _FakeRepo repo, TelemetryService? telemetry}) =>
    ProviderScope(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
        if (telemetry != null) telemetryProvider.overrideWithValue(telemetry),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: TopUpScreen(args: TopUpArgs(method: _method())),
      ),
    );

void main() {
  testWidgets('preset chip updates button label to that amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final telemetry = _RecordingTelemetry();
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo: repo, telemetry: telemetry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('₵50.00'));
    await tester.pumpAndSettle();
    expect(find.text('Top up ₵50.00'), findsOneWidget);
    expect(
      telemetry.events.any((e) => e.name == 'wallet_topup_preset_picked'),
      isTrue,
    );
  });

  testWidgets('invalid custom amount shows localized error', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0.5'); // Below min
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up ₵0.00')); // CTA for invalid
    await tester.pumpAndSettle();
    expect(find.textContaining('between'), findsOneWidget);
    expect(repo.topupCalls, isEmpty);
  });

  testWidgets(
    'Submit calls repository with the idempotency key and amount',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final telemetry = _RecordingTelemetry();
      final repo = _FakeRepo();
      await tester.pumpWidget(_host(repo: repo, telemetry: telemetry));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top up ₵100.00'));
      await tester.pump();
      expect(repo.topupCalls.length, 1);
      final (req, key) = repo.topupCalls.single;
      expect(req.amount, '100.00');
      expect(req.paymentMethodId, 'm1');
      expect(key, isNotEmpty);
      expect(
        telemetry.events.any((e) => e.name == 'wallet_topup_submitted'),
        isTrue,
      );
    },
  );
}
