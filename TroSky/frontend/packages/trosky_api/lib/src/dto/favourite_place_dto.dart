// `/users/me/favourite-places/*` DTOs (step 21/close-stubs-C).
//
// Plain Dart classes (not freezed) matching backend/app/schemas/
// favourite_place.py. The POST schema accepts either `stop_id` or
// `latitude`+`longitude`; the Flutter client only submits `stop_id`
// today (destination picker reuses Search's stop autocomplete).

/// `FavouritePlaceKind` — home/work/custom. A user has at most one
/// `home` and one `work`; `custom` has no cardinality limit.
enum FavouritePlaceKind {
  home('home'),
  work('work'),
  custom('custom');

  const FavouritePlaceKind(this.wire);
  final String wire;

  static FavouritePlaceKind fromWire(String value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return FavouritePlaceKind.custom;
  }
}

/// A saved place. `stop_id` is nullable when the backend has only the
/// coordinates on file (e.g. a map-dropped pin before stops caught
/// up); in that case `stop_name` is also null and the UI falls back
/// to showing the lat/lng.
class FavouritePlaceResponse {
  const FavouritePlaceResponse({
    required this.id,
    required this.kind,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.stopId,
    this.stopName,
  });

  final String id;
  final FavouritePlaceKind kind;
  final String label;
  final String? stopId;
  final String? stopName;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FavouritePlaceResponse.fromJson(Map<String, dynamic> json) =>
      FavouritePlaceResponse(
        id: json['id'] as String,
        kind: FavouritePlaceKind.fromWire(json['kind'] as String),
        label: json['label'] as String,
        stopId: json['stop_id'] as String?,
        stopName: json['stop_name'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wire,
    'label': label,
    'stop_id': stopId,
    'stop_name': stopName,
    'latitude': latitude,
    'longitude': longitude,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// `POST /users/me/favourite-places`. `label` is required for
/// `custom` and defaults to "Home" / "Work" on the backend when
/// absent. Supply either `stopId` or (`latitude` + `longitude`); the
/// client sends `stopId` from the stop autocomplete today.
class FavouritePlaceCreateRequest {
  const FavouritePlaceCreateRequest({
    required this.kind,
    this.label,
    this.stopId,
    this.latitude,
    this.longitude,
  });

  final FavouritePlaceKind kind;
  final String? label;
  final String? stopId;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    if (label != null) 'label': label,
    if (stopId != null) 'stop_id': stopId,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

/// `PATCH /users/me/favourite-places/{id}` — only label is editable
/// from the mobile app today (Edit label on a custom place).
class FavouritePlaceUpdateRequest {
  const FavouritePlaceUpdateRequest({this.label});
  final String? label;
  Map<String, dynamic> toJson() => {if (label != null) 'label': label};
}

/// `TripShareLinkResponse` — `POST /bookings/{id}/share` reply (step
/// 21/close-stubs-C). The public URL `url` opens `/share/{token}`
/// without a TroSky account. `expiresAt` is backend-stamped UTC
/// (ISO-8601, suffix `Z`) and is roughly 12 h after mint.
class TripShareLinkResponse {
  const TripShareLinkResponse({
    required this.url,
    required this.token,
    required this.expiresAt,
  });

  final String url;
  final String token;
  final DateTime expiresAt;

  factory TripShareLinkResponse.fromJson(Map<String, dynamic> json) =>
      TripShareLinkResponse(
        url: json['url'] as String,
        token: json['token'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'url': url,
    'token': token,
    'expires_at': expiresAt.toIso8601String(),
  };
}
