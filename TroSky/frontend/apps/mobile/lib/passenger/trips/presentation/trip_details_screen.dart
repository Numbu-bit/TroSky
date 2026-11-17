// P-04 (derived). No Figma export: layout is derived from the
// Payment / Ticket / Booking details screens — same tokens, same card
// radius, same type scale, same spacing. Opens from Booking details
// when TRIP_DETAILS_ENABLED is on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/cancel_booking_sheet.dart';
import '../application/trip_details_providers.dart';
import '../domain/ticket_args.dart';
import '../domain/trip_details_args.dart';

/// P-04 Trip details (derived).
class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.args});

  final TripDetailsArgs args;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(telemetryProvider)
          .emit(
            TelemetryEvent('trip_details_opened', {
              'from': widget.args.source.payload,
            }),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = widget.args.booking;
    final tripAsync = ref.watch(tripDetailsProvider(booking.tripId));
    return Scaffold(
      backgroundColor: TroskyColors.background,
      body: Column(
        children: [
          _Header(booking: booking),
          Expanded(
            child: tripAsync.when(
              loading: () => const _LoadingBody(),
              error: (error, _) => _ErrorBody(
                message: _messageFor(l10n, error),
                onRetry: () =>
                    ref.invalidate(tripDetailsProvider(booking.tripId)),
              ),
              data: (trip) => _Body(booking: booking, trip: trip),
            ),
          ),
          _Actions(booking: booking),
        ],
      ),
    );
  }

  String _messageFor(AppLocalizations l10n, Object error) {
    if (error is NetworkFailure) return l10n.tripDetailsOffline;
    if (error is AppFailure) {
      if (error.statusCode == 404) return l10n.tripDetailsNotFound;
      if (error.statusCode != null && error.statusCode! >= 500) {
        return l10n.tripDetailsServerError;
      }
    }
    return l10n.tripDetailsServerError;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = booking.trip;
    final from = booking.boardingStopName ?? trip?.originStopName ?? '';
    final to = booking.alightingStopName ?? trip?.destinationStopName ?? '';
    return DecoratedBox(
      decoration: BoxDecoration(gradient: TroskyGradients.navyHeader),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s16,
            TroskySpacing.s8,
            TroskySpacing.s20,
            TroskySpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(TroskySpacing.s8),
                    child: Icon(
                      Icons.chevron_left,
                      color: TroskyColors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TroskySpacing.s4),
              Text(
                l10n.tripDetailsTitle,
                style: TroskyTypography.body12SemiBoldH133.copyWith(
                  color: TroskyColors.whiteA55,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: TroskySpacing.s4),
              Text(
                '$from → $to',
                style: TroskyTypography.heading22ExtraBold.copyWith(
                  color: TroskyColors.white,
                ),
              ),
              const SizedBox(height: TroskySpacing.s10),
              _StatusPill(booking: booking),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = _labelAndColor(l10n, booking);
    return TroskyChip(label: label, color: color);
  }

  (String, TroskyChipColor) _labelAndColor(
    AppLocalizations l10n,
    BookingResponse booking,
  ) {
    if (booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.refundPending ||
        booking.status == BookingStatus.refunded ||
        booking.status == BookingStatus.expired) {
      return (l10n.tripDetailsStatusCancelled, TroskyChipColor.red);
    }
    final tripStatus = booking.trip?.status;
    switch (tripStatus) {
      case TripStatus.boarding:
      case TripStatus.inProgress:
      case TripStatus.paused:
        return (l10n.tripDetailsStatusOnTheWay, TroskyChipColor.green);
      case TripStatus.completed:
        return (l10n.tripDetailsStatusArrived, TroskyChipColor.blue);
      case TripStatus.cancelled:
        return (l10n.tripDetailsStatusCancelled, TroskyChipColor.red);
      case TripStatus.scheduled:
      case null:
        return (l10n.tripDetailsStatusUpcoming, TroskyChipColor.gray);
    }
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TroskySpacing.s20),
      children: const [
        _Skeleton(height: 96),
        SizedBox(height: TroskySpacing.s14),
        _Skeleton(height: 120),
        SizedBox(height: TroskySpacing.s14),
        _Skeleton(height: 72),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: TroskyColors.border,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.ticketRetry,
              variant: TroskyButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.trip});

  final BookingResponse booking;
  final TripDetailResponse trip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TroskySpacing.s20),
      children: [
        _ScheduleCard(trip: trip),
        const SizedBox(height: TroskySpacing.s14),
        _StopsCard(booking: booking, trip: trip),
        const SizedBox(height: TroskySpacing.s14),
        _VehicleCard(trip: trip),
        const SizedBox(height: TroskySpacing.s14),
        _DriverCard(trip: trip),
        const SizedBox(height: TroskySpacing.s14),
        _YourSeatsCard(booking: booking),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
      ),
      padding: const EdgeInsets.all(TroskySpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TroskyTypography.body12SemiBoldH133.copyWith(
              color: TroskyColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          child,
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.trip});

  final TripDetailResponse trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final departs = trip.scheduledDepartureAt;
    final arrives = trip.scheduledArrivalAt;
    final day = DateFormat(
      'EEE d MMM',
      l10n.localeName,
    ).format(departs.toLocal());
    final clock = DateFormat('HH:mm', l10n.localeName);
    final duration = arrives == null
        ? '—'
        : _durationLabel(arrives.difference(departs));
    return _Card(
      title: l10n.tripDetailsSchedule,
      child: Column(
        children: [
          _Row(label: day, value: ''),
          _Row(
            label: l10n.tripDetailsDeparts,
            value: clock.format(departs.toLocal()),
          ),
          if (arrives != null)
            _Row(
              label: l10n.tripDetailsArrives,
              value: clock.format(arrives.toLocal()),
            ),
          _Row(label: l10n.tripDetailsDuration, value: duration),
        ],
      ),
    );
  }

  String _durationLabel(Duration d) {
    final mins = d.inMinutes;
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s4),
      child: Row(
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
            value,
            style: TroskyTypography.body14SemiBold.copyWith(
              color: TroskyColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopsCard extends StatelessWidget {
  const _StopsCard({required this.booking, required this.trip});

  final BookingResponse booking;
  final TripDetailResponse trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Full ordered stops from the backend (PR #89). Falls back to
    // origin/destination when the list is empty (older backend, cached
    // response from before the migration): keeps the card useful rather
    // than empty.
    final stops = trip.stops.isNotEmpty
        ? trip.stops
        : <StopResponse>[
            StopResponse(
              id: trip.originStopId,
              name: trip.originStopName,
              latitude: 0,
              longitude: 0,
            ),
            StopResponse(
              id: trip.destinationStopId,
              name: trip.destinationStopName,
              latitude: 0,
              longitude: 0,
            ),
          ];
    // The passenger's own boarding stop: match the booking's own origin
    // id first, then fall back to the trip's origin (first stop). Owner
    // noted in the task that a first-stop fallback is OK — called out
    // in the PR body.
    final boardingStopId = booking.originStopId ?? stops.first.id;
    final alightingStopId = booking.destinationStopId ?? stops.last.id;
    return _Card(
      title: l10n.tripDetailsStops,
      child: Semantics(
        container: true,
        label: l10n.tripDetailsStops,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stops.length; i++)
              _StopRow(
                name: stops[i].name,
                isPassengerStop: stops[i].id == boardingStopId,
                tag: _tagFor(
                  l10n,
                  stops[i].id,
                  boardingStopId,
                  alightingStopId,
                ),
                isFirst: i == 0,
                isLast: i == stops.length - 1,
                sequenceLabel: l10n.tripDetailsStopSemantics(
                  i + 1,
                  stops.length,
                  stops[i].name,
                  stops[i].id == boardingStopId
                      ? l10n.tripDetailsStopBoardingSemantic
                      : l10n.tripDetailsStopRegularSemantic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _tagFor(
    AppLocalizations l10n,
    String stopId,
    String boardingId,
    String alightingId,
  ) {
    if (stopId == boardingId) return l10n.tripDetailsStopBoardingTag;
    if (stopId == alightingId) return l10n.tripDetailsStopAlightingTag;
    return null;
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.name,
    required this.isPassengerStop,
    required this.tag,
    required this.isFirst,
    required this.isLast,
    required this.sequenceLabel,
  });

  final String name;
  final bool isPassengerStop;
  final String? tag;
  final bool isFirst;
  final bool isLast;
  final String sequenceLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: sequenceLabel,
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? TroskyColors.transparent
                          : TroskyColors.border,
                    ),
                  ),
                  Container(
                    width: isPassengerStop ? 14 : 10,
                    height: isPassengerStop ? 14 : 10,
                    decoration: BoxDecoration(
                      color: isPassengerStop
                          ? TroskyColors.green
                          : TroskyColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? TroskyColors.transparent
                          : TroskyColors.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TroskySpacing.s10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TroskySpacing.s10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: isPassengerStop
                            ? TroskyTypography.body14SemiBold.copyWith(
                                color: TroskyColors.textPrimary,
                              )
                            : TroskyTypography.body14Regular.copyWith(
                                color: TroskyColors.textSecondary,
                              ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: TroskySpacing.s8),
                      TroskyChip(label: tag!, color: TroskyChipColor.green),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.trip});

  final TripDetailResponse trip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehicle = trip.vehicle;
    if (vehicle == null) return const SizedBox.shrink();
    final typeLabel = _vehicleTypeLabel(vehicle.type);
    return _Card(
      title: l10n.tripDetailsVehicle,
      child: Column(
        children: [
          _Row(label: typeLabel, value: vehicle.makeModel ?? ''),
          _Row(label: l10n.tripDetailsPlate, value: vehicle.registrationNumber),
        ],
      ),
    );
  }

  String _vehicleTypeLabel(VehicleType type) => switch (type) {
    VehicleType.minibus => 'Minibus',
    VehicleType.shuttle => 'Shuttle',
    VehicleType.sedan => 'Sedan',
    VehicleType.bus => 'Bus',
    VehicleType.other => 'Vehicle',
  };
}

class _DriverCard extends ConsumerWidget {
  const _DriverCard({required this.trip});

  final TripDetailResponse trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final driver = trip.driver;
    if (driver == null) return const SizedBox.shrink();
    final name = driver.fullName ?? '';
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '';
    // Live phone, gated by the backend to callers with a confirmed /
    // completed booking on this trip (null otherwise). Kept in a local
    // so the render path never touches the field name twice.
    final phone = driver.phoneNumber;
    return _Card(
      title: l10n.tripDetailsDriver,
      child: Row(
        children: [
          Semantics(
            label: name,
            image: true,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: TroskyColors.navy,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: TroskySpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TroskyTypography.body16Regular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: TroskyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: TroskySpacing.s2),
                Text(
                  driver.averageRating == null || driver.ratingCount == 0
                      ? l10n.tripDetailsDriverUnrated
                      : l10n.tripDetailsDriverRating(
                          driver.averageRating.toString(),
                          driver.ratingCount,
                        ),
                  style: TroskyTypography.body13Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
                _VerificationPill(status: driver.verificationStatus),
              ],
            ),
          ),
          if (phone == null)
            Text(
              l10n.tripDetailsDriverContactUnavailable,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textMuted,
              ),
            )
          else
            _DriverContactButtons(phone: phone),
        ],
      ),
    );
  }
}

