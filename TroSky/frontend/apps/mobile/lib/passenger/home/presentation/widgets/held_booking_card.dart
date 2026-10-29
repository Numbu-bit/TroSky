import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../booking/domain/payment_args.dart';
import '../../../booking/presentation/booking_format.dart';
import '../../../seats/application/seat_providers.dart';

/// A booking whose seats are held, at the top of Home's sheet (decision
/// 31): "Seats held · 9:12 left" with "Pay now", or "Waiting for driver"
/// with "View status". Either opens Payment. It goes when the deadline
/// passes, and the booking is read again (a move gives it a new one).
class HeldBookingCard extends ConsumerStatefulWidget {
  const HeldBookingCard({super.key});

  @override
  ConsumerState<HeldBookingCard> createState() => _HeldBookingCardState();
}

class _HeldBookingCardState extends ConsumerState<HeldBookingCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The countdown moves on; past the deadline, read the booking again.
  void _tick() {
    final booking = ref.read(heldBookingProvider).value;
    if (booking == null) return;
    if (_left(booking) == Duration.zero) {
      ref.invalidate(heldBookingProvider);
    } else {
      setState(() {});
    }
  }

  Duration _left(BookingResponse booking) {
    final now = ref.read(clockProvider)().toUtc();
    final left = booking.expiresAt?.difference(now);
    return left == null || left.isNegative ? Duration.zero : left;
  }

  Future<void> _open(BookingResponse booking) async {
    await context.pushNamed(
      AppRoute.payment.name,
      extra: PaymentArgs(booking: booking, restored: true),
    );
    if (mounted) ref.invalidate(heldBookingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(heldBookingProvider).value;
    if (booking == null) return const SizedBox.shrink();
    final left = _left(booking);
    if (left == Duration.zero) return const SizedBox.shrink();
    final waiting = booking.status == BookingStatus.awaitingAcceptance;
    // A MoMo payment is waiting for its approval: Payment shows it.
    final paying = booking.status == BookingStatus.paymentPending;
    final trip = booking.trip;
    final from = booking.boardingStopName ?? trip?.originStopName ?? '';
    final to = booking.alightingStopName ?? trip?.destinationStopName ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: TroskySpacing.s16),
      child: TroskyHeldBookingCard(
        route: '$from → $to',
        when: trip == null
            ? ''
            : bookingWhen(
                l10n,
                trip.scheduledDepartureAt,
                ref.read(clockProvider)(),
              ),
        status: waiting
            ? l10n.bookingStatusWaiting
            : l10n.homeHeldSeats(timeLeft(left)),
        tone: TroskyTagTone.amber,
        action: waiting || paying ? l10n.bookingViewStatus : l10n.bookingPayNow,
        onPressed: () => _open(booking),
      ),
    );
  }
}
