import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

part 'trip_details_providers.g.dart';

/// `GET /api/v1/trips/{tripId}`. Returns the fresh [TripDetailResponse]
/// for a trip we have a booking on. Errors throw to the UI so the
/// screen can render the right state (offline / not-found / server
/// error).
@riverpod
Future<TripDetailResponse> tripDetails(Ref ref, String tripId) async {
  final repo = ref.watch(routeRepositoryProvider);
  final result = await repo.trip(tripId);
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