class _DriverContactButtons extends ConsumerWidget {
  const _DriverContactButtons({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Future<void> launchTel() async {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('trip_call_driver_tapped'));
      await launchUrl(Uri(scheme: 'tel', path: phone));
    }

    Future<void> launchSms() async {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('trip_message_driver_tapped'));
      await launchUrl(Uri(scheme: 'sms', path: phone));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconAction(
          icon: Icons.phone,
          label: l10n.tripDetailsCallDriver,
          onTap: launchTel,
        ),
        const SizedBox(width: TroskySpacing.s8),
        _IconAction(
          icon: Icons.chat_bubble_outline,
          label: l10n.tripDetailsMessageDriver,
          onTap: launchSms,
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TroskyColors.border,
            borderRadius: BorderRadius.circular(TroskyRadii.full),
          ),
          child: Icon(icon, size: 20, color: TroskyColors.navy),
        ),
      ),
    );
  }
}

/// Small pill under the driver's name. `verified` -> brand green;
/// `pending` -> muted; `rejected` / `unverified` -> hidden (nothing to
/// reassure the passenger with, and showing "Rejected" in the UI is
/// an admin signal, not a passenger-facing one).
class _VerificationPill extends StatelessWidget {
  const _VerificationPill({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color, semantics) = switch (status) {
      VerificationStatus.verified => (
        l10n.tripDetailsDriverVerified,
        TroskyChipColor.green,
        l10n.tripDetailsDriverVerifiedSemantics,
      ),
      VerificationStatus.pending => (
        l10n.tripDetailsDriverVerificationPending,
        TroskyChipColor.gray,
        l10n.tripDetailsDriverVerificationPendingSemantics,
      ),
      VerificationStatus.unverified ||
      VerificationStatus.rejected => (null, null, null),
    };
    if (label == null || color == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TroskySpacing.s4),
      child: Semantics(
        label: semantics,
        container: true,
        child: TroskyChip(label: label, color: color),
      ),
    );
  }
}

