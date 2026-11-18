// Widget tests for P-17. Uses an in-memory FakePaymentRepository instead
// of real HTTP, so it runs offline and deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/wallet/presentation/wallet_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeRepo implements PaymentRepository {
  _FakeRepo({this.methodsResult, this.transactionsResult});

  Result<List<PaymentMethodResponse>>? methodsResult;
  Result<Paginated<WalletTransactionResponse>>? transactionsResult;

  final List<(String id, PaymentMethodUpdateRequest r)> updates = [];
  final List<String> deletes = [];

  @override
  Future<Result<List<PaymentMethodResponse>>> methods() async =>
      methodsResult ?? const Ok([]);

  @override
  Future<Result<Paginated<WalletTransactionResponse>>> transactions({
    WalletReferenceType? referenceType,
    int limit = 20,
    int offset = 0,
  }) async =>
      transactionsResult ??
      Ok(Paginated(items: const [], total: 0, limit: limit, offset: offset));

  @override
  Future<Result<PaymentMethodResponse>> updateMethod(
    String methodId,
    PaymentMethodUpdateRequest request,
  ) async {
    updates.add((methodId, request));
    return Err(const NetworkFailure());
  }

  @override
  Future<Result<void>> deleteMethod(String methodId) async {
    deletes.add(methodId);
    return const Ok(null);
  }

  // Unused by P-17 tests.
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
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<PaymentResponse>> topUpWallet(
    WalletTopupRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<WalletResponse>> wallet() async => const Err(NetworkFailure());

  @override
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  ) async => const Err(NetworkFailure());
}

class _RecordingTelemetry implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

PaymentMethodResponse _method({
  required String id,
  required PaymentChannel channel,
  required bool isDefault,
  String masked = '024 *** 8821',
}) => PaymentMethodResponse(
  id: id,
  channel: channel,
  maskedNumber: masked,
  label: null,
  isDefault: isDefault,
  createdAt: DateTime.utc(2026, 11, 1),
);

WalletTransactionResponse _txn({
  required String id,
  required WalletReferenceType ref,
  required WalletEntryType entry,
  String amount = '11.50',
  DateTime? at,
}) => WalletTransactionResponse(
  id: id,
  entryType: entry,
  amount: amount,
  balanceAfter: '0.00',
  referenceType: ref,
  referenceId: null,
  description: 'Row $id',
  createdAt: at ?? DateTime.utc(2026, 11, 18, 7, 15),
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
        home: const WalletScreen(),
      ),
    );

void main() {
  testWidgets('P-17 renders header + methods + transactions from fixtures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo(
      methodsResult: Ok([
        _method(
          id: 'm1',
          channel: PaymentChannel.mtnMomo,
          isDefault: true,
          masked: '024 *** 8821',
        ),
        _method(
          id: 'm2',
          channel: PaymentChannel.mtnMomo,
          isDefault: false,
          masked: '055 *** 7733',
        ),
      ]),
      transactionsResult: Ok(
        Paginated(
          items: [
            _txn(
              id: 't1',
              ref: WalletReferenceType.walletTopup,
              entry: WalletEntryType.credit,
              amount: '50.00',
            ),
            _txn(
              id: 't2',
              ref: WalletReferenceType.bookingPayment,
              entry: WalletEntryType.debit,
              amount: '11.50',
            ),
          ],
          total: 2,
          limit: 5,
          offset: 0,
        ),
      ),
    );
    await tester.pumpWidget(_host(repo: repo));
    await tester.pumpAndSettle();
    // Header
    expect(find.text('Wallet'), findsOneWidget);
    // Methods card
    expect(find.text('Payment Methods'), findsOneWidget);
    expect(find.text('024 *** 8821'), findsOneWidget);
    expect(find.text('055 *** 7733'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('+ Add method'), findsOneWidget);
    // Transactions card
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Row t1'), findsOneWidget);
    expect(find.text('Row t2'), findsOneWidget);
  });

  testWidgets('See all / See less toggles the expanded list and filter chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final telemetry = _RecordingTelemetry();
    final repo = _FakeRepo(
      methodsResult: const Ok([]),
      transactionsResult: Ok(
        Paginated(
          items: [
            _txn(
              id: 't1',
              ref: WalletReferenceType.walletTopup,
              entry: WalletEntryType.credit,
            ),
          ],
          total: 1,
          limit: 5,
          offset: 0,
        ),
      ),
    );
    await tester.pumpWidget(_host(repo: repo, telemetry: telemetry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Top-ups', skipOffstage: false), findsOneWidget);
    expect(find.text('Trips', skipOffstage: false), findsOneWidget);
    expect(find.text('Refunds', skipOffstage: false), findsOneWidget);
    expect(find.text('See less'), findsOneWidget);
    expect(
      telemetry.events.any((e) => e.name == 'wallet_transactions_expanded'),
      isTrue,
    );
    await tester.tap(find.text('See less'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsNothing);
  });

  testWidgets(
    'Tapping non-default method opens sheet; Set as default calls updateMethod',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final telemetry = _RecordingTelemetry();
      final repo = _FakeRepo(
        methodsResult: Ok([
          _method(
            id: 'm1',
            channel: PaymentChannel.mtnMomo,
            isDefault: false,
            masked: '024 *** 8821',
          ),
        ]),
      );
      await tester.pumpWidget(_host(repo: repo, telemetry: telemetry));
      await tester.pumpAndSettle();
      await tester.tap(find.text('024 *** 8821'));
      await tester.pumpAndSettle();
      expect(find.text('Set as default'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();
      expect(repo.updates.length, 1);
      expect(repo.updates.single.$1, 'm1');
      expect(repo.updates.single.$2.isDefault, true);
      expect(
        telemetry.events.any((e) => e.name == 'wallet_payment_method_tapped'),
        isTrue,
      );
    },
  );

  testWidgets(
    'Add method picker: MoMo pickable; Telecel/Visa disabled with Coming soon',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo(methodsResult: const Ok([]));
      await tester.pumpWidget(_host(repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Add method'));
      await tester.pumpAndSettle();
      expect(find.text('MTN MoMo'), findsOneWidget);
      expect(find.text('Telecel Cash'), findsOneWidget);
      expect(find.text('Visa Debit'), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(2));
    },
  );
}
