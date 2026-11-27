import 'package:trosky_core/trosky_core.dart';

import '../client/interceptors.dart';
import '../dto/auth_dto.dart';
import '../dto/booking_dto.dart';
import '../dto/driver_dto.dart';
import '../dto/notification_dto.dart';
import '../dto/paginated.dart';
import '../dto/payment_dto.dart';
import '../dto/route_dto.dart';
import '../dto/safety_dto.dart';
import '../dto/ticket_dto.dart';
import '../dto/tracking_dto.dart';
import '../dto/user_dto.dart';
import '../repositories/auth_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/driver_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/route_repository.dart';
import '../repositories/safety_repository.dart';
import '../repositories/ticket_repository.dart';
import '../repositories/tracking_repository.dart';
import '../repositories/user_repository.dart';
import 'mock_backend.dart';

/// Runs an authenticated [MockBackend] call the way the live client does:
/// with the current access token, refreshing once on an expired token.
Future<Result<T>> _authenticated<T>(
  SessionTokens tokens,
  Duration latency,
  Result<T> Function(String? accessToken) call,
) async {
  if (latency > Duration.zero) await Future<void>.delayed(latency);
  final first = call(tokens.accessToken);
  if (first.failureOrNull?.code != 'UNAUTHORIZED' ||
      tokens.accessToken == null) {
    return first;
  }
  final refreshed = await tokens.refresh();
  return switch (refreshed) {
    Ok(:final value) => call(value),
    Err(:final failure) => Err(failure),
  };
}

/// [AuthRepository] on a [MockBackend] (`API_MODE=mock`).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;

  /// How long each call takes, to see loading states.
  final Duration latency;

  Future<Result<T>> _call<T>(Result<T> Function() call) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return call();
  }

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest request) =>
      _call(() => _backend.register(request));

  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest request) =>
      _call(() => _backend.verifyOtp(request));

  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest request) =>
      _call(() => _backend.resendOtp(request));

  @override
  Future<Result<TokenPairResponse>> login(LoginRequest request) =>
      _call(() => _backend.login(request));

  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest request) =>
      _call(() => _backend.otpLogin(request));

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) =>
      _call(() => _backend.refresh(request));

  @override
  Future<Result<void>> logout() =>
      _authenticated(_tokens(), latency, _backend.logout);

  // Step 20: password reset. Mock mode returns a generic success so the
  // UI can be exercised without touching the live backend; replace with
  // _backend methods when mock seed data gets a reset flow.
  @override
  Future<Result<MessageResponse>> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return const Ok(
      MessageResponse(
        message: 'If an account exists, a reset code has been sent.',
      ),
    );
  }

  @override
  Future<Result<MessageResponse>> resetPassword(
    ResetPasswordRequest request,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return const Ok(MessageResponse(message: 'Password reset successfully.'));
  }
}

/// [UserRepository] on a [MockBackend] (`API_MODE=mock`).
class MockUserRepository implements UserRepository {
  MockUserRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<UserResponse>> getMe() =>
      _authenticated(_tokens(), latency, _backend.getMe);

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() =>
      _authenticated(_tokens(), latency, _backend.listFavouriteRoutes);

  @override
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  ) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.addFavouriteRoute(token, request),
  );

  // Step 20: PATCH /users/me + DELETE /users/me. The mock backend doesn't
  // track profile edits or deletion; these return a NOT_IMPLEMENTED error
  // so the Profile UI shows an offline-style line in mock mode. Live is
  // the target.
  @override
  Future<Result<UserResponse>> updateMe(
    UserProfileUpdateRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Profile editing is not available in mock mode.',
    ),
  );

  @override
  Future<Result<MessageResponse>> deleteAccount(
    AccountDeletionRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Account deletion is not available in mock mode.',
    ),
  );

  // Step 21/B4: change-password + change-email. The mock backend
  // doesn't track account mutations; returning NOT_IMPLEMENTED matches
  // how updateMe / deleteAccount behave in mock mode. Live is the
  // target for both; widget tests supply their own fakes.
  @override
  Future<Result<MessageResponse>> changePassword(
    ChangePasswordRequest request, {
    required String idempotencyKey,
  }) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Changing the password is not available in mock mode.',
    ),
  );

  @override
  Future<Result<EmailChangeStartedResponse>> changeEmail(
    ChangeEmailRequest request, {
    required String idempotencyKey,
  }) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Changing the email is not available in mock mode.',
    ),
  );

  @override
  Future<Result<UserResponse>> confirmEmailChange(
    ChangeEmailConfirmRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Confirming the email change is not available in mock mode.',
    ),
  );

  // Step 20/B: DELETE /users/me/favourite-routes/{id} +
  // notification-preferences GET/PATCH. The mock backend doesn't track
  // either today; returning NOT_IMPLEMENTED keeps mock mode honest and
  // widget tests supply their own fakes.
  @override
  Future<Result<void>> deleteFavouriteRoute(String favouriteId) async =>
      const Err(
        UnknownFailure(
          code: 'NOT_IMPLEMENTED',
          message: 'Deleting favourites is not available in mock mode.',
        ),
      );

  @override
  Future<Result<NotificationPreferencesResponse>>
  notificationPreferences() async => Ok(
    const NotificationPreferencesResponse(
      pushEnabled: true,
      smsEnabled: true,
      emailEnabled: true,
      promotionalOptIn: false,
    ),
  );

  @override
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message:
          'Updating notification preferences is not available in mock mode.',
    ),
  );
}

