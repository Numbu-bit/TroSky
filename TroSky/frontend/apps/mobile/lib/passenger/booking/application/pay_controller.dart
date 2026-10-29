import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';
import '../data/pay_method_store.dart';
import '../domain/pay_method.dart';
import '../domain/payment_args.dart';

part 'pay_controller.g.dart';

/// Payment asks for a mobile money payment's status
/// (`POST /payments/{id}/sync`) this often while the payer hasn't answered.
const Duration paymentSyncEvery = Duration(seconds: 5);

/// After failed asks the gap doubles (10 s, 20 s), up to this.
const Duration paymentSyncMaxGap = Duration(seconds: 30);

@Riverpod(keepAlive: true)
PayMethodStore payMethodStore(Ref ref) =>
    SharedPreferencesPayMethodStore(SharedPreferencesAsync());

/// What Payment can pay with.
@immutable
class PayOptions {
  const PayOptions({required this.wallet, required this.numbers, this.last});

  /// Null when the wallet couldn't be read: the server then decides.
  final WalletResponse? wallet;

  /// Saved MTN MoMo numbers, the default first.
  final List<PaymentMethodResponse> numbers;

  /// The method used last on this device ([PayMethod.key]).
  final String? last;

  /// The wallet holds [amount], or its balance isn't known.
  bool walletCovers(String amount) =>
      wallet == null || pesewas(wallet!.balance) >= pesewas(amount);

  /// The method offered first: the one used last while it is still there
  /// and can pay, else the wallet if it holds [amount], else the default
  /// number, else the wallet (to change).
  PayMethod initial(String amount) {
    if (last == WalletPay.walletKey && walletCovers(amount)) {
      return const WalletPay();
    }
    for (final number in numbers) {
      if (number.id == last) return MomoPay(number);
    }
    if (walletCovers(amount) || numbers.isEmpty) return const WalletPay();
    return MomoPay(numbers.first);
  }
}

/// The wallet (`GET /wallet`), the saved MTN MoMo numbers
/// (`GET /users/me/payment-methods`) and the method used last. Fails only
/// when neither could be read.
@Riverpod(retry: noRetry)
Future<PayOptions> payOptions(Ref ref) async {
  final userId = ref.watch(
    sessionControllerProvider.select(
      (session) => switch (session.value) {
        SessionAuthenticated(:final user) => user.id,
        _ => null,
      },
    ),
  );
  final repository = ref.read(paymentRepositoryProvider);
  final (wallet, methods, last) = await (
    repository.wallet(),
    repository.methods(),
    _lastMethod(ref, userId),
  ).wait;
  if ((wallet, methods) case (Err(:final failure), Err())) throw failure;
  final numbers = [
    ...?methods.valueOrNull?.where((m) => m.channel == PaymentChannel.mtnMomo),
  ]..sort((a, b) => a.isDefault == b.isDefault ? 0 : (a.isDefault ? -1 : 1));
  return PayOptions(wallet: wallet.valueOrNull, numbers: numbers, last: last);
}

Future<String?> _lastMethod(Ref ref, String? userId) async {
  if (userId == null) return null;
  try {
    return await ref.read(payMethodStoreProvider).lastMethod(userId);
  } on Object {
    return null;
  }
}

/// Where paying stands on Payment.
enum PayStage {
  /// Choosing how to pay (P-07).
  idle,

  /// `POST /bookings/{id}/pay` is on its way.
  paying,

  /// Mobile money: waiting for the payer to approve on their phone (P-08).
  approving,

  /// Paid: the booking is confirmed (P-09).
  paid,

  /// It didn't go through (P-09): declined, too little in the wallet, or
  /// the provider failed. The seats stay held while the hold lasts.
  failed,

  /// The hold ran out before the payer approved: the seats were released.
  /// A later approval is refunded (P-09).
  timedOut,
}

/// What paying shows on Payment.
@immutable
class PayFlow {
  const PayFlow({
    this.stage = PayStage.idle,
    this.method,
    this.payment,
    this.booking,
    this.error,
    this.offline = false,
    this.checking = false,
  });

  final PayStage stage;

  /// What is being, or was last, paid with. Null for a payment found on
  /// the server (Payment reopened while it was under way).
  final PayMethod? method;
  final PaymentResponse? payment;

  /// The booking as read once the payment ended.
  final BookingResponse? booking;

