// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Build-time settings (`--dart-define-from-file`).

@ProviderFor(env)
final envProvider = EnvProvider._();

/// Build-time settings (`--dart-define-from-file`).

final class EnvProvider extends $FunctionalProvider<Env, Env, Env>
    with $Provider<Env> {
  /// Build-time settings (`--dart-define-from-file`).
  EnvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'envProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$envHash();

  @$internal
  @override
  $ProviderElement<Env> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Env create(Ref ref) {
    return env(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Env value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Env>(value),
    );
  }
}

String _$envHash() => r'c2a98b2fec16e82abd83a3bf89e22eb074f24690';

@ProviderFor(refreshTokenStore)
final refreshTokenStoreProvider = RefreshTokenStoreProvider._();

final class RefreshTokenStoreProvider
    extends
        $FunctionalProvider<
          RefreshTokenStore,
          RefreshTokenStore,
          RefreshTokenStore
        >
    with $Provider<RefreshTokenStore> {
  RefreshTokenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refreshTokenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refreshTokenStoreHash();

  @$internal
  @override
  $ProviderElement<RefreshTokenStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RefreshTokenStore create(Ref ref) {
    return refreshTokenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RefreshTokenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RefreshTokenStore>(value),
    );
  }
}

String _$refreshTokenStoreHash() => r'f3c3167f801f4959cecf0447269511d45d6b8508';

@ProviderFor(tokenManager)
final tokenManagerProvider = TokenManagerProvider._();

final class TokenManagerProvider
    extends $FunctionalProvider<TokenManager, TokenManager, TokenManager>
    with $Provider<TokenManager> {
  TokenManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenManagerHash();

  @$internal
  @override
  $ProviderElement<TokenManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenManager create(Ref ref) {
    return tokenManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenManager>(value),
    );
  }
}

String _$tokenManagerHash() => r'9d647b8c2a646d829e8cf79fde7fab4a74614942';

/// Wakes the server before requests are sent (decision 29). None in mock
/// mode.

@ProviderFor(serverWake)
final serverWakeProvider = ServerWakeProvider._();

/// Wakes the server before requests are sent (decision 29). None in mock
/// mode.

final class ServerWakeProvider
    extends $FunctionalProvider<ServerWake?, ServerWake?, ServerWake?>
    with $Provider<ServerWake?> {
  /// Wakes the server before requests are sent (decision 29). None in mock
  /// mode.
  ServerWakeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverWakeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverWakeHash();

  @$internal
  @override
  $ProviderElement<ServerWake?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ServerWake? create(Ref ref) {
    return serverWake(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerWake? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerWake?>(value),
    );
  }
}

String _$serverWakeHash() => r'15f229aaa282eb4b5fbbc3dfbd130f4f9b3e629b';

/// The server's state for screens. Always awake in mock mode.

@ProviderFor(ServerStatus)
final serverStatusProvider = ServerStatusProvider._();

/// The server's state for screens. Always awake in mock mode.
final class ServerStatusProvider
    extends $NotifierProvider<ServerStatus, ServerState> {
  /// The server's state for screens. Always awake in mock mode.
  ServerStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverStatusHash();

  @$internal
  @override
  ServerStatus create() => ServerStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerState>(value),
    );
  }
}

String _$serverStatusHash() => r'9523b5cec4b8e78ab2f35831760b614f7e2be841';

/// The server's state for screens. Always awake in mock mode.

abstract class _$ServerStatus extends $Notifier<ServerState> {
  ServerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ServerState, ServerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServerState, ServerState>,
              ServerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The HTTP client every live repository shares.

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// The HTTP client every live repository shares.

final class ApiClientProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// The HTTP client every live repository shares.
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$apiClientHash() => r'8b6de51fca3241397615d55e96e075b2cf128b31';

/// The in-memory backend behind `API_MODE=mock`. Its drivers accept booking
/// requests, or answer as `--dart-define=MOCK_DRIVER=moveThenAccept` (or
/// `decline`, `rotate` to take turns, or `none` for nobody) says. The
/// seeded passenger has a week of bookings in every status (Trips tab).

@ProviderFor(mockBackend)
final mockBackendProvider = MockBackendProvider._();

/// The in-memory backend behind `API_MODE=mock`. Its drivers accept booking
/// requests, or answer as `--dart-define=MOCK_DRIVER=moveThenAccept` (or
/// `decline`, `rotate` to take turns, or `none` for nobody) says. The
/// seeded passenger has a week of bookings in every status (Trips tab).

final class MockBackendProvider
    extends $FunctionalProvider<MockBackend, MockBackend, MockBackend>
    with $Provider<MockBackend> {
  /// The in-memory backend behind `API_MODE=mock`. Its drivers accept booking
  /// requests, or answer as `--dart-define=MOCK_DRIVER=moveThenAccept` (or
  /// `decline`, `rotate` to take turns, or `none` for nobody) says. The
  /// seeded passenger has a week of bookings in every status (Trips tab).
  MockBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mockBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mockBackendHash();

  @$internal
  @override
  $ProviderElement<MockBackend> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MockBackend create(Ref ref) {
    return mockBackend(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MockBackend value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MockBackend>(value),
    );
  }
}

String _$mockBackendHash() => r'fe6bfea9dedda239d771116ff5defe6bd9883a04';

/// How long each mock call takes, so loading states can be seen.

@ProviderFor(mockLatency)
final mockLatencyProvider = MockLatencyProvider._();

/// How long each mock call takes, so loading states can be seen.

final class MockLatencyProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// How long each mock call takes, so loading states can be seen.
  MockLatencyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mockLatencyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mockLatencyHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return mockLatency(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$mockLatencyHash() => r'0409800df8c8d66d9f4d818f1b2fd91d0ab680cb';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'e8c425fb5233e0087b1e8998e7b6c656b9b60dc5';

@ProviderFor(userRepository)
final userRepositoryProvider = UserRepositoryProvider._();

final class UserRepositoryProvider
    extends $FunctionalProvider<UserRepository, UserRepository, UserRepository>
    with $Provider<UserRepository> {
  UserRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRepository create(Ref ref) {
    return userRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRepository>(value),
    );
  }
}

String _$userRepositoryHash() => r'444b702a418c33fe3de015e594c95859feec23e4';

@ProviderFor(driverRepository)
final driverRepositoryProvider = DriverRepositoryProvider._();

final class DriverRepositoryProvider
    extends
        $FunctionalProvider<
          DriverRepository,
          DriverRepository,
          DriverRepository
        >
    with $Provider<DriverRepository> {
  DriverRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'driverRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$driverRepositoryHash();

  @$internal
  @override
  $ProviderElement<DriverRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DriverRepository create(Ref ref) {
    return driverRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DriverRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DriverRepository>(value),
    );
  }
}

