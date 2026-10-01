import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import 'support.dart';

class _FailingDrivers implements DriverRepository {
  @override
  Future<Result<DriverResponse>> getMe() async => const Err(NetworkFailure());
}

void main() {
  late MockBackend backend;

  setUp(() => backend = MockBackend());

  /// Signs in [phone] and resolves where it goes in [mode].
  Future<Result<PostSignInDestination>> route(
    String phone,
    AppMode mode, {
    bool offline = false,
    DriverRepository? drivers,
  }) async {
    final c = appContainer(
      backend: backend,
      store: InMemoryRefreshTokenStore(),
      extra: [
        if (drivers != null)
          driverRepositoryProvider.overrideWithValue(drivers),
      ],
    );
    await c.read(sessionControllerProvider.future);
    final user = await c
        .read(sessionControllerProvider.notifier)
        .signIn(identifier: phone, password: MockBackend.seedPassword);
    return resolvePostSignIn(
      session: SessionAuthenticated(user.valueOrNull!, offline: offline),
      mode: mode,
      drivers: c.read(driverRepositoryProvider),
    );
  }

  void registerDriver(String phone) {
    backend
      ..register(
        RegisterRequest(
          phoneNumber: phone,
          email: 'kwame.mensah@gmail.com',
          password: MockBackend.seedPassword,
          fullName: 'Kwame Mensah',
          role: RegistrableRole.driver,
        ),
      )
      ..verifyOtp(
        VerifyOtpRequest(
          target: normalizePhoneNumber(phone),
          purpose: OtpPurpose.registration,
          code: MockBackend.otpCode,
        ),
      );
  }

  test('passenger mode, passenger account: home', () async {
    expect(
      (await route('0241234567', AppMode.passenger)).valueOrNull,
      PostSignInDestination.passengerHome,
    );
  });

  test('passenger mode, driver-only account: offer driver mode', () async {
    expect(
      (await route('0201234567', AppMode.passenger)).valueOrNull,
      PostSignInDestination.driverAccount,
    );
  });

  test('driver mode, approved driver: driver home', () async {
    expect(
      (await route('0201234567', AppMode.driver)).valueOrNull,
      PostSignInDestination.driverHome,
    );
  });

  test('driver mode, no driver role: S-10', () async {
    expect(
      (await route('0241234567', AppMode.driver)).valueOrNull,
      PostSignInDestination.notADriverYet,
    );
  });

  test('driver mode, driver without a profile: D-01', () async {
    registerDriver('0551234567');
    expect(
      (await route('0551234567', AppMode.driver)).valueOrNull,
      PostSignInDestination.driverOnboarding,
    );
  });

  test('driver mode, profile not approved: awaiting approval', () async {
    registerDriver('0551234567');
    for (final status in [
      ApprovalStatus.pending,
      ApprovalStatus.underReview,
      ApprovalStatus.rejected,
    ]) {
      backend.setDriverStatus('0551234567', status);
      expect(
        (await route('0551234567', AppMode.driver)).valueOrNull,
        PostSignInDestination.driverAwaitingApproval,
        reason: status.name,
      );
    }
  });

  test('offline, driver mode: driver home without asking', () async {
    registerDriver('0551234567');
    expect(
      (await route('0551234567', AppMode.driver, offline: true)).valueOrNull,
      PostSignInDestination.driverHome,
    );
  });

  test('a network failure on /drivers/me is reported, not guessed', () async {
    final result = await route(
      '0201234567',
      AppMode.driver,
      drivers: _FailingDrivers(),
    );
    expect(result.failureOrNull?.code, 'NETWORK_ERROR');
  });
}