  /// Why paying didn't start (idle: no connection, the server refused) or
  /// failed before reaching the provider (too little in the wallet).
  final AppFailure? error;

  /// The last status check found no connection.
  final bool offline;

  /// "Check again" is asking.
  final bool checking;

  /// The seats are gone: the hold ran out, or a late approval waits for
  /// its refund.
  bool get holdOver => switch (booking?.status) {
    BookingStatus.expired ||
    BookingStatus.cancelled ||
    BookingStatus.refundPending ||
    BookingStatus.refunded => true,
    _ => stage == PayStage.timedOut,
  };

  PayFlow copyWith({PaymentResponse? payment, bool? offline, bool? checking}) =>
      PayFlow(
        stage: stage,
        method: method,
        payment: payment ?? this.payment,
        booking: booking,
        error: error,
        offline: offline ?? this.offline,
        checking: checking ?? this.checking,
      );
}

/// Pays for the booking on Payment and follows a mobile money payment until
/// the payer answers: [paymentSyncEvery], backing off after errors, paused
/// in the background ([pause], [resume]). Reopened while the booking is
/// `payment_pending`, it finds the payment under way and follows it.
@riverpod
class PayController extends _$PayController {
  Timer? _timer;
  int _failures = 0;
  bool _paused = false;
  bool _syncing = false;
  bool _endingHold = false;

  /// The idempotency key of the payment being started. Kept after no
  /// connection, so trying again can't charge twice; dropped once the
  /// server answered.
  String? _key;

  PaymentRepository get _payments => ref.read(paymentRepositoryProvider);

  @override
  PayFlow build(PaymentArgs args) {
    ref.onDispose(() => _timer?.cancel());
    if (args.booking.status == BookingStatus.paymentPending) {
      _timer = Timer(Duration.zero, _findPayment);
      return const PayFlow(stage: PayStage.approving);
    }
    return const PayFlow();
  }