String _$driverRepositoryHash() => r'3ab08914ea9fe4807f573b420f3a52b08f4f824f';

/// Stops and routes. The mock answers from fixed Accra stops.

@ProviderFor(routeRepository)
final routeRepositoryProvider = RouteRepositoryProvider._();

/// Stops and routes. The mock answers from fixed Accra stops.

final class RouteRepositoryProvider
    extends
        $FunctionalProvider<RouteRepository, RouteRepository, RouteRepository>
    with $Provider<RouteRepository> {
  /// Stops and routes. The mock answers from fixed Accra stops.
  RouteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routeRepositoryHash();

  @$internal
  @override
  $ProviderElement<RouteRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RouteRepository create(Ref ref) {
    return routeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RouteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RouteRepository>(value),
    );
  }
}

String _$routeRepositoryHash() => r'cf287380f33aa0ca7446d19c40502ef968a4f54e';

/// Live vehicle positions. Only the mock invents vehicles (decision 14).

@ProviderFor(trackingRepository)
final trackingRepositoryProvider = TrackingRepositoryProvider._();

/// Live vehicle positions. Only the mock invents vehicles (decision 14).

final class TrackingRepositoryProvider
    extends
        $FunctionalProvider<
          TrackingRepository,
          TrackingRepository,
          TrackingRepository
        >
    with $Provider<TrackingRepository> {
  /// Live vehicle positions. Only the mock invents vehicles (decision 14).
  TrackingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackingRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrackingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrackingRepository create(Ref ref) {
    return trackingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackingRepository>(value),
    );
  }
}

String _$trackingRepositoryHash() =>
    r'c84da5f057977a96ca7642de22e99f8c9f67ba02';

/// Seat holds and bookings.

@ProviderFor(bookingRepository)
final bookingRepositoryProvider = BookingRepositoryProvider._();

/// Seat holds and bookings.

final class BookingRepositoryProvider
    extends
        $FunctionalProvider<
          BookingRepository,
          BookingRepository,
          BookingRepository
        >
    with $Provider<BookingRepository> {
  /// Seat holds and bookings.
  BookingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookingRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookingRepository create(Ref ref) {
    return bookingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookingRepository>(value),
    );
  }
}

String _$bookingRepositoryHash() => r'2fdcac728430e45f48814f8cbae9a5c8c06874e1';

/// Paying for bookings, the wallet and saved mobile money numbers.

@ProviderFor(paymentRepository)
final paymentRepositoryProvider = PaymentRepositoryProvider._();

/// Paying for bookings, the wallet and saved mobile money numbers.

final class PaymentRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentRepository,
          PaymentRepository,
          PaymentRepository
        >
    with $Provider<PaymentRepository> {
  /// Paying for bookings, the wallet and saved mobile money numbers.
  PaymentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentRepository create(Ref ref) {
    return paymentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentRepository>(value),
    );
  }
}

String _$paymentRepositoryHash() => r'da0e0ce027041cf68f2252ddfeb69efd6ea875f4';

@ProviderFor(userCache)
final userCacheProvider = UserCacheProvider._();

final class UserCacheProvider
    extends $FunctionalProvider<UserCache, UserCache, UserCache>
    with $Provider<UserCache> {
  UserCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userCacheHash();

  @$internal
  @override
  $ProviderElement<UserCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserCache create(Ref ref) {
    return userCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserCache>(value),
    );
  }
}

String _$userCacheHash() => r'ccb739315751dc7bf5dd9ef316147703d92c5408';
