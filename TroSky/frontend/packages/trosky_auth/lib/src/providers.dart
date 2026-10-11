import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'token_manager.dart';
import 'token_storage.dart';
import 'user_cache.dart';

part 'providers.g.dart';

/// Build-time settings (`--dart-define-from-file`).
@Riverpod(keepAlive: true)
Env env(Ref ref) => Env.fromDefines();

@Riverpod(keepAlive: true)
RefreshTokenStore refreshTokenStore(Ref ref) => const SecureRefreshTokenStore();

@Riverpod(keepAlive: true)
TokenManager tokenManager(Ref ref) {
  final manager = TokenManager(
    store: ref.watch(refreshTokenStoreProvider),
    // Read lazily: the repository's client needs this manager.
    refresh: (token) => ref
        .read(authRepositoryProvider)
        .refresh(RefreshRequest(refreshToken: token)),
  );
  ref.onDispose(manager.dispose);
  return manager;
}

/// The HTTP client every live repository shares.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = createApiClient(
    env: ref.watch(envProvider),
    tokens: () => ref.read(tokenManagerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
}

/// The in-memory backend behind `API_MODE=mock`.
@Riverpod(keepAlive: true)
MockBackend mockBackend(Ref ref) => MockBackend();

/// How long each mock call takes, so loading states can be seen.
@Riverpod(keepAlive: true)
Duration mockLatency(Ref ref) => const Duration(milliseconds: 600);

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveAuthRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockAuthRepository(
        ref.watch(mockBackendProvider),
        tokens: () => ref.read(tokenManagerProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveUserRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockUserRepository(
        ref.watch(mockBackendProvider),
        tokens: () => ref.read(tokenManagerProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

@Riverpod(keepAlive: true)
DriverRepository driverRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveDriverRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockDriverRepository(
        ref.watch(mockBackendProvider),
        tokens: () => ref.read(tokenManagerProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

/// Stops and routes. The mock answers from fixed Accra stops.
@Riverpod(keepAlive: true)
RouteRepository routeRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveRouteRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockRouteRepository(
        ref.watch(mockBackendProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

/// Live vehicle positions. Only the mock invents vehicles (decision 14).
@Riverpod(keepAlive: true)
TrackingRepository trackingRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveTrackingRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockTrackingRepository(
        ref.watch(mockBackendProvider),
        tokens: () => ref.read(tokenManagerProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

/// Seat holds and bookings.
@Riverpod(keepAlive: true)
BookingRepository bookingRepository(Ref ref) =>
    switch (ref.watch(envProvider).apiMode) {
      ApiMode.live => LiveBookingRepository(ref.watch(apiClientProvider)),
      ApiMode.mock => MockBookingRepository(
        ref.watch(mockBackendProvider),
        tokens: () => ref.read(tokenManagerProvider),
        latency: ref.watch(mockLatencyProvider),
      ),
    };

@Riverpod(keepAlive: true)
UserCache userCache(Ref ref) =>
    SharedPreferencesUserCache(SharedPreferencesAsync());
