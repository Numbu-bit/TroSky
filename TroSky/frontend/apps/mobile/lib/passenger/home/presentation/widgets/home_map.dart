import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/offline_banner.dart';
import '../../../../app/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/home_providers.dart';

/// A vehicle with this many free seats or fewer has the amber pin, as the
/// design's 2-seat one does.
const int fewSeats = 2;

/// The map on Home (P5), 220 px tall: OpenStreetMap tiles (decision 13),
/// the passenger's dot, vehicle pins (decision 14), my-location and SOS.
///
/// It never waits for location: without a position it shows Accra. When
/// the map, location or vehicles fail, the rest of Home carries on.
class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key});

  static const double height = 220;

  /// Vehicles move, so their pins are fetched again this often while Home
  /// is on screen.
  static const Duration refreshEvery = Duration(seconds: 30);

  static final Uri osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  final MapController _map = MapController();
  late final TileProvider _tiles = ref.read(mapTileProviderFactoryProvider)();
  bool _ready = false;
  Timer? _refresh;
  ValueListenable<TickerModeData>? _onScreen;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(HomeMap.refreshEvery, (_) => _refreshVehicles());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another tab is showing.
    _onScreen = TickerMode.getValuesNotifier(context);
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _refreshVehicles() {
    if (!mounted || !(_onScreen?.value.enabled ?? true)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final location = ref.read(locationControllerProvider);
    if (!location.settled) return;
    ref.invalidate(nearbyVehiclesProvider(location.position ?? accra));
  }

  void _moveTo(LatLng? position) {
    if (position != null && _ready) _map.move(position, _map.camera.zoom);
  }

  Future<void> _locate() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(locationControllerProvider.notifier);
    final outcome = await controller.locate();
    if (!mounted) return;
    final service = ref.read(locationServiceProvider);
    final (message, action) = switch (outcome) {
      LocateOutcome.located => (null, null),
      // The passenger just said no to the phone's dialog: nothing to add.
      LocateOutcome.denied => (null, null),
      LocateOutcome.notFound => (l10n.homeLocationNotFound, null),
      LocateOutcome.blocked => (
        l10n.homeLocationBlocked,
        service.openAppSettings,
      ),
      LocateOutcome.serviceOff => (
        l10n.homeLocationServiceOff,
        service.openLocationSettings,
      ),
    };
    if (outcome == LocateOutcome.located) {
      _moveTo(ref.read(locationControllerProvider).position);
    }
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action == null
              ? null
              : SnackBarAction(
                  label: l10n.homeOpenSettings,
                  onPressed: () => unawaited(action()),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(envProvider);
    final location = ref.watch(locationControllerProvider);
    final offline = ref.watch(
      sessionControllerProvider.select(
        (s) =>
            s.value is SessionAuthenticated &&
            (s.value! as SessionAuthenticated).offline,
      ),
    );
    ref.listen(locationControllerProvider.select((s) => s.position), (
      previous,
      next,
    ) {
      if (previous == null) _moveTo(next);
    });
    final centre = location.position ?? accra;
    // Wait for the position before asking, so one request does.
    final vehicles = location.settled
        ? ref.watch(nearbyVehiclesProvider(centre))
        : null;

    return SizedBox(
      height: HomeMap.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: homeMapZoom,
                minZoom: 6,
                maxZoom: 18,
                backgroundColor: TroskyColors.background,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
                onMapReady: () {
                  _ready = true;
                  final position = ref
                      .read(locationControllerProvider)
                      .position;
                  if (position != null && position != centre) {
                    _moveTo(position);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: env.mapTileUrl,
                  userAgentPackageName: 'com.trosky.app',
                  tileProvider: _tiles,
                ),
                MarkerLayer(
                  markers: [
                    for (final vehicle
                        in vehicles?.value ?? const <NearbyVehicleResponse>[])
                      _vehicleMarker(l10n, vehicle),
                    if (location.position case final position?)
                      Marker(
                        point: position,
                        width: TroskyLocationDot.size.width,
                        height: TroskyLocationDot.size.height,
                        child: TroskyLocationDot(
                          semanticsLabel: l10n.homeYouAreHere,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // The sheet covers the bottom 8 px of the map.
          const Positioned(left: 8, bottom: 12, child: _Attribution()),
          Positioned(
            right: 6,
            bottom: 58,
            child: TroskyMyLocationButton(
              semanticsLabel: l10n.homeMyLocation,
              onPressed: _locate,
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: TroskySosButton(
              label: l10n.homeSos,
              semanticsLabel: l10n.homeSosLabel,
              onPressed: () => context.pushNamed(AppRoute.sos.name),
            ),
          ),
          Positioned(
            top: TroskySpacing.s8,
            left: TroskySpacing.s12,
            right: TroskySpacing.s12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offline)
                  const OfflineBanner(floating: true)
                else if (vehicles?.hasError ?? false)
                  _VehiclesError(
                    message: l10n.homeVehiclesError,
                    retry: l10n.offlineRetry,
                    onRetry: () =>
                        ref.invalidate(nearbyVehiclesProvider(centre)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _vehicleMarker(AppLocalizations l10n, NearbyVehicleResponse vehicle) {
    final seats = vehicle.availableSeats;
    return Marker(
      key: ValueKey(vehicle.tripId),
      point: LatLng(vehicle.latitude, vehicle.longitude),
      width: TroskyBusPin.size.width,
      height: TroskyBusPin.size.height,
      child: TroskyBusPin(
        seats: seats,
        amber: seats <= fewSeats,
        semanticsLabel: l10n.homeVehicle(vehicle.routeName, seats),
      ),
    );
  }
}

/// "© OpenStreetMap contributors", required on every map using its data
/// (decision 13). Opens the copyright page.
class _Attribution extends StatelessWidget {
  const _Attribution();

  static const String text = '© OpenStreetMap contributors';

  static void _open() => unawaited(
    launchUrl(HomeMap.osmCopyright, mode: LaunchMode.externalApplication),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: text,
      onTap: _open,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s4,
            vertical: TroskySpacing.s1,
          ),
          decoration: BoxDecoration(
            color: TroskyColors.whiteA85,
            borderRadius: BorderRadius.circular(TroskyRadii.r4),
          ),
          child: Text(
            text,
            style: TroskyTypography.body10Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small card over the map when vehicles could not be loaded, with Retry.
class _VehiclesError extends StatelessWidget {
  const _VehiclesError({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  final String message;
  final String retry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.only(left: TroskySpacing.s12),
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
          boxShadow: TroskyShadows.mapFab,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message,
                style: TroskyTypography.body12Regular.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            TroskyTextLink(prompt: '', action: retry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
