// Stops and routes, field for field as in backend/app/schemas/route.py.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_dto.freezed.dart';
part 'route_dto.g.dart';

/// `NearbyStopResponse` from `GET /stops/nearby`: a `StopResponse` plus how
/// far it is from the point asked about.
@freezed
abstract class NearbyStopResponse with _$NearbyStopResponse {
  const factory NearbyStopResponse({
    required String id,
    required String name,
    String? code,
    String? address,
    String? city,
    String? region,
    required double latitude,
    required double longitude,

    /// Metres from the point asked about.
    required double distanceM,
  }) = _NearbyStopResponse;

  factory NearbyStopResponse.fromJson(Map<String, dynamic> json) =>
      _$NearbyStopResponseFromJson(json);
}
