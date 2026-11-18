import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../../safety/domain/safety_args.dart';
import '../application/tracking_providers.dart';
import '../data/trip_tracking_service.dart';
import '../domain/track_status.dart';
import '../domain/track_trip_args.dart';

/// P-11 Live tracking. Full-screen map under a navy bottom card.
class TrackTripScreen extends ConsumerStatefulWidget {
  const TrackTripScreen({super.key, required this.args});

  final TrackTripArgs args;

  @override
  ConsumerState<TrackTripScreen> createState() => _TrackTripScreenState();
}

class _TrackTripScreenState extends ConsumerState<TrackTripScreen>
    with WidgetsBindingObserver {
  final MapController _map = MapController();
  StreamSubscription<TripTrackingUpdate>? _sub;
  LatLng? _busPosition;
  TripTrackingSource _source = TripTrackingSource.webSocket;
  LiveLocationResponse? _location;
  DateTime _lastRepaint = DateTime.fromMillisecondsSinceEpoch(0);

  // 10 Hz paint cap: drop ticks that arrive faster.
  static const _minRepaintGap = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscribe();
      ref.read(telemetryProvider).emit(TelemetryEvent('track_trip_opened'));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = ref.read(tripTrackingServiceProvider(widget.args.trip.id));
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      service.pause();
    } else if (state == AppLifecycleState.resumed) {
      service.resume();
    }
  }

  void _subscribe() {
    final service = ref.read(tripTrackingServiceProvider(widget.args.trip.id));
    _sub = service.start(widget.args.trip.id).listen(_onUpdate);
  }

  void _onUpdate(TripTrackingUpdate update) {
    final now = DateTime.now();
    if (now.difference(_lastRepaint) < _minRepaintGap) return;
    _lastRepaint = now;
    setState(() {
      _busPosition = LatLng(
        update.location.latitude,
        update.location.longitude,
      );
      _location = update.location;
      final nowSource = update.source;
      if (_source != nowSource) {
        if (nowSource == TripTrackingSource.pollFallback) {
          ref
              .read(telemetryProvider)
              .emit(
                TelemetryEvent('track_trip_ws_fallback_to_poll', {
                  'after_seconds': 5,
                }),
              );
        } else {
          ref
              .read(telemetryProvider)
              .emit(TelemetryEvent('track_trip_ws_connected'));
        }
        _source = nowSource;
      }
    });
  }

  LatLng _destination() {
    // Destination coords: take the matching stop from trip.stops (PR #90
    // wire-up), else fall back to origin.
    for (final s in widget.args.trip.stops) {
      if (s.id == widget.args.trip.destinationStopId) {
        return LatLng(s.latitude, s.longitude);
      }
    }
    final stops = widget.args.trip.stops;
    if (stops.isNotEmpty) {
      return LatLng(stops.last.latitude, stops.last.longitude);
    }
    return const LatLng(5.56, -0.2); // Accra fallback
  }

  double _distanceM(LatLng from, LatLng to) {
    const r = 6371000.0;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(from.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _recentre() {
    final bus = _busPosition;
    if (bus == null) return;
    final dest = _destination();
    final bounds = LatLngBounds.fromPoints([bus, dest]);
    _map.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('track_trip_recenter_tapped'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(envProvider);
    final etaAsync = ref.watch(tripEtaProvider(widget.args.trip.id));
    final now = ref.watch(clockProvider)();
    final destination = _destination();
    final eta = etaAsync.value;
    final distanceM = _busPosition != null
        ? _distanceM(_busPosition!, destination)
        : double.infinity;
    final status = trackStatusFor(
      tripStatus: _location?.tripStatus ?? widget.args.trip.status,
      departureAt: widget.args.trip.scheduledDepartureAt,
      distanceToDestinationMeters: distanceM,
      etaMinutes: eta?.durationMinutes ?? 0,
      etaAt: eta?.etaAt ?? now,
      now: now,
    );

    return Scaffold(
      backgroundColor: TroskyColors.navyDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: l10n.trackTripSemanticsMap(status.etaMinutes ?? 0),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _busPosition ?? destination,
                  initialZoom: 13,
                  minZoom: 5,
                  maxZoom: 18,
                  backgroundColor: TroskyColors.background,
                ),
                children: [
                  TileLayer(
                    urlTemplate: env.mapTileUrl,
                    userAgentPackageName: 'com.trosky.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      if (_busPosition != null)
                        Polyline(
                          points: [_busPosition!, destination],
                          color: TroskyColors.green,
                          strokeWidth: 3,
                          pattern: StrokePattern.dashed(
                            segments: const [10, 6],
                          ),
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: destination,
                        width: 44,
                        height: 44,
                        child: const _DestinationPin(),
                      ),
                      if (_busPosition case final bus?)
                        Marker(
                          point: bus,
                          width: 44,
                          height: 44,
                          child: const _BusPin(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TroskySpacing.s16,
                  TroskySpacing.s12,
                  TroskySpacing.s16,
                  0,
                ),
                child: _StatusChip(status: status),
              ),
            ),
          ),
          if (_source == TripTrackingSource.pollFallback)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: _FallbackBanner(message: l10n.trackTripFallbackBanner),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomCard(
              booking: widget.args.booking,
              trip: widget.args.trip,
              liveFare: _location?.liveFarePerSeat,
              ridersCount:
                  _location?.ridersCount ?? widget.args.trip.ridersCount,
              onShare: _share,
              onSos: () => _openSos(context),
              onCall: _callDriver,
              onMessage: _messageDriver,
            ),
          ),
          Positioned(
            right: TroskySpacing.s16,
            bottom: 280,
            child: Semantics(
              button: true,
              label: l10n.trackTripRecenter,
              child: FloatingActionButton.small(
                heroTag: 'recentre',
                onPressed: _recentre,
                backgroundColor: TroskyColors.surface,
                foregroundColor: TroskyColors.navy,
                child: const Icon(Icons.my_location),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final seat = widget.args.booking.passengers.isNotEmpty
        ? widget.args.booking.passengers.first.seatId
        : '';
    final plate = widget.args.trip.vehicle?.registrationNumber ?? '';
    final time = DateFormat('HH:mm', l10n.localeName).format(
      ref.read(tripEtaProvider(widget.args.trip.id)).value?.etaAt ??
          widget.args.trip.scheduledArrivalAt ??
          widget.args.trip.scheduledDepartureAt,
    );
    final text = l10n.trackTripShareText(
      '${widget.args.trip.originStopName} → '
      '${widget.args.trip.destinationStopName}',
      time,
      seat,
      plate,
    );
    ref.read(telemetryProvider).emit(TelemetryEvent('track_trip_share_tapped'));
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _openSos(BuildContext context) async {
    ref.read(telemetryProvider).emit(TelemetryEvent('track_trip_sos_tapped'));
    if (sosEnabled) {
      await context.pushNamed(
        AppRoute.sosAlert.name,
        extra: SosArgs(
          tripId: widget.args.trip.id,
          booking: widget.args.booking,
        ),
      );
      return;
    }
    // Fallback (prod until SOS_ENABLED=true): the original Call 191 sheet.
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TroskyColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s20,
            TroskySpacing.s8,
            TroskySpacing.s20,
            TroskySpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.trackTripSosTitle,
                style: TroskyTypography.heading22ExtraBold,
              ),
              const SizedBox(height: TroskySpacing.s8),
              Text(
                l10n.trackTripSosBody,
                style: TroskyTypography.body14Regular,
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.trackTripSosCall,
                variant: TroskyButtonVariant.danger,
                onPressed: () async {
                  await launchUrl(Uri(scheme: 'tel', path: '191'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    final phone = widget.args.trip.driver?.phoneNumber;
    if (phone == null) return;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('track_trip_call_driver_tapped'));
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _messageDriver() async {
    final phone = widget.args.trip.driver?.phoneNumber;
    if (phone == null) return;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('track_trip_message_driver_tapped'));
    await launchUrl(Uri(scheme: 'sms', path: phone));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TrackStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, time) = switch (status.kind) {
      TrackStatusKind.boardingAtOrigin => (
        l10n.trackTripStatusBoardingAtOrigin,
        null,
      ),
      TrackStatusKind.arrivingIn => (
        l10n.trackTripStatusArrivingIn(status.etaMinutes ?? 0),
        status.etaAt == null
            ? null
            : l10n.trackTripEta(
                DateFormat(
                  'HH:mm',
                  l10n.localeName,
                ).format(status.etaAt!.toLocal()),
              ),
      ),
      TrackStatusKind.atYourStop => (l10n.trackTripStatusAtYourStop, null),
      TrackStatusKind.completed => (l10n.trackTripStatusCompleted, null),
    };
    return Semantics(
      label: '$label${time == null ? '' : ', $time'}',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: TroskyColors.navyDeep,
          borderRadius: BorderRadius.circular(TroskyRadii.full),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: TroskySpacing.s16,
          vertical: TroskySpacing.s10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: TroskyColors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: TroskySpacing.s8),
            Text(
              label,
              style: TroskyTypography.body14SemiBold.copyWith(
                color: TroskyColors.white,
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: TroskySpacing.s12),
              Text(
                time,
                style: TroskyTypography.body14Regular.copyWith(
                  color: TroskyColors.whiteA55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TroskySpacing.s12,
          vertical: TroskySpacing.s6,
        ),
        decoration: BoxDecoration(
          color: TroskyColors.amberA15,
          borderRadius: BorderRadius.circular(TroskyRadii.full),
        ),
        child: Text(
          message,
          style: TroskyTypography.body12SemiBoldH133.copyWith(
            color: TroskyColors.goldText,
          ),
        ),
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.green,
        borderRadius: BorderRadius.circular(TroskyRadii.full),
      ),
      padding: const EdgeInsets.all(TroskySpacing.s6),
      child: const Icon(Icons.location_on, color: TroskyColors.white, size: 20),
    );
  }
}

class _BusPin extends StatelessWidget {
  const _BusPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.green,
        borderRadius: BorderRadius.circular(TroskyRadii.full),
        boxShadow: const [
          BoxShadow(color: TroskyColors.navy, blurRadius: 6, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(TroskySpacing.s6),
      child: const Icon(
        Icons.directions_bus,
        color: TroskyColors.white,
        size: 20,
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.booking,
    required this.trip,
    required this.liveFare,
    required this.ridersCount,
    required this.onShare,
    required this.onSos,
    required this.onCall,
    required this.onMessage,
  });

  final BookingResponse booking;
  final TripDetailResponse trip;
  final double? liveFare;
  final int? ridersCount;
  final Future<void> Function() onShare;
  final Future<void> Function() onSos;
  final Future<void> Function() onCall;
  final Future<void> Function() onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = trip.driver;
    final name = driver?.fullName ?? '';
    final plate = trip.vehicle?.registrationNumber ?? '';
    final type = trip.vehicle?.type.name ?? '';
    final seat = booking.passengers.isNotEmpty
        ? booking.passengers.first.seatId
        : '';
    final fareLabel = liveFare == null
        ? '…'
        : '₵${liveFare!.toStringAsFixed(2)}';
    final ridersLabel = l10n.trackTripRidersOf(
      ridersCount ?? trip.ridersCount,
      trip.seatsTotal,
    );
    return Container(
      decoration: const BoxDecoration(
        color: TroskyColors.navyDeep,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TroskyRadii.r24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s20,
        TroskySpacing.s12,
        TroskySpacing.s20,
        TroskySpacing.s16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TroskyColors.whiteA30,
                borderRadius: BorderRadius.circular(TroskyRadii.full),
              ),
            ),
            const SizedBox(height: TroskySpacing.s16),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: TroskyColors.whiteA10,
                  child: Text(
                    name.isNotEmpty ? name.characters.first.toUpperCase() : '',
                    style: TroskyTypography.heading20Bold.copyWith(
                      color: TroskyColors.white,
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
                          color: TroskyColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$plate · $type',
                        style: TroskyTypography.body13Regular.copyWith(
                          color: TroskyColors.whiteA55,
                        ),
                      ),
                    ],
                  ),
                ),
                _DarkIconButton(
                  icon: Icons.phone,
                  background: TroskyColors.green,
                  onPressed: driver?.phoneNumber == null ? null : onCall,
                ),
                const SizedBox(width: TroskySpacing.s8),
                _DarkIconButton(
                  icon: Icons.chat_bubble_outline,
                  background: TroskyColors.whiteA10,
                  onPressed: driver?.phoneNumber == null ? null : onMessage,
                ),
              ],
            ),
            const SizedBox(height: TroskySpacing.s16),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: l10n.trackTripLiveFare,
                    value: fareLabel,
                    valueColor: TroskyColors.amber,
                  ),
                ),
                const SizedBox(width: TroskySpacing.s8),
                Expanded(
                  child: _InfoTile(
                    label: l10n.trackTripRiders,
                    value: ridersLabel,
                    valueColor: TroskyColors.white,
                  ),
                ),
                const SizedBox(width: TroskySpacing.s8),
                Expanded(
                  child: _InfoTile(
                    label: l10n.trackTripSeat,
                    value: l10n.trackTripSeatValue(seat),
                    valueColor: TroskyColors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: TroskySpacing.s16),
            Row(
              children: [
                Expanded(
                  child: TroskyButton(
                    label: l10n.trackTripShare,
                    variant: TroskyButtonVariant.outline,
                    onPressed: onShare,
                  ),
                ),
                const SizedBox(width: TroskySpacing.s12),
                Expanded(
                  child: TroskyButton(
                    label: l10n.trackTripSos,
                    variant: TroskyButtonVariant.danger,
                    onPressed: onSos,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: TroskyColors.whiteA10,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
        ),
        padding: const EdgeInsets.all(TroskySpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.whiteA55,
              ),
            ),
            const SizedBox(height: TroskySpacing.s4),
            Text(
              value,
              style: TroskyTypography.body16Regular.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({
    required this.icon,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color background;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed == null ? null : () => unawaited(onPressed!()),
          child: Icon(icon, color: TroskyColors.white, size: 20),
        ),
      ),
    );
  }
}
