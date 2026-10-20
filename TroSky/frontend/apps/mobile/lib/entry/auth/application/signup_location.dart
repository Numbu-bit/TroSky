import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../passenger/home/application/home_providers.dart';
import '../../../passenger/home/data/location_service.dart';

part 'signup_location.g.dart';

/// Why a passenger's sign-up couldn't get the phone's position.
enum SignUpLocationProblem {
  /// Refused in the explanation sheet or the phone's dialog; asking again
  /// works.
  denied,

  /// Refused for good: only the phone's settings can change it.
  blocked,

  /// The phone's location is switched off.
  serviceOff,

  /// No position came in time.
  notFound,
}

/// Where the passenger is, for `POST /auth/register`: [Located] or
/// [NotLocated].
sealed class SignUpLocation {
  const SignUpLocation();
}

final class Located extends SignUpLocation {
  const Located(this.position);

  final LatLng position;
}

final class NotLocated extends SignUpLocation {
  const NotLocated(this.problem);

  final SignUpLocationProblem problem;
}

/// One position of the phone for a passenger's sign-up, which the backend
/// checks is in Ghana (`PASSENGER_SIGNUP_COUNTRIES`, decision 27). It is
/// returned to the caller and goes only into the register request: nothing
/// here keeps or saves it, unlike Home's location.
class SignUpLocator {
  const SignUpLocator(this._service);

  final LocationService _service;

  /// The position, asking for permission when needed. Without permission,
  /// [explain] is shown first (the explanation sheet); only when it answers
  /// true does the phone's own dialog appear.
  Future<SignUpLocation> locate({
    required Future<bool> Function() explain,
  }) async {
    var permission = await _service.checkPermission();
    if (permission == LocationPermissionStatus.denied) {
      if (!await explain()) {
        return const NotLocated(SignUpLocationProblem.denied);
      }
      permission = await _service.requestPermission();
    }
    switch (permission) {
      case LocationPermissionStatus.deniedForever:
        return const NotLocated(SignUpLocationProblem.blocked);
      case LocationPermissionStatus.denied:
        return const NotLocated(SignUpLocationProblem.denied);
      case LocationPermissionStatus.granted:
        break;
    }
    if (!await _service.serviceEnabled()) {
      return const NotLocated(SignUpLocationProblem.serviceOff);
    }
    // The phone's last fix will do (city-level is enough for a country
    // check); without one, a fresh fix, for up to 10 s.
    final position =
        await _service.lastKnownPosition() ?? await _service.currentPosition();
    return position == null
        ? const NotLocated(SignUpLocationProblem.notFound)
        : Located(position);
  }

  /// The app's page in the phone's settings, to allow location there.
  Future<void> openAppSettings() => _service.openAppSettings();
}

@riverpod
SignUpLocator signUpLocator(Ref ref) =>
    SignUpLocator(ref.watch(locationServiceProvider));
