import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';

/// The last nearby-stops answer, with the point it was asked for.
class CachedNearbyStop {
  const CachedNearbyStop({
    required this.position,
    required this.stop,
    required this.savedAt,
  });

  final LatLng position;

  /// Null when nothing was near.
  final NearbyStopResponse? stop;
  final DateTime savedAt;
}

/// What Home keeps on the device: whether location was asked for (it is
/// asked once), and the last answers, for low data and offline starts.
abstract interface class HomeStore {
  Future<bool> locationAsked();

  Future<void> markLocationAsked();

  Future<CachedNearbyStop?> readNearbyStop();

  Future<void> writeNearbyStop(CachedNearbyStop value);

  /// [userId]'s last favourite routes; null if none are saved for them.
  Future<List<FavouriteRouteResponse>?> readFavourites(String userId);

  Future<void> writeFavourites(
    String userId,
    List<FavouriteRouteResponse> routes,
  );
}

/// [HomeStore] in shared preferences. Holds nothing secret: stop names and
/// the passenger's own routes.
class SharedPreferencesHomeStore implements HomeStore {
  SharedPreferencesHomeStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const String locationAskedKey = 'home.location_asked';
  static const String nearbyStopKey = 'home.nearby_stop';
  static const String favouritesKey = 'home.favourite_routes';

  @override
  Future<bool> locationAsked() async =>
      await _preferences.getBool(locationAskedKey) ?? false;

  @override
  Future<void> markLocationAsked() =>
      _preferences.setBool(locationAskedKey, true);

  @override
  Future<CachedNearbyStop?> readNearbyStop() async {
    final json = await _read(nearbyStopKey);
    if (json == null) return null;
    try {
      final stop = json['stop'];
      return CachedNearbyStop(
        position: LatLng(
          (json['latitude']! as num).toDouble(),
          (json['longitude']! as num).toDouble(),
        ),
        stop: stop == null
            ? null
            : NearbyStopResponse.fromJson((stop as Map).cast()),
        savedAt: DateTime.parse(json['saved_at']! as String),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeNearbyStop(CachedNearbyStop value) =>
      _preferences.setString(
        nearbyStopKey,
        jsonEncode({
          'latitude': value.position.latitude,
          'longitude': value.position.longitude,
          'stop': value.stop?.toJson(),
          'saved_at': value.savedAt.toUtc().toIso8601String(),
        }),
      );

  @override
  Future<List<FavouriteRouteResponse>?> readFavourites(String userId) async {
    final json = await _read(favouritesKey);
    if (json == null || json['user_id'] != userId) return null;
    try {
      return [
        for (final route in json['routes']! as List)
          FavouriteRouteResponse.fromJson((route as Map).cast()),
      ];
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeFavourites(
    String userId,
    List<FavouriteRouteResponse> routes,
  ) => _preferences.setString(
    favouritesKey,
    jsonEncode({
      'user_id': userId,
      'routes': [for (final route in routes) route.toJson()],
    }),
  );

  Future<Map<String, Object?>?> _read(String key) async {
    final raw = await _preferences.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast();
    } on Object {
      // An older or damaged entry is just a missing one.
      return null;
    }
  }
}

/// [HomeStore] in memory, for tests.
class InMemoryHomeStore implements HomeStore {
  InMemoryHomeStore({this.asked = false});

  bool asked;
  CachedNearbyStop? nearbyStop;
  final Map<String, List<FavouriteRouteResponse>> favourites = {};

  @override
  Future<bool> locationAsked() async => asked;

  @override
  Future<void> markLocationAsked() async => asked = true;

  @override
  Future<CachedNearbyStop?> readNearbyStop() async => nearbyStop;

  @override
  Future<void> writeNearbyStop(CachedNearbyStop value) async =>
      nearbyStop = value;

  @override
  Future<List<FavouriteRouteResponse>?> readFavourites(String userId) async =>
      favourites[userId];

  @override
  Future<void> writeFavourites(
    String userId,
    List<FavouriteRouteResponse> routes,
  ) async => favourites[userId] = routes;
}