  /// `POST /bookings/{id}/pay` with [method]. Does nothing while a payment
  /// is on its way, under way or done, so a second tap can't pay twice.
  Future<void> pay(PayMethod method) async {
    switch (state.stage) {
      case PayStage.paying ||
          PayStage.approving ||
          PayStage.paid ||
          PayStage.timedOut:
        return;
      case PayStage.idle || PayStage.failed:
        break;
    }
    if (state.method != method) _key = null;
    final key = _key ??= uuidV4();
    state = PayFlow(stage: PayStage.paying, method: method);
    unawaited(_remember(method));
    final result = await _payments.pay(
      args.booking.id,
      method.request,
      idempotencyKey: key,
    );
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        _key = null;
        await _follow(value);
      case Err(:final failure)
          when failure is NetworkFailure || failure is TimeoutFailure:
        state = PayFlow(method: method, error: failure);
      case Err(:final failure) when failure.code == 'BOOKING_NOT_PAYABLE':
        // Paid or paying already (another tap, another phone): follow that.
        _key = null;
        await _findPayment(error: failure);
      case Err(:final failure)
          when failure.code == 'INSUFFICIENT_WALLET_BALANCE':
        _key = null;
        ref.invalidate(payOptionsProvider);
        state = PayFlow(stage: PayStage.failed, method: method, error: failure);
      case Err(:final failure):
        _key = null;
        state = PayFlow(method: method, error: failure);
    }
  }

  /// "Check again" on P-08: asks now.
  Future<void> checkNow() async {
    if (state.stage != PayStage.approving || _syncing) return;
    state = state.copyWith(checking: true);
    if (state.payment == null) {
      await _findPayment();
    } else {
      await _sync();
    }
  }

  /// The hold ran out with the payment still waiting: asks once more, then
  /// stops. The server expires the booking and releases the seats; if the
  /// payer approves later, the booking waits for a refund
  /// (backend/app/services/payment_service.py `_settle_booking_payment`).
  Future<void> timeUp() async {
    if (state.stage != PayStage.approving || _endingHold) return;
    _endingHold = true;
    _timer?.cancel();
    if (state.payment case final payment?) {
      final result = await _payments.sync(payment.id);
      if (!ref.mounted || state.stage != PayStage.approving) return;
      if (result case Ok(:final value) when !_waiting(value)) {
        await _follow(value);
        return;
      }
    }
    final read = await ref.read(bookingRepositoryProvider).get(args.booking.id);
    if (!ref.mounted || state.stage != PayStage.approving) return;
    state = PayFlow(
      stage: PayStage.timedOut,
      method: state.method,
      payment: state.payment,
      booking: read.valueOrNull,
    );
  }

  /// Back from P-09's failure to P-07, to pay again or another way.
  void reset() {
    if (state.stage != PayStage.failed || state.holdOver) return;
    state = PayFlow(method: state.method);
  }

  /// The app went to the background: no checks meanwhile.
  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  /// The app is back, maybe from approving on the phone: asks now.
  Future<void> resume() async {
    _paused = false;
    if (state.stage != PayStage.approving) return;
    if (state.payment == null) {
      await _findPayment();
    } else {
      await _sync();
    }
  }

  /// Keeps [method] as the passenger's last one on this device.
  Future<void> _remember(PayMethod method) async {
    final session = ref.read(sessionControllerProvider).value;
    if (session is! SessionAuthenticated) return;
    try {
      await ref
          .read(payMethodStoreProvider)
          .saveLastMethod(session.user.id, method.key);
    } on Object {
      // Only a convenience: the next payment offers the default again.
    }
  }

  static bool _waiting(PaymentResponse payment) =>
      payment.status == PaymentStatus.pending ||
      payment.status == PaymentStatus.processing;

  /// Shows [payment]: waiting for the payer, or ended.
  Future<void> _follow(PaymentResponse payment) async {
    if (_waiting(payment)) {
      _failures = 0;
      state = PayFlow(
        stage: PayStage.approving,
        method: state.method,
        payment: payment,
      );
      if (!_paused) _schedule(paymentSyncEvery);
      return;
    }
    await _ended(
      payment,
      payment.status == PaymentStatus.failed ||
              payment.status == PaymentStatus.cancelled
          ? PayStage.failed
          : PayStage.paid,
    );
  }

  /// The payment ended: the booking says where that left it. A success
  /// that came after the hold ran out is a refund, not a booking.
  Future<void> _ended(PaymentResponse payment, PayStage stage) async {
    _timer?.cancel();
    final read = await ref.read(bookingRepositoryProvider).get(args.booking.id);
    if (!ref.mounted) return;
    final booking = read.valueOrNull;
    final late =
        stage == PayStage.paid &&
        booking != null &&
        booking.status != BookingStatus.confirmed &&
        booking.status != BookingStatus.completed;
    state = PayFlow(
      stage: late ? PayStage.timedOut : stage,
      method: state.method,
      payment: payment,
      booking: booking,
    );
  }

  /// The booking is past `pending`: its payment is under way or done
  /// (`GET /payments`, newest first).
  Future<void> _findPayment({AppFailure? error}) async {
    final result = await _payments.list(limit: 20);
    if (!ref.mounted) return;
    final mine = [
      ...?result.valueOrNull?.items.where(
        (p) => p.bookingId == args.booking.id,
      ),
    ];
    final payment = mine.where(_waiting).firstOrNull ?? mine.firstOrNull;
    if (payment == null) {
      state = PayFlow(
        method: state.method,
        error: error ?? result.failureOrNull,
      );
      return;
    }
    await _follow(payment);
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, _sync);
  }

  Future<void> _sync() async {
    final payment = state.payment;
    if (_syncing || payment == null || state.stage != PayStage.approving) {
      return;
    }
    _syncing = true;
    _timer?.cancel();
    final result = await _payments.sync(payment.id);
    _syncing = false;
    if (!ref.mounted || state.stage != PayStage.approving) return;
    switch (result) {
      case Ok(:final value) when _waiting(value):
        _failures = 0;
        state = state.copyWith(payment: value, offline: false, checking: false);
      case Ok(:final value):
        await _follow(value);
        return;
      case Err(:final failure):
        _failures++;
        state = state.copyWith(
          offline: failure is NetworkFailure || failure is TimeoutFailure,
          checking: false,
        );
    }
    if (!_paused) _schedule(_gap());
  }

  Duration _gap() {
    if (_failures == 0) return paymentSyncEvery;
    final gap = paymentSyncEvery * (1 << _failures.clamp(1, 3));
    return gap > paymentSyncMaxGap ? paymentSyncMaxGap : gap;
  }
}