/// [DriverRepository] on a [MockBackend] (`API_MODE=mock`).
class MockDriverRepository implements DriverRepository {
  MockDriverRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<DriverResponse>> getMe() =>
      _authenticated(_tokens(), latency, _backend.getDriverMe);
}

/// [RouteRepository] on a [MockBackend] (`API_MODE=mock`).
class MockRouteRepository implements RouteRepository {
  MockRouteRepository(this._backend, {this.latency = Duration.zero});

  final MockBackend _backend;
  final Duration latency;

  @override
  Future<Result<List<NearbyStopResponse>>> nearbyStops({
    required double latitude,
    required double longitude,
    int? radiusM,
    int? limit,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.nearbyStops(
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      limit: limit,
    );
  }

  @override
  Future<Result<List<StopResponse>>> searchStops(
    String query, {
    int limit = 20,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.searchStops(query, limit: limit);
  }

  @override
  Future<Result<Paginated<TripSearchResultResponse>>> searchTrips(
    TripSearchQuery query,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.searchTrips(query);
  }

  @override
  Future<Result<TripSeatsResponse>> tripSeats(String tripId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.tripSeats(tripId);
  }

  @override
  Future<Result<TripDetailResponse>> trip(String tripId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.tripDetail(tripId);
  }

  @override
  Future<Result<FareQuoteResponse>> fareQuote(
    String tripId, {
    String? originStopId,
    String? destinationStopId,
    int seats = 1,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _backend.fareQuote(
      tripId,
      originStopId: originStopId,
      destinationStopId: destinationStopId,
      seats: seats,
    );
  }
}

/// [BookingRepository] on a [MockBackend] (`API_MODE=mock`).
class MockBookingRepository implements BookingRepository {
  MockBookingRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  /// The booking made for each idempotency key, as the backend keeps it.
  final Map<String, String> _byKey = {};

  @override
  Future<Result<BookingResponse>> create(
    BookingCreateRequest request, {
    required String idempotencyKey,
  }) => _authenticated(_tokens(), latency, (token) {
    if (_byKey[idempotencyKey] case final id?) {
      return _backend.getBooking(token, id);
    }
    final result = _backend.createBooking(token, request);
    if (result case Ok(:final value)) _byKey[idempotencyKey] = value.id;
    return result;
  });

  @override
  Future<Result<Paginated<BookingResponse>>> list({
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.listBookings(
      token,
      statuses: statuses,
      upcoming: upcoming,
      limit: limit,
      offset: offset,
    ),
  );

  @override
  Future<Result<BookingSummaryResponse>> summary({String? month}) =>
      _authenticated(
        _tokens(),
        latency,
        (token) => _backend.bookingSummary(token, month: month),
      );

  @override
  Future<Result<BookingResponse>> get(String bookingId) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.getBooking(token, bookingId),
  );

  @override
  Future<Result<BookingResponse>> cancel(
    String bookingId, {
    CancelReason? reason,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.cancelBooking(token, bookingId, reason: reason),
  );

  // Step 19: rate + getRating. Mock mode returns NOT_IMPLEMENTED so the
  // Rate UI shows an offline-style friendly line. Live is the target.
  @override
  Future<Result<RatingResponse>> rate(
    String bookingId,
    RateBookingRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Rating a trip is not yet available in mock mode.',
    ),
  );

  @override
  Future<Result<RatingResponse>> getRating(String bookingId) async => const Err(
    UnknownFailure(code: 'NOT_FOUND', message: 'No rating in mock mode.'),
  );
}

/// [PaymentRepository] against the in-memory [MockBackend]: the wallet pays
/// at once; mobile money is approved after [MockBackend.momoApproveAfter],
/// declined for numbers ending 0000, unanswered for numbers ending 9999.
class MockPaymentRepository implements PaymentRepository {
  MockPaymentRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<PaymentResponse>> pay(
    String bookingId,
    PayBookingRequest request, {
    required String idempotencyKey,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.payBooking(
      token,
      bookingId,
      request,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<Result<PaymentResponse>> sync(String paymentId) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.syncPayment(token, paymentId),
  );

  @override
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.listPayments(token, limit: limit, offset: offset),
  );

  @override
  Future<Result<PaymentResponse>> topUpWallet(
    WalletTopupRequest request, {
    required String idempotencyKey,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.createWalletTopup(token, request),
  );

  @override
  Future<Result<WalletResponse>> wallet() =>
      _authenticated(_tokens(), latency, _backend.getWallet);

  @override
  Future<Result<List<PaymentMethodResponse>>> methods() =>
      _authenticated(_tokens(), latency, _backend.listPaymentMethods);

  @override
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  ) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.addPaymentMethod(token, request),
  );

  // Step 18 added these three. Mock mode shows the empty/no-op state; the
  // live app is the target. Widget tests use their own repository fakes.
  @override
  Future<Result<PaymentMethodResponse>> updateMethod(
    String methodId,
    PaymentMethodUpdateRequest request,
  ) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Managing saved methods is not yet available in mock mode.',
    ),
  );

  @override
  Future<Result<void>> deleteMethod(String methodId) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Managing saved methods is not yet available in mock mode.',
    ),
  );

  @override
  Future<Result<Paginated<WalletTransactionResponse>>> transactions({
    WalletReferenceType? referenceType,
    int limit = 20,
    int offset = 0,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Ok(
      Paginated(items: const [], total: 0, limit: limit, offset: offset),
    );
  }
}

