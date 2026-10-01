import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'app_mode.dart';
import 'session.dart';

/// Where a signed-in user goes, given the app mode and their roles.
enum PostSignInDestination {
  /// Passenger mode, passenger account.
  passengerHome,

  /// Driver mode, driver account without a driver profile yet (D-01).
  driverOnboarding,

  /// Driver mode, profile pending, under review, rejected, suspended or
  /// expired.
  driverAwaitingApproval,

  /// Driver mode, approved driver.
  driverHome,

  /// Driver mode, but the account has no driver role (S-10): offer
  /// "Become a driver" or "Continue as passenger".
  notADriverYet,

  /// Passenger mode, but a driver-only account: offer "Switch to driver
  /// mode".
  driverAccount,
}

/// Picks the [PostSignInDestination] for [session] in [mode]. Only an
/// approved driver profile leads to the driver home; that takes
/// `GET /drivers/me`, skipped offline (the last role is all there is).
Future<Result<PostSignInDestination>> resolvePostSignIn({
  required SessionAuthenticated session,
  required AppMode mode,
  required DriverRepository drivers,
}) async {
  final roles = session.roles;
  switch (mode) {
    case AppMode.passenger:
      final driverOnly =
          !roles.contains('passenger') && roles.contains('driver');
      return Ok(
        driverOnly
            ? PostSignInDestination.driverAccount
            : PostSignInDestination.passengerHome,
      );
    case AppMode.driver:
      if (!roles.contains('driver')) {
        return const Ok(PostSignInDestination.notADriverYet);
      }
      if (session.offline) return const Ok(PostSignInDestination.driverHome);
      final profile = await drivers.getMe();
      return switch (profile) {
        Ok(:final value) => Ok(
          value.status == ApprovalStatus.approved
              ? PostSignInDestination.driverHome
              : PostSignInDestination.driverAwaitingApproval,
        ),
        Err(failure: NotFoundFailure()) => const Ok(
          PostSignInDestination.driverOnboarding,
        ),
        Err(failure: ForbiddenFailure()) => const Ok(
          PostSignInDestination.notADriverYet,
        ),
        Err(:final failure) => Err(failure),
      };
  }
}