class _YourSeatsCard extends StatelessWidget {
  const _YourSeatsCard({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      title: l10n.tripDetailsYourSeats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in booking.passengers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s4),
              child: Text(
                l10n.tripDetailsSeatRow(p.seatId, p.fullName),
                style: TroskyTypography.body14Regular.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.booking});

  final BookingResponse booking;

  bool get _canCancel =>
      booking.status == BookingStatus.pending ||
      booking.status == BookingStatus.paymentPending ||
      booking.status == BookingStatus.confirmed;

  bool get _canShowTicket =>
      booking.status == BookingStatus.confirmed ||
      booking.status == BookingStatus.completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
              Row(
                children: [
                  Expanded(
                    child: TroskyButton(
                      label: l10n.tripDetailsTrackTrip,
                      variant: TroskyButtonVariant.primary,
                      onPressed: () => _onTrack(context, ref, l10n),
                    ),
                  ),
                  if (_canShowTicket) ...[
                    const SizedBox(width: TroskySpacing.s12),
                    Expanded(
                      child: TroskyButton(
                        label: l10n.bookingShowTicket,
                        variant: TroskyButtonVariant.outline,
                        onPressed: () => _onShowTicket(context),
                      ),
                    ),
                  ],
                ],
              ),
              if (_canCancel)
                Padding(
                  padding: const EdgeInsets.only(top: TroskySpacing.s8),
                  child: TroskyTextLink(
                    prompt: '',
                    action: l10n.tripDetailsCancelBooking,
                    actionColor: TroskyColors.red,
                    actionStyle: TroskyTypography.body13Bold,
                    onPressed: () => _onCancel(context, ref),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTrack(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    ref.read(telemetryProvider).emit(TelemetryEvent('trip_track_tapped'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tripDetailsTrackComingSoon)));
  }

  void _onShowTicket(BuildContext context) {
    context.pushNamed(
      AppRoute.ticket.name,
      pathParameters: {'bookingId': booking.id},
      extra: TicketArgs(booking: booking),
    );
  }

  Future<void> _onCancel(BuildContext context, WidgetRef ref) async {
    ref.read(telemetryProvider).emit(TelemetryEvent('trip_cancel_tapped'));
    await showCancelBookingSheet(
      context,
      booking: booking,
      tripStatus: booking.trip?.status,
    );
  }
}