/// [TrackingRepository] on a [MockBackend] (`API_MODE=mock`): invented
/// vehicles, for mock mode only (decision 14).
class MockTrackingRepository implements TrackingRepository {
  MockTrackingRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<List<NearbyVehicleResponse>>> nearbyVehicles({
    required double latitude,
    required double longitude,
    required int radiusM,
    int limit = 20,
  }) => _authenticated(
    _tokens(),
    latency,
    (token) => _backend.nearbyVehicles(
      token,
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      limit: limit,
    ),
  );

  @override
  Future<Result<LiveLocationResponse>> tripLocation(String tripId) async =>
      const Err(
        UnknownFailure(
          code: 'NOT_IMPLEMENTED',
          message: 'Live tracking is not yet available in mock mode.',
        ),
      );

  @override
  Future<Result<EtaResponse>> tripEta(
    String tripId, {
    String? destinationStopId,
  }) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Live tracking is not yet available in mock mode.',
    ),
  );
}

/// [SafetyRepository] on a [MockBackend]. Mock mode doesn't actually
/// trigger SOS or file incidents; replies look like a real success so
/// the P-12/P-13 UI has something to confirm against in demo mode.
class MockSafetyRepository implements SafetyRepository {
  MockSafetyRepository({required this.tokens, this.latency = Duration.zero});
  final SessionTokens Function() tokens;
  final Duration latency;

  SosAlertResponse _fakeAlert({String? tripId}) => SosAlertResponse(
    id: 'mock-sos-${DateTime.now().microsecondsSinceEpoch}',
    tripId: tripId,
    triggeredBy: 'mock-user',
    status: SosAlertStatus.active,
    createdAt: DateTime.now().toUtc(),
  );

  IncidentResponse _fakeIncident(String tripId, ReportIncidentRequest req) =>
      IncidentResponse(
        id: 'mock-incident-${DateTime.now().microsecondsSinceEpoch}',
        tripId: tripId,
        reportedBy: 'mock-user',
        incidentType: req.incidentType,
        severity: req.severity ?? IncidentSeverity.medium,
        description: req.description,
        status: IncidentStatus.reported,
        createdAt: DateTime.now().toUtc(),
      );

  @override
  Future<Result<SosAlertResponse>> triggerTripSos(
    String tripId,
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Ok(_fakeAlert(tripId: tripId));
  }

  @override
  Future<Result<SosAlertResponse>> triggerSos(
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Ok(_fakeAlert());
  }

  @override
  Future<Result<IncidentResponse>> reportIncident(
    String tripId,
    ReportIncidentRequest request, {
    required String idempotencyKey,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Ok(_fakeIncident(tripId, request));
  }

  @override
  Future<Result<IncidentResponse>> uploadIncidentPhoto(
    String incidentId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async => const Err(
    UnknownFailure(
      code: 'NOT_IMPLEMENTED',
      message: 'Photo upload is not available in mock mode.',
    ),
  );
}

/// [TicketRepository] on a [MockBackend].
class MockTicketRepository implements TicketRepository {
  MockTicketRepository(
    this._backend, {
    required this._tokens,
    this.latency = Duration.zero,
  });

  final MockBackend _backend;
  final SessionTokens Function() _tokens;
  final Duration latency;

  @override
  Future<Result<List<TicketResponse>>> listForBooking(String bookingId) =>
      _authenticated(
        _tokens(),
        latency,
        (token) => _backend.listTicketsForBooking(token, bookingId),
      );
}
