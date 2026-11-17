import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../data/trip_tracking_service.dart';

part 'tracking_providers.g.dart';

/// Opens the realtime channel for one trip. Fresh per trip id; the
/// screen disposes it on unmount.
@riverpod
TripTrackingService tripTrackingService(Ref ref, String tripId) {
  final env = ref.watch(envProvider);
  final repo = ref.watch(trackingRepositoryProvider);
  final service = LiveTripTrackingService(
    env: env,
    repository: repo,
    accessToken: () async => ref.read(tokenManagerProvider).accessToken,
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Optional ETA fetch. Independent of the realtime stream so a WS tick
/// doesn't trigger an extra HTTP request.
@riverpod
Future<EtaResponse?> tripEta(Ref ref, String tripId) async {
  final repo = ref.watch(trackingRepositoryProvider);
  final result = await repo.tripEta(tripId);
  return switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };
}
