import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/domain/payment_args.dart';
import '../../booking/presentation/booking_format.dart';
import '../../search/presentation/trip_view.dart';
import '../../seats/application/seat_providers.dart';
import '../application/trips_providers.dart';
import '../domain/booking_view.dart';
import 'cancel_booking_sheet.dart';

/// Booking details (P-16): the trip, vehicle and driver, seats and fare,
/// with the status chip in the header and the actions its status allows.
/// "View ticket", "Track trip", "Rate driver" and "Book again" aren't built
/// yet, so they aren't shown.
///
/// [initial] is the booking as Trip History had it, shown until the
/// details arrive.
class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.initial,
  });

  final String bookingId;
  final BookingResponse? initial;

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  /// The answer to a cancel: the screen then says how it went.
  CancelOutcome? _outcome;

  BookingDetailsProvider get _details =>
      bookingDetailsProvider(widget.bookingId);

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy(String reference) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: reference));
    if (mounted) _say(l10n.bookingReferenceCopied);
  }

  /// Payment (P-07) for this booking: to pay, or to follow the driver's
  /// answer. Back from it comes here, read again.
  Future<void> _payment(BookingResponse booking) async {
    await context.pushNamed(
      AppRoute.payment.name,
      extra: PaymentArgs(booking: booking, restored: true),
    );
    if (mounted) refreshBookings(ref, booking.id);
  }

  Future<void> _cancel(BookingDetails details) async {
    final outcome = await showCancelBookingSheet(
      context,
      booking: details.booking,
      tripStatus: details.trip?.status,
    );
    if (outcome == null || !mounted) return;
    refreshBookings(ref, details.booking.id);
    setState(() => _outcome = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_outcome case final outcome?) {
      return _Cancelled(outcome: outcome, onDone: () => context.pop());
    }
    final details = ref.watch(_details);
    final shown =
        details.value ??
        (widget.initial == null
            ? null
            : BookingDetails(booking: widget.initial!));
    final booking = shown?.booking;
    final chip = booking == null
        ? null
        : BookingChip.of(booking, tripStatus: shown?.trip?.status);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: Column(
          children: [
            TroskyPageHeader(
              title: l10n.bookingDetailsTitle,
              subtitle: booking?.bookingReference ?? '',
              backLabel: l10n.backLabel,
              onBack: () => context.pop(),
              subtitleTrailing: booking == null
                  ? null
                  : Semantics(
                      button: true,
                      label: l10n.bookingCopyReference,
                      excludeSemantics: true,
                      child: InkResponse(
                        onTap: () => _copy(booking.bookingReference),
                        radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.all(TroskySpacing.s8),
                          child: TroskyIcons.copy(color: TroskyColors.whiteA55),
                        ),
                      ),
                    ),
              trailing: chip == null
                  ? null
                  : TroskyStatusChip(label: chip.label(l10n), tone: chip.chip),
            ),
            Expanded(child: _body(l10n, details, shown, chip)),
            if (shown != null && chip != null) _actions(l10n, shown, chip),
          ],
        ),
      ),
    );
  }

  Widget _body(
    AppLocalizations l10n,
    AsyncValue<BookingDetails> details,
    BookingDetails? shown,
    BookingChip? chip,
  ) {
    const padding = EdgeInsets.fromLTRB(
      TroskySpacing.s18,
      TroskySpacing.s16,
      TroskySpacing.s18,
      TroskySpacing.s24,
    );
    if (shown == null || chip == null) {
      if (details.hasError) {
        final error = details.error;
        return ListView(
          padding: padding,
          children: [
            const SizedBox(height: TroskySpacing.s32),
            Text(
              error is AppFailure
                  ? failureMessage(context, error)
                  : l10n.bookingLoadError,
              textAlign: TextAlign.center,
              style: TroskyTypography.heading15Bold.copyWith(
                color: TroskyColors.textPrimary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s16),
            TroskyButton(
              label: l10n.offlineRetry,
              variant: TroskyButtonVariant.outline,
              onPressed: () => ref.invalidate(_details),
            ),
          ],
        );
      }
      return ListView(
        padding: padding,
        children: const [
          TroskySkeleton(
            width: double.infinity,
            height: 150,
            radius: TroskyRadii.r20,
          ),
          SizedBox(height: TroskySpacing.s14),
          TroskySkeleton(
            width: double.infinity,
            height: 170,
            radius: TroskyRadii.r20,
          ),
        ],
      );
    }
    final booking = shown.booking;
    final trip = shown.trip;
    final summary = booking.trip;
    final departs = trip?.scheduledDepartureAt ?? summary?.scheduledDepartureAt;
    final arrives = trip?.scheduledArrivalAt;
    final seats = seatNumbersFrom(
      booking,
      ref.watch(tripSeatsProvider(booking.tripId)).value,
    );
    final refund = refundLine(l10n, booking);
    return RefreshIndicator(
      color: TroskyColors.green,
      onRefresh: () =>
          ref.refresh(_details.future).then((_) {}, onError: (Object _) {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          TroskyJourneyCard(
            day: departs == null
                ? ''
                : DateFormat(
                    'EEE d MMM',
                    l10n.localeName,
                  ).format(departs.toLocal()),
            duration: departs == null || arrives == null
                ? null
                : l10n.bookingAboutMinutes(
                    arrives.difference(departs).inMinutes,
                  ),
            from: booking.boardingStopName ?? summary?.originStopName ?? '',
            fromTime: departs == null ? '' : clockTime(departs),
            to: booking.alightingStopName ?? summary?.destinationStopName ?? '',
            toTime: arrives == null
                ? null
                : l10n.bookingArrival(clockTime(arrives)),
          ),
          const SizedBox(height: TroskySpacing.s14),
          _VehicleCard(
            booking: booking,
            trip: trip,
            seats: seats == null ? '…' : seatList(l10n, seats),
          ),
          const SizedBox(height: TroskySpacing.s14),
          _FareCard(booking: booking),
          if (refund != null) ...[
            const SizedBox(height: TroskySpacing.s14),
            TroskyRefundNote(text: refund),
          ],
        ],
      ),
    );
  }

  /// The status's actions at the bottom, as the design's variants.
  Widget _actions(
    AppLocalizations l10n,
    BookingDetails shown,
    BookingChip chip,
  ) {
    final booking = shown.booking;
    final main = chip.canPay
        ? l10n.bookingPayNow
        : chip.canViewStatus
        ? l10n.bookingViewStatus
        : null;
    if (main == null && !chip.canCancel) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TroskyColors.surface,
        border: Border(top: BorderSide(color: TroskyColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s18,
            TroskySpacing.s12,
            TroskySpacing.s18,
            TroskySpacing.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (main != null)
                TroskyButton(
                  label: main,
                  variant: TroskyButtonVariant.primary,
                  onPressed: () => _payment(booking),
                ),
              if (chip.canCancel)
                TroskyTextLink(
                  prompt: '',
                  action: l10n.cancelConfirm,
                  actionColor: TroskyColors.red,
                  actionStyle: TroskyTypography.body13Bold,
                  onPressed: () => _cancel(shown),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "VEHICLE & DRIVER", then the seats and how many passengers.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.booking,
    required this.trip,
    required this.seats,
  });

  final BookingResponse booking;
  final TripDetailResponse? trip;
  final String seats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = trip?.vehicle;
    final driver = trip?.driver;
    final plate =
        vehicle?.registrationNumber ??
        booking.trip?.vehicleRegistrationNumber ??
        '';
    final rating = driver?.averageRating?.toStringAsFixed(1);
    return TroskyDetailsCard(
      label: l10n.bookingVehicleDriver,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TroskyColors.greenA10,
                  borderRadius: BorderRadius.circular(TroskyRadii.r12),
                ),
                alignment: Alignment.center,
                child: TroskyIcons.vehicle(color: TroskyColors.green),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate,
                      style: TroskyTypography.heading15Bold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                    if (vehicle?.makeModel case final model?)
                      Text(
                        model,
                        style: TroskyTypography.body12Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (driver?.fullName case final name?)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      style: TroskyTypography.heading14Bold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                    if (rating != null)
                      Semantics(
                        label: l10n.bookingDriverRated(rating),
                        excludeSemantics: true,
                        child: Text(
                          '★ $rating',
                          style: TroskyTypography.body12SemiBold.copyWith(
                            color: TroskyColors.goldText,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: TroskySpacing.s14),
          const Divider(height: 1, color: TroskyColors.border),
          const SizedBox(height: TroskySpacing.s14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TroskyDetailsLabel(l10n.bookingSeats, bold: false),
                    const SizedBox(height: TroskySpacing.s2),
                    Text(
                      seats,
                      style: TroskyTypography.heading15Bold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              TroskyChip(
                label: l10n.bookingPassengers(booking.passengerCount),
                color: TroskyChipColor.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "FARE BREAKDOWN": seats times the fare, the service fee, the total.
/// The design's "PAID WITH" isn't shown: the booking doesn't say how it
/// was paid (backend gap G35).
class _FareCard extends StatelessWidget {
  const _FareCard({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = booking.passengerCount;
    final fare = double.parse(booking.fareAmount);
    final perSeat = (count == 0 ? fare : fare / count).toStringAsFixed(2);
    final fee = double.parse(booking.platformFee);
    Widget line(String label, String amount) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
        ),
        Text(
          amount,
          style: TroskyTypography.body14Bold.copyWith(color: TroskyColors.ink),
        ),
      ],
    );
    return TroskyDetailsCard(
      label: l10n.bookingFareBreakdown,
      child: Column(
        children: [
          line(
            l10n.bookingFareLine(count, cedis(l10n, perSeat)),
            cedis(l10n, booking.fareAmount),
          ),
          if (fee > 0) ...[
            const SizedBox(height: TroskySpacing.s8),
            line(l10n.bookingServiceFee, cedis(l10n, booking.platformFee)),
          ],
          const SizedBox(height: TroskySpacing.s14),
          const Divider(height: 1, color: TroskyColors.border),
          const SizedBox(height: TroskySpacing.s12),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TroskyDetailsLabel(l10n.paymentTotal, bold: false),
                Text(
                  cedis(l10n, booking.totalAmount),
                  style: TroskyTypography.heading26ExtraBold.copyWith(
                    color: TroskyColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// After a cancel (P-16's "Booking cancelled"), or when it waits for
/// TroSky because the trip had started (not in the design).
class _Cancelled extends StatelessWidget {
  const _Cancelled({required this.outcome, required this.onDone});

  final CancelOutcome outcome;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requested = outcome.requested;
    final refund = refundLine(l10n, outcome.booking);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TroskySpacing.s20,
              0,
              TroskySpacing.s20,
              TroskySpacing.s16,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TroskyStatusTile(
                            color: requested
                                ? TroskyColors.amberA15
                                : TroskyColors.greenA10,
                            icon: requested
                                ? TroskyIcons.clock(
                                    color: TroskyColors.goldText,
                                    size: 36,
                                  )
                                : TroskyIcons.checkCircle(
                                    color: TroskyColors.green,
                                  ),
                          ),
                          const SizedBox(height: TroskySpacing.s20),
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              requested
                                  ? l10n.cancelRequestedTitle
                                  : l10n.cancelledTitle,
                              textAlign: TextAlign.center,
                              style: TroskyTypography.heading24ExtraBold
                                  .copyWith(color: TroskyColors.ink),
                            ),
                          ),
                          const SizedBox(height: TroskySpacing.s8),
                          Text(
                            requested
                                ? l10n.cancelRequestedBody
                                : l10n.cancelledBody,
                            textAlign: TextAlign.center,
                            style: TroskyTypography.body14Regular.copyWith(
                              color: TroskyColors.textSecondary,
                            ),
                          ),
                          if (refund != null) ...[
                            const SizedBox(height: TroskySpacing.s20),
                            TroskyRefundNote(text: refund, prominent: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                TroskyButton(
                  label: l10n.cancelledBackToTrips,
                  variant: TroskyButtonVariant.primary,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
