import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../app/app_providers.dart';
import '../domain/payment_args.dart';

part 'booking_watch.g.dart';

/// Payment asks for the booking (`GET /bookings/{id}`) this often while the
/// driver hasn't answered.
const Duration bookingPollEvery = Duration(seconds: 5);

/// After failed polls the gap doubles (10 s, 20 s), up to this.
const Duration bookingPollMaxGap = Duration(seconds: 30);

/// Where a booking on Payment (P-07) stands, from what the server says.
enum PaymentStage {
  /// `awaiting_acceptance`: waiting for the trip's driver to accept it.
  waiting,

  /// Moved to another vehicle (a new `trip_id`), waiting for its driver.
  moved,

  /// `pending` (or later): accepted, to pay before `expires_at`.
  accepted,

  /// It ended (`expired` or `cancelled`) without being accepted: nobody
  /// answered, or the driver declined, and no other vehicle had seats.
  notAccepted,

  /// Accepted, but not paid for in time (`expired`).
  holdExpired,

  /// Cancelled from this screen.
  cancelled,
}

/// Why the booking moved: worked out from when the move was seen, before
/// or after the old deadline (backend/app/services/booking_acceptance_
/// service.py moves it at once when the driver declines, and only after
/// the deadline when nobody answers).
enum MoveReason { unanswered, declined }

/// What Payment shows: the booking as last read, and what changed.
@immutable
class BookingWatch {
  const BookingWatch({
    required this.booking,
    required this.stage,
    this.movedFrom,
    this.moveReason,
    this.acceptedHere = false,
    this.answerWindow,
    this.offline = false,
  });

  final BookingResponse booking;
  final PaymentStage stage;

  /// The booking before its last move, for the trip it was on.
  final BookingResponse? movedFrom;
  final MoveReason? moveReason;

  /// The driver accepted while this screen was waiting (the green banner).
  final bool acceptedHere;

  /// How long a driver has to answer (`BOOKING_ACCEPT_TIMEOUT_SECONDS`,
  /// which the API doesn't send): a new booking's `expires_at` less its
  /// `created_at`. Null when that can't be known (a reopened booking).
  final Duration? answerWindow;

  /// The last poll found no connection.
  final bool offline;

  BookingWatch copyWith({BookingResponse? booking, bool? offline}) =>
      BookingWatch(
        booking: booking ?? this.booking,
        stage: stage,
        movedFrom: movedFrom,
        moveReason: moveReason,
        acceptedHere: acceptedHere,
        answerWindow: answerWindow,
        offline: offline ?? this.offline,
      );
}

/// The booking shown on Payment, kept up to date: polled every
/// [bookingPollEvery] while the driver hasn't answered, backing off after
/// errors, paused while the app is in the background and read again when
/// it comes back ([pause], [resume]). Disposed, and so stopped, when
/// Payment closes.
@riverpod
class BookingWatchController extends _$BookingWatchController {
  Timer? _timer;
  int _failures = 0;
  bool _paused = false;
  bool _polling = false;

  @override
  BookingWatch build(PaymentArgs args) {
    ref.onDispose(() => _timer?.cancel());
    final booking = args.booking;
    final waiting = booking.status == BookingStatus.awaitingAcceptance;
    final watch = BookingWatch(
      booking: booking,
      stage: _stageOf(booking.status, from: null),
      answerWindow: waiting && !args.restored
          ? booking.expiresAt?.difference(booking.createdAt)
          : null,
    );
    if (_polls(watch.stage)) _schedule(bookingPollEvery);
    return watch;
  }

  /// The app went to the background: no polling meanwhile.
  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  /// The app is back: read the booking now, and poll again while waiting.
  Future<void> resume() async {
    _paused = false;
    if (_polls(state.stage) || state.stage == PaymentStage.accepted) {
      await _poll();
    }
  }

  /// `POST /bookings/{id}/cancel`. When the server says it already ended,
  /// the booking is read again to show how.
  Future<Result<BookingResponse>> cancel() async {
    final result = await ref
        .read(bookingRepositoryProvider)
        .cancel(state.booking.id);
    if (!ref.mounted) return result;
    switch (result) {
      case Ok(:final value):
        _timer?.cancel();
        state = BookingWatch(
          booking: value,
          stage: PaymentStage.cancelled,
          answerWindow: state.answerWindow,
        );
      case Err(:final failure) when failure.code == 'INVALID_STATE_TRANSITION':
        await _poll();
      case Err():
        break;
    }
    return result;
  }

  bool _polls(PaymentStage stage) =>
      stage == PaymentStage.waiting || stage == PaymentStage.moved;

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, _poll);
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    _timer?.cancel();
    final result = await ref
        .read(bookingRepositoryProvider)
        .get(state.booking.id);
    _polling = false;
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        _failures = 0;
        _apply(value);
      case Err(:final failure):
        _failures++;
        state = state.copyWith(
          offline: failure is NetworkFailure || failure is TimeoutFailure,
        );
    }
    if (!_paused && _polls(state.stage)) _schedule(_gap());
  }

  Duration _gap() {
    if (_failures == 0) return bookingPollEvery;
    final gap = bookingPollEvery * (1 << _failures.clamp(1, 3));
    return gap > bookingPollMaxGap ? bookingPollMaxGap : gap;
  }

  void _apply(BookingResponse next) {
    final current = state;
    final previous = current.booking;
    if (next.status == BookingStatus.awaitingAcceptance &&
        next.tripId != previous.tripId) {
      final now = ref.read(clockProvider)().toUtc();
      final answeredInTime =
          previous.status != BookingStatus.awaitingAcceptance ||
          (previous.expiresAt?.isAfter(now) ?? false);
      state = BookingWatch(
        booking: next,
        stage: PaymentStage.moved,
        movedFrom: previous,
        moveReason: answeredInTime
            ? MoveReason.declined
            : MoveReason.unanswered,
        answerWindow: current.answerWindow,
      );
      return;
    }
    final stage = _stageOf(next.status, from: current.stage);
    state = BookingWatch(
      booking: next,
      stage: stage,
      movedFrom: stage == current.stage ? current.movedFrom : null,
      moveReason: stage == current.stage ? current.moveReason : null,
      acceptedHere:
          current.acceptedHere ||
          (stage == PaymentStage.accepted && _polls(current.stage)),
      answerWindow: current.answerWindow,
    );
  }

  static PaymentStage _stageOf(BookingStatus status, {PaymentStage? from}) =>
      switch (status) {
        BookingStatus.awaitingAcceptance =>
          from == PaymentStage.moved
              ? PaymentStage.moved
              : PaymentStage.waiting,
        BookingStatus.pending ||
        BookingStatus.paymentPending ||
        BookingStatus.confirmed => PaymentStage.accepted,
        BookingStatus.expired when from == PaymentStage.accepted =>
          PaymentStage.holdExpired,
        _ => PaymentStage.notAccepted,
      };
}
