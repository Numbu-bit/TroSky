import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../seats/application/seat_providers.dart';
import '../../seats/domain/seat_map_layout.dart';

/// How Payment closed, for the screen under it.
enum PaymentOutcome {
  /// The booking was cancelled; the seats are free again.
  cancelled,

  /// The hold ran out.
  expired,

  /// The passenger went back to change seats and released them (the
  /// booking is cancelled).
  released,
}

/// A held booking for Payment (P-07).
@immutable
class PaymentArgs {
  const PaymentArgs({
    required this.booking,
    this.seatNumbers,
    this.restored = false,
  });

  final BookingResponse booking;

  /// The booked seats' numbers; looked up from the seat map when unknown
  /// (a booking reopened after the app restarted).
  final List<String>? seatNumbers;

  /// Reopened by Home after a restart, not reached from Seat Selection.
  final bool restored;
}

/// Payment (P-07): a placeholder until payment is built. It shows the held
/// booking, counts down the seat hold (`expires_at`) and can cancel it.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Timer? _ticker;
  Duration _left = Duration.zero;
  bool _cancelling = false;
  bool _closed = false;
  String? _error;

  BookingResponse get _booking => widget.args.booking;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final expires = _booking.expiresAt;
    if (expires == null || !mounted) return;
    final left = expires.difference(ref.read(clockProvider)().toUtc());
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left <= Duration.zero) _expired();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _close(PaymentOutcome outcome) {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    ref.invalidate(heldBookingProvider);
    context.pop(outcome);
  }

  void _expired() {
    if (_closed) return;
    final l10n = AppLocalizations.of(context);
    _say(widget.args.restored ? l10n.paymentExpiredHome : l10n.paymentExpired);
    _close(PaymentOutcome.expired);
  }

  /// Back from a booking just made on Seat Selection: going back to change
  /// seats would leave these held, so ask to release them first.
  Future<void> _back() async {
    if (widget.args.restored) {
      context.pop();
      return;
    }
    final release = await showReleaseSeatsPrompt(context);
    if ((release ?? false) && mounted) await _cancel(released: true);
  }

  Future<void> _cancel({bool released = false}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _cancelling = true;
      _error = null;
    });
    final result = await ref
        .read(bookingRepositoryProvider)
        .cancel(_booking.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    switch (result) {
      case Ok() when released:
        _say(l10n.paymentReleased);
        _close(PaymentOutcome.released);
      case Ok():
        _say(l10n.paymentCancelled);
        _close(PaymentOutcome.cancelled);
      case Err(:final failure) when failure.code == 'INVALID_STATE_TRANSITION':
        // Already expired or cancelled on the server.
        _expired();
      case Err(:final failure):
        setState(() => _error = failureMessage(context, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers =
        widget.args.seatNumbers ??
        _seatNumbersFrom(ref.watch(tripSeatsProvider(_booking.tripId)).value);
    final minutes = _left.inMinutes.toString().padLeft(2, '0');
    final seconds = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: widget.args.restored,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_closed && !_cancelling) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              TroskySpacing.s16,
              MediaQuery.viewPaddingOf(context).top + TroskySpacing.s4,
              TroskySpacing.s16,
              TroskySpacing.s24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  // The chevron sits on the page margin; its touch area
                  // reaches past it.
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: Semantics(
                      container: true,
                      button: true,
                      label: l10n.backLabel,
                      onTap: _cancelling ? null : _back,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _cancelling ? null : _back,
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: TroskyIcons.back(
                              color: TroskyColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.paymentTitle,
                        style: TroskyTypography.heading20Bold.copyWith(
                          color: TroskyColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TroskySpacing.s16),
              Container(
                padding: const EdgeInsets.all(TroskySpacing.s16),
                decoration: BoxDecoration(
                  color: TroskyColors.surface,
                  borderRadius: BorderRadius.circular(TroskyRadii.r20),
                  boxShadow: TroskyShadows.cardSubtle,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: _left.inSeconds % 60 == 0,
                      child: Text(
                        l10n.paymentHeldFor('$minutes:$seconds'),
                        style: TroskyTypography.heading16ExtraBold.copyWith(
                          color: _left < const Duration(minutes: 1)
                              ? TroskyColors.red
                              : TroskyColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: TroskySpacing.s4),
                    Text(
                      l10n.paymentReference(_booking.bookingReference),
                      style: TroskyTypography.body13Regular.copyWith(
                        color: TroskyColors.textSecondary,
                      ),
                    ),
                    if (_booking.trip case final trip?)
                      Text(
                        [
                          '${_booking.boardingStopName ?? trip.originStopName} → '
                              '${_booking.alightingStopName ?? trip.destinationStopName}',
                          ?trip.vehicleRegistrationNumber,
                        ].join(' · '),
                        style: TroskyTypography.body13Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: TroskySpacing.s12),
                    _Line(l10n.paymentSeats, numbers?.join(', ') ?? '…'),
                    _Line(l10n.paymentFare, _cedis(l10n, _booking.fareAmount)),
                    _Line(
                      l10n.paymentPlatformFee,
                      _cedis(l10n, _booking.platformFee),
                    ),
                    const Divider(height: TroskySpacing.s20),
                    _Line(
                      l10n.paymentTotal,
                      _cedis(l10n, _booking.totalAmount),
                      strong: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              Text(
                l10n.paymentComingSoon,
                style: TroskyTypography.body13Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: TroskySpacing.s12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TroskyTypography.body13Regular.copyWith(
                      color: TroskyColors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: TroskySpacing.s20),
              TroskyButton(
                label: l10n.paymentCancel,
                variant: TroskyButtonVariant.outline,
                loading: _cancelling,
                onPressed: _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String>? _seatNumbersFrom(TripSeatsResponse? map) {
    if (map == null) return null;
    final numbers = {for (final s in map.seats) s.id: s.seatNumber};
    return [for (final p in _booking.passengers) numbers[p.seatId] ?? '?']
      ..sort(compareSeatNumbers);
  }
}

/// Going back from Payment to change seats: true to release the held seats
/// (cancel the booking), false or null (dismissed) to stay.
Future<bool?> showReleaseSeatsPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s24,
          TroskySpacing.s28,
          TroskySpacing.s24,
          TroskySpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.paymentReleaseTitle,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.paymentReleaseBody,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: l10n.paymentReleaseKeep,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.paymentReleaseConfirm,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "₵29.00": booking amounts keep their pesewas.
String _cedis(AppLocalizations l10n, String amount) =>
    l10n.priceCedis(double.parse(amount).toStringAsFixed(2));

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? TroskyTypography.heading16ExtraBold.copyWith(color: TroskyColors.ink)
        : TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.textPrimary,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
