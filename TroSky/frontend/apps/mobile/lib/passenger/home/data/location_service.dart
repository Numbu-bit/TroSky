import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Whether the app may read the phone's position.
enum LocationPermissionStatus {
  granted,

  /// Refused, but the phone will ask again.
  denied,

  /// Refused for good: only the phone's settings can change it.
  deniedForever,
}

/// The phone's location: permission and position. [GeolocatorLocationService]
/// in the app; tests use a fake.
abstract interface class LocationService {
  /// Whether the phone's location (GPS) is switched on at all.
  Future<bool> serviceEnabled();

  Future<LocationPermissionStatus> checkPermission();

  /// Shows the phone's own permission dialog.
  Future<LocationPermissionStatus> requestPermission();

  /// The phone's last fix, at once, if it has one. It may be old.
  Future<LatLng?> lastKnownPosition();

  /// A fresh fix, or null if none comes within a few seconds.
  Future<LatLng?> currentPosition();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

/// [LocationService] on the geolocator plugin.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Long enough for a first GPS fix outdoors; the map works without one.
  static const Duration fixTimeout = Duration(seconds: 10);

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      _status(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      _status(await Geolocator.requestPermission());

  @override
  Future<LatLng?> lastKnownPosition() async {
    try {
      return _latLng(await Geolocator.getLastKnownPosition());
    } on Exception {
      return null;
    }
  }

  @override
  Future<LatLng?> currentPosition() async {
    try {
      return _latLng(
        await Geolocator.getCurrentPosition(
          // City-block accuracy is enough for the nearest stop, and comes
          // faster and cheaper than a full GPS fix.
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: fixTimeout,
          ),
        ),
      );
    } on TimeoutException {
      return null;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static LatLng? _latLng(Position? position) =>
      position == null ? null : LatLng(position.latitude, position.longitude);

  static LocationPermissionStatus _status(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationPermissionStatus.granted,
        LocationPermission.deniedForever =>
          LocationPermissionStatus.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationPermissionStatus.denied,
      };
}
