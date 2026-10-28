import 'dart:math' as math;

import 'package:trosky_core/trosky_core.dart';

import '../dto/auth_dto.dart';
import '../dto/booking_dto.dart';
import '../dto/driver_dto.dart';
import '../dto/paginated.dart';
import '../dto/route_dto.dart';
import '../dto/tracking_dto.dart';
import '../dto/user_dto.dart';
import '../repositories/booking_repository.dart';
import '../repositories/route_repository.dart';
import 'mock_regions.dart';

/// An in-memory stand-in for the backend's auth and user endpoints, for
/// `API_MODE=mock` and tests.
///
/// It follows backend/app/services/auth_service.py and otp_service.py rule
/// for rule, with the same error codes, statuses, messages and details, and
/// the backend's default settings (backend/app/core/config.py).
///
/// Fixed data:
/// * Every code is [otpCode] (`123456`).
/// * `0241234567` is an existing passenger and `0201234567` an existing,
///   approved driver, both verified, both with the password [seedPassword].
/// * Any other phone number is a new user.
/// * [stops] are real Accra places, at approximate positions.
/// * The seeded passenger has the four favourite routes the Home design
///   shows; other accounts have none.
/// * Three vehicles are always on the road around whatever point is asked
///   about, where the Home design draws them (decision 14), unless
///   [vehiclesOnTheRoad] is off.
/// * Trip search finds trips between any two different stops: for a search
///   from now, the five P6 design vehicles (three approaching, two passed),
///   then a departure every 15 minutes until 22:00 (see [searchTrips]).
/// * Trips found by a search can be booked. Minibuses have the P7 seat map
///   (14 seats, 5 taken); while [simulateRiders] is on, another rider takes
///   a seat on a minibus every 10 seconds until 12 are booked, and the
///   shared fare drops as in the design (see [tripSeats]).
/// * A booking waits for the trip's driver ([bookingAcceptanceRequired],
///   as backend/app/services/booking_acceptance_service.py). Drivers answer
///   as [driverScript] says, [driverAnswersAfter] after each request; with
///   no script nobody answers, and tests answer with [acceptBooking] and
///   [declineBooking].
class MockBackend {
  MockBackend({
    DateTime Function()? clock,
    this.codesByEmail = false,
    this.passengerSignupCountries = const {'GH'},
    this.bookingAcceptanceRequired = true,
    this.driverScript,
    this.driverAnswersAfter = const Duration(seconds: 8),
    this.bookingHistory = false,
  }) : _now = clock ?? DateTime.now {
    _seed();
    if (bookingHistory) _seedHistory();
  }

  /// The code every OTP has.
  static const String otpCode = '123456';

  /// The password of the seeded accounts.
  static const String seedPassword = 'TroSky2026';

  static const String passengerPhone = '+233241234567';
  static const String driverPhone = '+233201234567';

  // Backend defaults.
  static const int pickupMaxWalkMeters = 1000;
  static const int pickupNearbyLimit = 5;
  static const int favouriteRoutesMax = 20;
  static const Duration otpTtl = Duration(seconds: 300);
  static const Duration otpCooldown = Duration(seconds: 60);
  static const int otpMaxAttempts = 5;
  static const int loginMaxFailedAttempts = 5;
  static const Duration loginLockout = Duration(seconds: 900);
  static const int accessTokenTtlSeconds = 900;
  static const Duration refreshTokenTtl = Duration(days: 30);
  static const Set<String> registrationEmailDomains = {
    'gmail.com',
    'googlemail.com',
  };

  /// `OTP_DELIVERY_CHANNEL=email`: codes go to the account's email address,
  /// as in the docker-compose setup. The default sends them by SMS.
  final bool codesByEmail;

  /// `PASSENGER_SIGNUP_COUNTRIES`: a passenger signs up only with the
  /// phone's position, in one of these countries (Ghana, as the backend's
  /// default). Empty switches the check off, as on the staging server.
  final Set<String> passengerSignupCountries;

  final DateTime Function() _now;
  final List<_User> _users = [];
  final List<_Challenge> _challenges = [];
  final Map<String, DateTime> _cooldowns = {};
  final Map<String, _Session> _sessions = {};
  final Map<String, _RefreshToken> _refreshTokens = {};
  final Map<String, _AccessToken> _accessTokens = {};
  final Map<String, DriverResponse> _driverProfiles = {};
  final Map<String, List<FavouriteRouteResponse>> _favourites = {};
  int _counter = 0;

  /// When off, `GET /vehicles/nearby` finds nothing, as when no trip is
  /// running.
  bool vehiclesOnTheRoad = true;

  /// Other riders keep booking minibus seats (decision 24's fare drop).
  bool simulateRiders = true;

  static const Duration seatHold = Duration(seconds: 600);
  static const int bookingMaxSeats = 10;
  static const String platformFeePerSeat = '0.50';

  /// `BOOKING_ACCEPT_TIMEOUT_SECONDS`, `BOOKING_MAX_MOVES` and
  /// `BOOKING_MOVE_WINDOW_MINUTES`.
  static const Duration acceptTimeout = Duration(seconds: 120);
  static const int bookingMaxMoves = 3;
  static const Duration bookingMoveWindow = Duration(minutes: 60);

  /// `BOOKING_ACCEPTANCE_REQUIRED`: new bookings wait for the driver. Off,
  /// they are pending (payable) at once, as on the staging server.
  final bool bookingAcceptanceRequired;

  /// How the trips' drivers answer booking requests; null: nobody answers,
  /// so a request moves to another vehicle when its time is up, or ends.
  final MockDriverScript? driverScript;

  /// How long a scripted driver takes to answer.
  final Duration driverAnswersAfter;

  /// The seeded passenger starts with a week of bookings in every status
  /// (Trips tab, P-15/P-16). Off in tests that count bookings.
  final bool bookingHistory;

  final Map<String, _MockTrip> _tripIndex = {};
  final Map<String, _MockBooking> _bookings = {};

  /// The stops, by name.
  static final Map<String, MockStop> stops = {
    for (final stop in const [
      MockStop('Madina', 5.6731, -0.1661),
      MockStop('Circle', 5.5713, -0.2069),
      MockStop('Legon', 5.6508, -0.1870),
      MockStop('Osu', 5.5560, -0.1820),
      MockStop('Achimota', 5.6131, -0.2297),
      MockStop('Tema', 5.6698, -0.0166),
      MockStop('Kaneshie', 5.5667, -0.2333),
      MockStop('Lapaz', 5.6060, -0.2500),
      MockStop('Accra Central', 5.5490, -0.2090),
    ])
      stop.name: stop,
  };

  /// Codes "sent" so far, newest last: what an SMS or email would carry.
  final List<SentCode> outbox = [];

  void _seed() {
    final created = DateTime.utc(2026, 7, 1, 8);
    _users
      ..add(
        _User(
          id: '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41',
          phone: passengerPhone,
          email: 'ama.mensah@gmail.com',
          password: seedPassword,
          fullName: 'Ama Mensah',
          roles: ['passenger'],
          createdAt: created,
        )..phoneVerifiedAt = created,
      )
      ..add(
        _User(
          id: '8c4d2a91-3b7e-4f60-a2d5-9e1b6c7f0a28',
          phone: driverPhone,
          email: 'kofi.boateng@gmail.com',
          password: seedPassword,
          fullName: 'Kofi Boateng',
          roles: ['driver'],
          createdAt: created,
        )..phoneVerifiedAt = created,
      );
    _driverProfiles['8c4d2a91-3b7e-4f60-a2d5-9e1b6c7f0a28'] = DriverResponse(
      id: '5a1e9c37-2d4b-4c8f-9e60-1b7d3f2a8c94',
      userId: '8c4d2a91-3b7e-4f60-a2d5-9e1b6c7f0a28',
      licenseNumber: 'GHA-DL-0482913',
      licenseExpiry: DateTime.utc(2029, 3, 31),
      licenseClass: 'C',
      yearsOfExperience: 9,
      status: ApprovalStatus.approved,
      createdAt: created,
    );
    _favourites['2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41'] = [
      for (final (i, (from, to)) in const [
        ('Madina', 'Circle'),
        ('Legon', 'Osu'),
        ('Achimota', 'Tema'),
        ('Kaneshie', 'Lapaz'),
      ].indexed)
        FavouriteRouteResponse(
          id: 'f${i + 1}0e8a5c-4b2d-4e9f-8a61-3c7d2b9e5f04',
          originStopId: stops[from]!.id,
          originStopName: from,
          destinationStopId: stops[to]!.id,
          destinationStopName: to,
          createdAt: created.add(Duration(minutes: i)),
        ),
    ];
  }

  // ---------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------

  Result<RegisterResponse> register(RegisterRequest request) {
    final phone = tryNormalizePhoneNumber(request.phoneNumber);
    final invalid = [
      if (phone == null)
        _fieldError(
          'phone_number',
          "Value error, '${request.phoneNumber}' is not a valid phone number",
        ),
      if (request.email != null && !_looksLikeEmail(request.email!))
        _fieldError(
          'email',
          'value is not a valid email address: An email address must have '
              'an @-sign.',
        ),
      if (request.password.length < 8)
        _fieldError('password', 'String should have at least 8 characters'),
      if (request.fullName.length < 2)
        _fieldError('full_name', 'String should have at least 2 characters'),
    ];
    if (invalid.isNotEmpty) return _validationError(invalid);

    final violations = _passwordViolations(request.password);
    if (violations.isNotEmpty) {
      return _error(
        409,
        'PASSWORD_POLICY_VIOLATION',
        'Password does not meet the required policy.',
        {'violations': violations},
      );
    }

    final email = request.email?.trim().toLowerCase();
    final domains = (registrationEmailDomains.toList()..sort())
        .map((d) => '@$d')
        .join(' or ');
    if (email == null) {
      return _error(
        422,
        'EMAIL_REQUIRED',
        'An email address ending in $domains is required to register.',
        {'allowed_domains': registrationEmailDomains.toList()..sort()},
      );
    }
    if (!registrationEmailDomains.contains(email.split('@').last)) {
      return _error(
        422,
        'EMAIL_DOMAIN_NOT_ALLOWED',
        'Please register with an email address ending in $domains.',
        {'allowed_domains': registrationEmailDomains.toList()..sort()},
      );
    }
    final outside = _checkSignupLocation(request);
    if (outside != null) return outside;
    if (_byPhone(phone!) != null) {
      return _error(
        409,
        'PHONE_ALREADY_REGISTERED',
        'An account with this phone number already exists.',
      );
    }
    if (_byEmail(email) != null) {
      return _error(
        409,
        'EMAIL_ALREADY_REGISTERED',
        'An account with this email already exists.',
      );
    }

    final user = _User(
      id: _uuid(),
      phone: phone,
      email: email,
      password: request.password,
      fullName: request.fullName,
      roles: [_roleSlug(request.role)],
      createdAt: _now().toUtc(),
      preferredLanguage: request.preferredLanguage,
    );
    _users.add(user);

    // If the code can't be issued, the backend's transaction rolls back and
    // no account is left behind.
    if (codesByEmail) {
      final failed = _issue(email, OtpChannel.email, OtpPurpose.registration);
      if (failed != null) {
        _users.remove(user);
        return Err(failed);
      }
      return Ok(
        RegisterResponse(
          userId: user.id,
          phoneNumber: phone,
          otpSentTo: email,
          message:
              'Registration successful. Verify your email address with the '
              'code sent.',
        ),
      );
    }
    final failed = _issue(phone, OtpChannel.sms, OtpPurpose.registration);
    if (failed != null) {
      _users.remove(user);
      return Err(failed);
    }
    // Best effort in the backend; a cooldown clash is ignored there too.
    if (_cooldownRunning(email, OtpPurpose.emailVerification) == null) {
      _issue(email, OtpChannel.email, OtpPurpose.emailVerification);
    }
    return Ok(
      RegisterResponse(
        userId: user.id,
        phoneNumber: phone,
        otpSentTo: phone,
        message:
            'Registration successful. Verify your phone number with the OTP '
            'sent.',
      ),
    );
  }

  Result<MessageResponse> verifyOtp(VerifyOtpRequest request) {
    final invalid = _codeFieldErrors(request.code);
    if (invalid != null) return _validationError(invalid);
    final target = _normalizeTarget(request.target);
    final verified = _verify(target, request.purpose, request.code);
    if (verified case Err(:final failure)) return Err(failure);
    final challenge = verified.valueOrNull!;

    final bool provesEmail;
    switch (request.purpose) {
      case OtpPurpose.registration:
        provesEmail = challenge.channel == OtpChannel.email;
      case OtpPurpose.phoneVerification || OtpPurpose.emailVerification:
        provesEmail = request.purpose == OtpPurpose.emailVerification;
      case OtpPurpose.login || OtpPurpose.passwordReset:
        return const Ok(MessageResponse(message: 'OTP verified successfully.'));
    }
    final user = _resolve(target);
    if (user == null) {
      return _error(
        404,
        'NOT_FOUND',
        'No account found for this phone number or email.',
      );
    }
    if (provesEmail) {
      user.emailVerifiedAt = _now().toUtc();
    } else {
      user.phoneVerifiedAt = _now().toUtc();
    }
    return const Ok(MessageResponse(message: 'OTP verified successfully.'));
  }

  Result<MessageResponse> resendOtp(ResendOtpRequest request) {
    const sent = MessageResponse(
      message: 'A new verification code has been sent.',
    );
    final target = _normalizeTarget(request.target);
    final user = _resolve(request.target);
    if (user == null) {
      // Nothing is sent, but the answer and the cooldown are the same.
      final held = _holdCooldown(target, request.purpose);
      return held == null ? const Ok(sent) : Err(held);
    }
    final channel = switch (request.purpose) {
      OtpPurpose.emailVerification => OtpChannel.email,
      OtpPurpose.phoneVerification => OtpChannel.sms,
      _ => codesByEmail ? OtpChannel.email : request.channel,
    };
    final deliverTo = channel == OtpChannel.email ? user.email : user.phone;
    if (deliverTo == null) {
      final held = _holdCooldown(target, request.purpose);
      return held == null ? const Ok(sent) : Err(held);
    }
    final issued = _issue(
      target,
      channel,
      request.purpose,
      deliverTo: deliverTo,
    );
    return issued == null ? const Ok(sent) : Err(issued);
  }

  Result<TokenPairResponse> login(LoginRequest request) {
    if (request.password.isEmpty) {
      return _validationError([
        _fieldError('password', 'String should have at least 1 character'),
      ]);
    }
    final user = _resolve(request.identifier);
    if (user == null) return _invalidCredentials();
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    if (request.password != user.password) {
      user.failedLogins++;
      if (user.failedLogins >= loginMaxFailedAttempts) {
        user.lockedUntil = _now().toUtc().add(loginLockout);
      }
      return _invalidCredentials();
    }
    if (!user.isVerified) {
      return _error(
        403,
        'ACCOUNT_NOT_VERIFIED',
        'Verify your account with the code sent to you before logging in.',
        {
          'target': codesByEmail && user.email != null
              ? user.email
              : user.phone,
          'purpose': 'registration',
        },
      );
    }
    user
      ..failedLogins = 0
      ..lockedUntil = null;
    return Ok(_issueTokens(user));
  }

  Result<TokenPairResponse> otpLogin(OtpLoginRequest request) {
    final invalid = _codeFieldErrors(request.code);
    if (invalid != null) return _validationError(invalid);
    final user = _resolve(request.target);
    if (user == null) {
      return _error(404, 'NOT_FOUND', 'No account found for this identifier.');
    }
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    final verified = _verify(
      _normalizeTarget(request.target),
      OtpPurpose.login,
      request.code,
    );
    if (verified case Err(:final failure)) return Err(failure);
    // The code reached the user, which proves where it went.
    if (verified.valueOrNull!.channel == OtpChannel.email) {
      user.emailVerifiedAt ??= _now().toUtc();
    } else {
      user.phoneVerifiedAt ??= _now().toUtc();
    }
    user
      ..failedLogins = 0
      ..lockedUntil = null;
    return Ok(_issueTokens(user));
  }

  Result<TokenPairResponse> refresh(RefreshRequest request) {
    if (request.refreshToken.length < 20) {
      return _validationError([
        _fieldError(
          'refresh_token',
          'String should have at least 20 characters',
        ),
      ]);
    }
    final stored = _refreshTokens[request.refreshToken];
    if (stored == null) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired refresh token.');
    }
    if (stored.revoked) {
      // A rotated token used again: assume it was stolen.
      _revokeAllSessions(stored.userId);
      return _error(
        401,
        'REFRESH_TOKEN_REUSE_DETECTED',
        'This refresh token has already been used. All sessions have been '
            'revoked.',
      );
    }
    if (!stored.expiresAt.isAfter(_now())) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired refresh token.');
    }
    final session = _sessions[stored.sessionId];
    if (session == null || session.revoked) {
      return _error(401, 'UNAUTHORIZED', 'This session has been revoked.');
    }
    final user = _users.firstWhere((u) => u.id == stored.userId);
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    final pair = _tokensForSession(user, session.id);
    stored.revoked = true;
    return Ok(pair);
  }

  Result<void> logout(String? accessToken) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _revokeSession(auth.valueOrNull!.sessionId);
    return const Ok(null);
  }

  Result<UserResponse> getMe(String? accessToken) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    final user = _users.firstWhere((u) => u.id == auth.valueOrNull!.userId);
    return Ok(user.toResponse());
  }

  /// `GET /drivers/me`: driver role required, then a profile.
  Result<DriverResponse> getDriverMe(String? accessToken) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    final user = _users.firstWhere((u) => u.id == auth.valueOrNull!.userId);
    if (!user.roles.contains('driver')) {
      return _error(
        403,
        'FORBIDDEN',
        'You do not have permission to perform this action.',
      );
    }
    final profile = _driverProfiles[user.id];
    if (profile == null) {
      return _error(
        404,
        'NOT_FOUND',
        'No driver profile exists for this account.',
      );
    }
    return Ok(profile);
  }

  /// `GET /stops/nearby` (public): stops within [radiusM], nearest first.
  Result<List<NearbyStopResponse>> nearbyStops({
    required double latitude,
    required double longitude,
    int? radiusM,
    int? limit,
  }) {
    final radius = radiusM ?? pickupMaxWalkMeters;
    final near =
        [
            for (final stop in stops.values)
              (
                stop,
                distanceMeters(
                  latitude,
                  longitude,
                  stop.latitude,
                  stop.longitude,
                ),
              ),
          ].where((s) => s.$2 <= radius).toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    return Ok([
      for (final (stop, distance) in near.take(limit ?? pickupNearbyLimit))
        NearbyStopResponse(
          id: stop.id,
          name: stop.name,
          city: 'Accra',
          region: 'Greater Accra',
          latitude: stop.latitude,
          longitude: stop.longitude,
          distanceM: (distance * 10).roundToDouble() / 10,
        ),
    ]);
  }

  /// `GET /users/me/favourite-routes`.
  Result<List<FavouriteRouteResponse>> listFavouriteRoutes(
    String? accessToken,
  ) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    return Ok([...?_favourites[auth.valueOrNull!.userId]]);
  }

  /// `GET /vehicles/nearby`: the three design vehicles around the point,
  /// those within [radiusM], nearest first.
  Result<List<NearbyVehicleResponse>> nearbyVehicles(
    String? accessToken, {
    required double latitude,
    required double longitude,
    required int radiusM,
    int limit = 20,
  }) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    if (!vehiclesOnTheRoad) return const Ok([]);
    // Metres east and north of the point. P5 draws the pins at (80, 60),
    // (310, 130) and (145, 190) around the map centre (195, 110); at the
    // Home map's zoom (13) a pixel is about 19 m in Accra.
    const designed = [
      ('Madina → Circle', 'GR 2417-24', -2185.0, 950.0, 5),
      ('Legon → Osu', 'GT 8830-23', 2185.0, -380.0, 8),
      ('Achimota → Tema', 'GE 1196-25', -950.0, -1520.0, 2),
    ];
    final vehicles = <NearbyVehicleResponse>[];
    for (final (i, (route, plate, east, north, seats)) in designed.indexed) {
      final lat = latitude + north / _metersPerDegree;
      final lng =
          longitude +
          east / (_metersPerDegree * math.cos(latitude * math.pi / 180));
      final distance = distanceMeters(latitude, longitude, lat, lng);
      if (distance > radiusM) continue;
      vehicles.add(
        NearbyVehicleResponse(
          tripId: '7e${i}c4b1a-9d2f-4a8e-b6c3-1f5e8d2a7c90',
          vehicleId: '3b${i}a9e2c-6f1d-4c7b-8e5a-2d9f1c6b4e83',
          vehicleRegistrationNumber: plate,
          vehicleType: VehicleType.minibus,
          routeId: '9c${i}e3f7a-1b5d-4e2c-a8f6-4d1b7e9c3a52',
          routeName: route,
          latitude: lat,
          longitude: lng,
          distanceM: (distance * 10).roundToDouble() / 10,
          availableSeats: seats,
          updatedAt: _now().toUtc().subtract(const Duration(seconds: 20)),
        ),
      );
    }
    vehicles.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return Ok(vehicles.take(limit).toList());
  }

  /// `POST /users/me/favourite-routes`.
  Result<FavouriteRouteResponse> addFavouriteRoute(
    String? accessToken,
    FavouriteRouteCreateRequest request,
  ) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    if (request.originStopId == request.destinationStopId) {
      return _validationError([
        _fieldError(
          'destination_stop_id',
          'origin_stop_id and destination_stop_id must be different.',
        ),
      ]);
    }
    final from = _stopById(request.originStopId);
    final to = _stopById(request.destinationStopId);
    for (final (id, stop) in [
      (request.originStopId, from),
      (request.destinationStopId, to),
    ]) {
      if (stop == null) {
        return _error(404, 'NOT_FOUND', 'Stop not found.', {'stop_id': id});
      }
    }
    final mine = _favourites.putIfAbsent(auth.valueOrNull!.userId, () => []);
    if (mine.length >= favouriteRoutesMax) {
      return _error(
        409,
        'FAVOURITE_ROUTES_LIMIT',
        'You can save up to $favouriteRoutesMax favourite routes. '
            'Remove one first.',
      );
    }
    if (mine.any(
      (f) =>
          f.originStopId == request.originStopId &&
          f.destinationStopId == request.destinationStopId,
    )) {
      return _error(
        409,
        'FAVOURITE_ROUTE_EXISTS',
        'This journey is already in your favourites.',
      );
    }
    final label = request.label?.trim();
    final route = FavouriteRouteResponse(
      id: _uuid(),
      originStopId: from!.id,
      originStopName: from.name,
      destinationStopId: to!.id,
      destinationStopName: to.name,
      label: label == null || label.isEmpty ? null : label,
      createdAt: _now().toUtc(),
    );
    mine.add(route);
    return Ok(route);
  }

  /// `GET /stops?q=` (public): stops whose name contains [query], by name.
  Result<List<StopResponse>> searchStops(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      return _validationError([
        {
          'type': 'string_too_short',
          'loc': ['query', 'q'],
          'msg': 'String should have at least 2 characters',
        },
      ]);
    }
    final found =
        stops.values.where((s) => s.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Ok([for (final stop in found.take(limit)) _stopResponse(stop)]);
  }

  /// `GET /trips/search` (public), for journeys between two stops.
  ///
  /// The pickup is the chosen stop, else the nearest stop within walking
  /// distance of the position (422 `NO_PICKUP_NEARBY` with none).
  ///
  /// The day's trips: for a search from now, the five P6 vehicles around
  /// the current minute (approaching ones 3, 7 and 12 minutes from the
  /// stop, two that passed it), with the G20 and G21 fields the design
  /// shows; then, on any day, a departure every 15 minutes from 05:30 to
  /// 22:00, one in four of them full.
  Result<Paginated<TripSearchResultResponse>> searchTrips(
    TripSearchQuery query,
  ) {
    if ((query.pickupLatitude == null) != (query.pickupLongitude == null)) {
      return _error(
        422,
        'VALIDATION_ERROR',
        'Provide both a latitude and a longitude, or neither.',
        {'latitude': query.pickupLatitude, 'longitude': query.pickupLongitude},
      );
    }
    MockStop? board;
    double? walk;
    PickupSource? source;
    final lat = query.pickupLatitude;
    final lng = query.pickupLongitude;
    if (query.originStopId case final id?) {
      board = _stopById(id);
      if (board == null) return _error(404, 'NOT_FOUND', 'Stop not found.');
      source = PickupSource.manual;
      if (lat != null && lng != null) {
        walk = distanceMeters(lat, lng, board.latitude, board.longitude);
      }
    } else if (lat != null && lng != null) {
      final near = nearbyStops(latitude: lat, longitude: lng).valueOrNull!;
      if (near.isEmpty) {
        return _error(
          422,
          'NO_PICKUP_NEARBY',
          'No pickup point is within walking distance of your location.',
          {
            'max_walk_meters': pickupMaxWalkMeters,
            'hint': 'Search for a pickup point by name instead.',
          },
        );
      }
      board = _stopById(near.first.id);
      walk = near.first.distanceM;
      source = PickupSource.gps;
    }
    final alight = query.destinationStopId == null
        ? null
        : _stopById(query.destinationStopId!);
    final trips = board == null || alight == null || board == alight
        ? <TripSearchResultResponse>[]
        : _trips(query, board, alight, walk, source!);
    for (final trip in trips) {
      _tripIndex.putIfAbsent(
        trip.tripId,
        () => _MockTrip(trip, board!, alight!, _now()),
      );
    }
    final shown = [
      for (final trip in trips)
        if (query.vehicleType == null || trip.vehicleType == query.vehicleType)
          trip,
    ];
    double current(TripSearchResultResponse t) => double.parse(t.fare!.current);
    int order(TripSearchResultResponse a, TripSearchResultResponse b) {
      if (a.hasPassedPickup != b.hasPassedPickup) {
        return a.hasPassedPickup ? 1 : -1;
      }
      final byKey = switch (query.sort) {
        SearchSort.departure => 0,
        SearchSort.cheapest => current(a).compareTo(current(b)),
        SearchSort.fastest => (a.rideMinutes ?? 0).compareTo(
          b.rideMinutes ?? 0,
        ),
      };
      return byKey != 0
          ? byKey
          : a.scheduledDepartureAt.compareTo(b.scheduledDepartureAt);
    }

    // A stable sort: equal keys keep departure order.
    final sorted = [for (final (i, trip) in shown.indexed) (i, trip)]
      ..sort((a, b) {
        final byOrder = order(a.$2, b.$2);
        return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final (_, trip) in sorted) trip];
    return Ok(
      Paginated(
        items: ordered.skip(query.offset).take(query.limit).toList(),
        total: ordered.length,
        limit: query.limit,
        offset: query.offset,
      ),
    );
  }

  List<TripSearchResultResponse> _trips(
    TripSearchQuery query,
    MockStop board,
    MockStop alight,
    double? walk,
    PickupSource source,
  ) {
    final now = _now().toUtc();
    final minute = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final day = DateTime.utc(
      query.travelDate.year,
      query.travelDate.month,
      query.travelDate.day,
    );
    final after = day.add(query.departureAfter ?? Duration.zero);
    final before = day.add(
      query.departureBefore ?? const Duration(hours: 23, minutes: 59),
    );
    // A search from now (as "Now" sends it) gets the live vehicles of G21.
    final fromNow =
        day == DateTime.utc(now.year, now.month, now.day) &&
        after.difference(now).abs() <= const Duration(minutes: 2);

    TripSearchResultResponse trip({
      required DateTime departs,
      required int minutes,
      required VehicleType type,
      required String plate,
      required int seats,
      required int solo,
      required int shared,
      int? etaMinutes,
      bool? passed,
    }) {
      final key = departs.hour * 60 + departs.minute;
      return TripSearchResultResponse(
        tripId: _tripId(board, alight, key, departs),
        routeId:
            '${_hash('${board.name}>${alight.name}')}-3c9d-4a20-9000-'
            '000000000000',
        routeName: '${board.name} – ${alight.name}',
        originStopId: board.id,
        destinationStopId: alight.id,
        scheduledDepartureAt: departs,
        scheduledArrivalAt: departs.add(Duration(minutes: minutes)),
        estimatedDurationMinutes: minutes,
        distanceKm: 14,
        fareAmount: '$solo.00',
        status: TripStatus.scheduled,
        availableSeats: seats,
        vehicleRegistrationNumber: plate,
        vehicleType: type,
        pickupStopId: board.id,
        pickupStopName: board.name,
        pickupDistanceM: walk == null ? null : (walk * 10).roundToDouble() / 10,
        pickupSource: source,
        fare: _fareSummary(
          current: shared.toDouble(),
          solo: solo.toDouble(),
          minimum: type == VehicleType.minibus ? 6 : solo * 0.25,
          seats: 1,
          riders: 0,
        ),
        rideMinutes: minutes,
        vehicleEtaToPickupMinutes: etaMinutes,
        hasPassedPickup: passed ?? false,
      );
    }

    final trips = <TripSearchResultResponse>[
      if (fromNow) ...[
        // P6, in the design's order of departure.
        for (final (
              offset,
              minutes,
              type,
              plate,
              seats,
              solo,
              shared,
              eta,
              passed,
            )
            in const [
              (-14, 50, VehicleType.minibus, 'GR-1190', 0, 38, 14, null, true),
              (-10, 50, VehicleType.sedan, 'GR-5531', 3, 45, 16, null, true),
              (3, 50, VehicleType.minibus, 'GR-4821', 5, 38, 14, 3, false),
              (10, 48, VehicleType.sedan, 'GR-2204', 2, 45, 18, 7, false),
              (18, 50, VehicleType.minibus, 'GR-7743', 9, 38, 12, 12, false),
            ])
          trip(
            departs: minute.add(Duration(minutes: offset)),
            minutes: minutes,
            type: type,
            plate: plate,
            seats: seats,
            solo: solo,
            shared: shared,
            etaMinutes: eta,
            passed: passed,
          ),
      ],
      for (var k = 0; k <= 66; k++)
        if (day.add(Duration(minutes: 330 + 15 * k)) case final departs
            when !departs.isBefore(
                  fromNow ? minute.add(const Duration(minutes: 25)) : after,
                ) &&
                !departs.isAfter(before))
          trip(
            departs: departs,
            minutes: 50,
            type: const [
              VehicleType.minibus,
              VehicleType.sedan,
              VehicleType.minibus,
              VehicleType.bus,
            ][k % 4],
            plate: 'GR-${(3017 + 389 * k) % 9000 + 1000}',
            seats: const [11, 3, 0, 18][k % 4],
            solo: const [38, 45, 38, 30][k % 4],
            shared: const [13, 20, 15, 10][k % 4],
          ),
    ]..sort((a, b) => a.scheduledDepartureAt.compareTo(b.scheduledDepartureAt));
    return trips;
  }

  String _tripId(MockStop board, MockStop alight, int key, DateTime departs) {
    final day = departs.year * 10000 + departs.month * 100 + departs.day;
    return '${_hash('${board.name}>${alight.name}')}-'
        '${(key % 10000).toString().padLeft(4, '0')}-4000-8000-'
        '${day.toString().padLeft(12, '0')}';
  }

  static String _hash(String text) => text.codeUnits
      .fold<int>(17, (hash, unit) => (hash * 31 + unit) & 0xffffffff)
      .toRadixString(16)
      .padLeft(8, '0');

  MockStop? _stopById(String id) =>
      stops.values.where((s) => s.id == id).firstOrNull;

  StopResponse _stopResponse(MockStop stop) => StopResponse(
    id: stop.id,
    name: stop.name,
    city: 'Accra',
    region: 'Greater Accra',
    latitude: stop.latitude,
    longitude: stop.longitude,
  );

  /// `GET /trips/{id}/seats` (public), with the G20 fares the P7 design
  /// shows. On a minibus another rider books a seat each time 10 seconds
  /// have passed since the last one, while [simulateRiders] is on.
  Result<TripSeatsResponse> tripSeats(String tripId) {
    _expireHolds();
    final trip = _tripIndex[tripId];
    if (trip == null) return _error(404, 'NOT_FOUND', 'Trip not found.');
    if (simulateRiders && trip.minibus) _simulateRider(trip);
    final held = _heldSeatIds(tripId);
    final seats = [
      for (final seat in trip.seats)
        TripSeatResponse(
          id: seat.id,
          seatNumber: seat.number,
          rowNumber: seat.row,
          columnNumber: seat.column,
          seatType: seat.type,
          isAvailable:
              !trip.takenByOthers.contains(seat.id) && !held.contains(seat.id),
        ),
    ];
    return Ok(
      TripSeatsResponse(
        tripId: tripId,
        vehicleId: 'veh-${trip.result.vehicleRegistrationNumber}',
        totalSeats: seats.length,
        availableSeats: seats.where((s) => s.isAvailable).length,
        seats: seats,
      ),
    );
  }

  /// `GET /trips/{id}` (public): the trip with its route, vehicle, driver
  /// and how full it is.
  Result<TripDetailResponse> tripDetail(String tripId) {
    _expireHolds();
    final trip = _tripIndex[tripId];
    if (trip == null) return _error(404, 'NOT_FOUND', 'Trip not found.');
    final result = trip.result;
    final (name, rating, ratings) =
        _drivers[tripId.codeUnits.fold(0, (a, b) => a + b) % _drivers.length];
    final booked = _booked(trip);
    final type = result.vehicleType ?? VehicleType.other;
    return Ok(
      TripDetailResponse(
        id: tripId,
        routeId: result.routeId,
        scheduledDepartureAt: result.scheduledDepartureAt,
        scheduledArrivalAt:
            result.scheduledArrivalAt ??
            result.scheduledDepartureAt.add(
              Duration(minutes: result.estimatedDurationMinutes ?? 45),
            ),
        status: trip.status,
        fareAmount: result.fareAmount,
        routeName: result.routeName,
        originStopId: trip.board.id,
        originStopName: trip.board.name,
        destinationStopId: trip.alight.id,
        destinationStopName: trip.alight.name,
        vehicle: result.vehicleRegistrationNumber == null
            ? null
            : TripVehicleResponse(
                registrationNumber: result.vehicleRegistrationNumber!,
                type: type,
                makeModel: switch (type) {
                  VehicleType.minibus => 'Toyota Hiace',
                  VehicleType.bus => 'Yutong ZK6107',
                  VehicleType.sedan => 'Toyota Corolla',
                  VehicleType.shuttle => 'Ford Transit',
                  VehicleType.other => null,
                },
                capacity: trip.seats.length,
              ),
        driver: TripDriverResponse(
          id: 'd${tripId.substring(1)}',
          fullName: name,
          averageRating: rating,
          ratingCount: ratings,
        ),
        ridersCount: booked,
        seatsTotal: trip.seats.length,
        availableSeats: trip.seats.length - booked,
      ),
    );
  }

  /// Who drives the mock's trips: name, rating and how many ratings.
  static const List<(String, double, int)> _drivers = [
    ('Kwame Mensah', 4.8, 126),
    ('Kofi Boateng', 4.9, 212),
    ('Yaw Asante', 4.6, 58),
    ('Abena Owusu', 4.7, 94),
    ('Kojo Antwi', 4.5, 37),
  ];

  /// `GET /trips/{id}/fare-quote` (public): [seats] seats between the
  /// trip's stops as it stands now, with the P7 fares on a minibus. The
  /// mock prices each seat the same, however many are asked for.
  Result<FareQuoteResponse> fareQuote(
    String tripId, {
    String? originStopId,
    String? destinationStopId,
    int seats = 1,
  }) {
    _expireHolds();
    final trip = _tripIndex[tripId];
    if (trip == null) return _error(404, 'NOT_FOUND', 'Trip not found.');
    for (final (id, role) in [
      (originStopId, 'origin'),
      (destinationStopId, 'destination'),
    ]) {
      if (id != null && id != trip.board.id && id != trip.alight.id) {
        return _error(
          422,
          'STOP_NOT_ON_ROUTE',
          "That stop is not on this trip's route.",
          {'stop_id': id, 'role': role},
        );
      }
    }
    final fares = trip.fares(_booked(trip));
    final summary = _fareSummary(
      current: double.parse(fares.shared),
      solo: double.parse(fares.solo),
      minimum: double.parse(fares.floor),
      seats: seats,
      riders: _booked(trip),
    );
    return Ok(
      FareQuoteResponse(
        tripId: tripId,
        originStopId: originStopId ?? trip.board.id,
        destinationStopId: destinationStopId ?? trip.alight.id,
        current: summary.current,
        solo: summary.solo,
        minimum: summary.minimum,
        platformFee: summary.platformFee,
        total: summary.total,
        currency: summary.currency,
        ridersCount: summary.ridersCount,
        seats: summary.seats,
      ),
    );
  }

  /// A fare as the backend sends it: [current] a seat, plus the flat
  /// platform fee per seat.
  static FareSummaryResponse _fareSummary({
    required double current,
    required double solo,
    required double minimum,
    required int seats,
    required int riders,
  }) {
    final fee = double.parse(platformFeePerSeat) * seats;
    return FareSummaryResponse(
      current: current.toStringAsFixed(2),
      solo: solo.toStringAsFixed(2),
      minimum: minimum.toStringAsFixed(2),
      platformFee: fee.toStringAsFixed(2),
      total: (current * seats + fee).toStringAsFixed(2),
      currency: 'GHS',
      ridersCount: riders,
      seats: seats,
    );
  }

  /// `POST /bookings`: holds the seats, waiting [acceptTimeout] for the
  /// driver (or, with [bookingAcceptanceRequired] off, [seatHold] to pay).
  Result<BookingResponse> createBooking(
    String? accessToken,
    BookingCreateRequest request,
  ) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _expireHolds();
    final user = _users.firstWhere((u) => u.id == auth.valueOrNull!.userId);
    if (!user.isVerified) {
      return _error(
        403,
        'ACCOUNT_NOT_VERIFIED',
        'Verify your account with the code sent to you before booking.',
      );
    }
    final seatIds = [for (final p in request.passengers) p.seatId];
    if (seatIds.isEmpty || seatIds.length > bookingMaxSeats) {
      return _validationError([
        _fieldError(
          'passengers',
          'List should have between 1 and $bookingMaxSeats items',
        ),
      ]);
    }
    if (seatIds.toSet().length != seatIds.length) {
      return _validationError([
        _fieldError(
          'passengers',
          'Each passenger must occupy a distinct seat.',
        ),
      ]);
    }
    if ((request.pickupLatitude == null) != (request.pickupLongitude == null)) {
      return _validationError([
        _fieldError(
          'pickup_latitude',
          'Provide both pickup_latitude and pickup_longitude, or neither.',
        ),
      ]);
    }
    final trip = _tripIndex[request.tripId];
    if (trip == null) return _error(404, 'NOT_FOUND', 'Trip not found.');
    if (trip.closed) {
      return _error(
        409,
        'TRIP_NOT_BOOKABLE',
        'This trip is not currently open for booking.',
      );
    }
    final ids = {for (final seat in trip.seats) seat.id};
    for (final id in seatIds) {
      if (!ids.contains(id)) {
        return _error(
          404,
          'NOT_FOUND',
          "Seat $id does not belong to this trip's vehicle.",
        );
      }
    }
    final held = _heldSeatIds(trip.result.tripId);
    for (final id in seatIds) {
      if (trip.takenByOthers.contains(id) || held.contains(id)) {
        return _error(
          409,
          'SEAT_NOT_AVAILABLE',
          'That seat was just taken. Please choose another seat.',
          {'seat_id': id},
        );
      }
    }
    final fares = trip.fares(_booked(trip));
    final perSeat = double.parse(fares.shared);
    final fare = perSeat * seatIds.length;
    final fee = double.parse(platformFeePerSeat) * seatIds.length;
    final now = _now().toUtc();
    final booking = _MockBooking(
      number: _bookings.values.where((b) => !b.seeded).length,
      id: _uuid(),
      reference: 'TS-${_reference()}',
      userId: user.id,
      trip: trip,
      seatIds: seatIds,
      originStopId: request.originStopId ?? trip.board.id,
      destinationStopId: request.destinationStopId ?? trip.alight.id,
      fare: fare.toStringAsFixed(2),
      fee: fee.toStringAsFixed(2),
      total: (fare + fee).toStringAsFixed(2),
      solo: (double.parse(fares.solo) * seatIds.length).toStringAsFixed(2),
      status: bookingAcceptanceRequired
          ? BookingStatus.awaitingAcceptance
          : BookingStatus.pending,
      expiresAt: now.add(bookingAcceptanceRequired ? acceptTimeout : seatHold),
      createdAt: now,
      passengers: [
        for (final p in request.passengers)
          BookingPassengerResponse(
            id: _uuid(),
            seatId: p.seatId,
            fullName: p.fullName,
            phoneNumber: p.phoneNumber,
          ),
      ],
    );
    _bookings[booking.id] = booking;
    return Ok(booking.toResponse(_now().toUtc()));
  }

  /// `GET /bookings`: the passenger's bookings, newest first, or by trip
  /// time with [upcoming].
  Result<Paginated<BookingResponse>> listBookings(
    String? accessToken, {
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  }) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _expireHolds();
    final now = _now().toUtc();
    // Ahead: departing now or later, or under way.
    bool ahead(_MockBooking b) =>
        !b.trip.result.scheduledDepartureAt.isBefore(now) ||
        const {
          TripStatus.boarding,
          TripStatus.inProgress,
          TripStatus.paused,
        }.contains(b.trip.status);
    final mine = _bookings.values
        .where((b) => b.userId == auth.valueOrNull!.userId)
        .where((b) => statuses == null || statuses.contains(b.status))
        .where((b) => upcoming == null || ahead(b) == upcoming)
        .toList();
    // Upcoming soonest first, past most recent first, else newest booking
    // first.
    mine.sort((a, b) {
      final departs = a.trip.result.scheduledDepartureAt.compareTo(
        b.trip.result.scheduledDepartureAt,
      );
      return switch (upcoming) {
        true when departs != 0 => departs,
        false when departs != 0 => -departs,
        _ => b.createdAt.compareTo(a.createdAt),
      };
    });
    return Ok(
      Paginated(
        items: [
          for (final b in mine.skip(offset).take(limit))
            b.toResponse(_now().toUtc()),
        ],
        total: mine.length,
        limit: limit,
        offset: offset,
      ),
    );
  }

  /// `GET /bookings/summary` (G25): the passenger's paid trips departing
  /// in [month] ("2026-10"; default this month), what they cost with fees,
  /// and what sharing saved.
  Result<BookingSummaryResponse> bookingSummary(
    String? accessToken, {
    String? month,
  }) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _expireHolds();
    final now = _now().toUtc();
    var start = DateTime.utc(now.year, now.month);
    if (month != null) {
      final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(month);
      if (match == null) {
        return _validationError([
          _fieldError(
            'month',
            r"String should match pattern '^\d{4}-(0[1-9]|1[0-2])$'",
          ),
        ]);
      }
      start = DateTime.utc(int.parse(match[1]!), int.parse(match[2]!));
    }
    final end = DateTime.utc(start.year, start.month + 1);
    final paid = [
      for (final b in _bookings.values)
        if (b.userId == auth.valueOrNull!.userId &&
            const {
              BookingStatus.confirmed,
              BookingStatus.completed,
            }.contains(b.status) &&
            !b.trip.result.scheduledDepartureAt.isBefore(start) &&
            b.trip.result.scheduledDepartureAt.isBefore(end))
          b,
    ];
    final spent = paid.fold<double>(0, (sum, b) => sum + double.parse(b.total));
    final saved = paid.fold<double>(
      0,
      (sum, b) =>
          sum +
          math.max(0, double.parse(b.solo ?? b.fare) - double.parse(b.fare)),
    );
    return Ok(
      BookingSummaryResponse(
        month: '${start.year}-${start.month.toString().padLeft(2, '0')}',
        currency: 'GHS',
        tripsCount: paid.length,
        totalSpent: spent.toStringAsFixed(2),
        averageFare: (paid.isEmpty ? 0 : spent / paid.length).toStringAsFixed(
          2,
        ),
        totalSaved: saved.toStringAsFixed(2),
      ),
    );
  }

  /// `GET /bookings/{id}`.
  Result<BookingResponse> getBooking(String? accessToken, String bookingId) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _expireHolds();
    final booking = _bookings[bookingId];
    if (booking == null || booking.userId != auth.valueOrNull!.userId) {
      return _error(404, 'NOT_FOUND', 'Booking not found.');
    }
    return Ok(booking.toResponse(_now().toUtc()));
  }

  /// `POST /bookings/{id}/cancel`. Before the trip starts, or while no
  /// driver has accepted it, at once: the seats go back and the booking is
  /// `cancelled`, or `refund_pending` when it was paid. Once the trip has
  /// started, the request waits for an admin and the booking stays as it
  /// is.
  Result<BookingResponse> cancelBooking(
    String? accessToken,
    String bookingId, {
    String? reason,
  }) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _expireHolds();
    final booking = _bookings[bookingId];
    if (booking == null || booking.userId != auth.valueOrNull!.userId) {
      return _error(404, 'NOT_FOUND', 'Booking not found.');
    }
    if (const {
      BookingStatus.cancelled,
      BookingStatus.expired,
      BookingStatus.completed,
      BookingStatus.refunded,
    }.contains(booking.status)) {
      return _error(
        409,
        'INVALID_STATE_TRANSITION',
        "A booking in status '${bookingStatusName(booking.status)}' cannot "
            'be cancelled.',
      );
    }
    final started = booking.trip.status != TripStatus.scheduled;
    if (started && booking.status != BookingStatus.awaitingAcceptance) {
      booking.cancellationRequested = true;
    } else {
      booking.status = booking.status == BookingStatus.confirmed
          ? BookingStatus.refundPending
          : BookingStatus.cancelled;
    }
    return Ok(booking.toResponse(_now().toUtc()));
  }

  int _booked(_MockTrip trip) =>
      trip.takenByOthers.length + _heldSeatIds(trip.result.tripId).length;

  /// Seats held or confirmed by bookings on [tripId].
  Set<String> _heldSeatIds(String tripId) => {
    for (final b in _bookings.values)
      if (b.trip.result.tripId == tripId &&
          const {
            BookingStatus.awaitingAcceptance,
            BookingStatus.pending,
            BookingStatus.paymentPending,
            BookingStatus.confirmed,
          }.contains(b.status))
        ...b.seatIds,
  };

  /// What the background jobs and the scripted drivers did by now: drivers
  /// answer, unanswered requests move or end (`move_unanswered_bookings`),
  /// and lapsed holds release their seats (`expire_stale_bookings`).
  void _expireHolds() {
    final now = _now().toUtc();
    for (final b in _bookings.values) {
      if (b.rolling != null) continue;
      // A move opens a new request, which may be answered or lapse too.
      for (var step = 0; step <= bookingMaxMoves + 1; step++) {
        if (b.status != BookingStatus.awaitingAcceptance) break;
        if (_scriptedAnswer(b, now)) continue;
        if (b.expiresAt.isAfter(now)) break;
        _moveOrEnd(b, BookingStatus.expired, from: b.expiresAt);
      }
      if (b.status == BookingStatus.pending && !b.expiresAt.isAfter(now)) {
        b.status = BookingStatus.expired;
      }
    }
  }

  /// The [driverScript]'s answer to [b]'s request, if it is due by [now].
  bool _scriptedAnswer(_MockBooking b, DateTime now) {
    final script = b.seeded ? null : driverScript?.forBooking(b.number);
    if (script == null) return false;
    final answerAt = b.requestedAt.add(driverAnswersAfter);
    if (answerAt.isAfter(now) || !answerAt.isBefore(b.expiresAt)) {
      return false;
    }
    switch (script) {
      case MockDriverScript.accept:
        _accept(b, answerAt);
      case MockDriverScript.moveThenAccept:
        // The first driver lets the request lapse; the next one accepts.
        if (b.moves == 0) return false;
        _accept(b, answerAt);
      case MockDriverScript.decline:
        // No other vehicle going that way has seats.
        _end(b, BookingStatus.cancelled);
      case MockDriverScript.rotate:
        // forBooking has taken its turn.
        return false;
    }
    return true;
  }

  /// `BookingAcceptanceService.accept`: pending, [seatHold] to pay from [at].
  void _accept(_MockBooking b, DateTime at) {
    b
      ..status = BookingStatus.pending
      ..expiresAt = at.add(seatHold);
  }

  /// `_move_or_end`: onto the nearest other trip from the same pickup to the
  /// same destination that has seats for everyone on [b], still waiting for
  /// a driver ([acceptTimeout] from [from]); after [bookingMaxMoves] moves,
  /// or with no such trip, it ends as [ending].
  void _moveOrEnd(
    _MockBooking b,
    BookingStatus ending, {
    required DateTime from,
  }) {
    if (b.moves < bookingMaxMoves) {
      final departs = b.trip.result.scheduledDepartureAt;
      final others =
          _tripIndex.values
              .where(
                (t) =>
                    !t.closed &&
                    !b.tried.contains(t.result.tripId) &&
                    t.board.id == b.trip.board.id &&
                    t.alight.id == b.trip.alight.id &&
                    t.result.scheduledDepartureAt.difference(departs).abs() <=
                        bookingMoveWindow,
              )
              .toList()
            ..sort(
              (x, y) => x.result.scheduledDepartureAt
                  .difference(departs)
                  .abs()
                  .compareTo(
                    y.result.scheduledDepartureAt.difference(departs).abs(),
                  ),
            );
      for (final trip in others) {
        final held = _heldSeatIds(trip.result.tripId);
        final free = [
          for (final seat in trip.seats)
            if (!trip.takenByOthers.contains(seat.id) &&
                !held.contains(seat.id))
              seat.id,
        ];
        if (free.length < b.seatIds.length) continue;
        final seats = free.take(b.seatIds.length).toList();
        b
          ..trip = trip
          ..seatIds = seats
          ..passengers = [
            for (final (i, p) in b.passengers.indexed)
              p.copyWith(seatId: seats[i]),
          ]
          ..tried.add(trip.result.tripId)
          ..moves += 1
          ..requestedAt = from
          ..expiresAt = from.add(acceptTimeout);
        return;
      }
    }
    _end(b, ending);
  }

  void _end(_MockBooking b, BookingStatus ending) => b.status = ending;

  /// The P7 riders: one more seat every 10 s, while 12 or fewer are booked.
  void _simulateRider(_MockTrip trip) {
    final now = _now();
    if (now.difference(trip.lastRider) < const Duration(seconds: 10)) return;
    if (_booked(trip) >= 12) return;
    final held = _heldSeatIds(trip.result.tripId);
    for (final number in const ['7', '13', '3', '10', '14', '1', '5', '8']) {
      final seat = trip.seats.firstWhere((s) => s.number == number);
      if (!trip.takenByOthers.contains(seat.id) && !held.contains(seat.id)) {
        trip.takenByOthers.add(seat.id);
        trip.lastRider = now;
        return;
      }
    }
  }

  /// Ama Mensah's bookings around now: three ahead (paid, waiting for the
  /// driver, accepted and not paid), one on a trip under way, and the
  /// past week (completed, cancelled, refunded, a refund waiting for
  /// approval, expired). Fixed ids and references, so the counter-made
  /// ones of the tests don't move.
  void _seedHistory() {
    final now = _now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const userId = '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41';
    var n = 0;
    void book({
      required String from,
      required String to,
      required DateTime departs,
      required int minutes,
      required VehicleType vehicle,
      required String plate,
      required String perSeat,
      required String solo,
      required List<String> seats,
      required BookingStatus status,
      required String reference,
      TripStatus trip = TripStatus.scheduled,
      Duration? rolling,
    }) {
      n++;
      final id = n.toString().padLeft(2, '0');
      final board = stops[from]!;
      final alight = stops[to]!;
      final result = TripSearchResultResponse(
        tripId: 'c00000$id-4a1e-4000-8000-0000000000$id',
        routeId: 'e00000$id-4a1e-4000-8000-0000000000$id',
        routeName: '$from → $to',
        originStopId: board.id,
        destinationStopId: alight.id,
        scheduledDepartureAt: departs,
        scheduledArrivalAt: departs.add(Duration(minutes: minutes)),
        estimatedDurationMinutes: minutes,
        fareAmount: perSeat,
        status: TripStatus.scheduled,
        availableSeats: 0,
        vehicleRegistrationNumber: plate,
        vehicleType: vehicle,
      );
      final mockTrip = _MockTrip(result, board, alight, now)
        ..status = trip
        ..closed = trip != TripStatus.scheduled || departs.isBefore(now);
      _tripIndex[result.tripId] = mockTrip;
      final seatIds = [
        for (final number in seats)
          mockTrip.seats.firstWhere((seat) => seat.number == number).id,
      ];
      final fare = double.parse(perSeat) * seats.length;
      final fee = double.parse(platformFeePerSeat) * seats.length;
      // Booked the evening before, or an hour ago when that is still ahead.
      final evening = departs.subtract(const Duration(hours: 20));
      final booked = evening.isBefore(now)
          ? evening
          : now.subtract(const Duration(hours: 1));
      final booking = _MockBooking(
        number: -1,
        id: 'b00000$id-7c2d-4000-8000-0000000000$id',
        reference: reference,
        userId: userId,
        trip: mockTrip,
        seatIds: seatIds,
        originStopId: board.id,
        destinationStopId: alight.id,
        fare: fare.toStringAsFixed(2),
        fee: fee.toStringAsFixed(2),
        total: (fare + fee).toStringAsFixed(2),
        solo: (double.parse(solo) * seats.length).toStringAsFixed(2),
        status: status,
        expiresAt: booked.add(seatHold),
        createdAt: rolling == null ? booked : now,
        passengers: [
          for (final (i, seatId) in seatIds.indexed)
            BookingPassengerResponse(
              id: 'a00000$id-7c2d-4000-8000-00000000000$i',
              seatId: seatId,
              fullName: i == 0 ? 'Ama Mensah' : 'Kwabena Mensah',
            ),
        ],
        seeded: true,
        rolling: rolling,
      );
      _bookings[booking.id] = booking;
    }

    DateTime at(int days, int hour, int minute) =>
        today.add(Duration(days: days, hours: hour, minutes: minute));

    // Ahead.
    book(
      from: 'Madina',
      to: 'Circle',
      departs: at(1, 7, 15),
      minutes: 40,
      vehicle: VehicleType.minibus,
      plate: 'GR 1234-24',
      perSeat: '8.00',
      solo: '14.00',
      seats: ['3', '4'],
      status: BookingStatus.confirmed,
      reference: 'TS-8KQ2',
    );
    book(
      from: 'Legon',
      to: 'Osu',
      departs: at(1, 8, 30),
      minutes: 35,
      vehicle: VehicleType.sedan,
      plate: 'GT 5521-23',
      perSeat: '18.00',
      solo: '45.00',
      seats: ['2'],
      status: BookingStatus.awaitingAcceptance,
      reference: 'TS-4HBN',
      rolling: acceptTimeout,
    );
    book(
      from: 'Circle',
      to: 'Tema',
      departs: at(1, 17, 45),
      minutes: 55,
      vehicle: VehicleType.bus,
      plate: 'GN 7781-22',
      perSeat: '9.00',
      solo: '9.00',
      seats: ['6'],
      status: BookingStatus.pending,
      reference: 'TS-Q7RD',
      rolling: seatHold,
    );
    book(
      from: 'Achimota',
      to: 'Lapaz',
      departs: now.subtract(const Duration(minutes: 20)),
      minutes: 25,
      vehicle: VehicleType.minibus,
      plate: 'GW 3390-21',
      perSeat: '5.00',
      solo: '9.00',
      seats: ['7'],
      status: BookingStatus.confirmed,
      reference: 'TS-C2MX',
      trip: TripStatus.inProgress,
    );
    // Behind, or ended.
    book(
      from: 'Osu',
      to: 'Circle',
      departs: at(2, 12, 0),
      minutes: 30,
      vehicle: VehicleType.minibus,
      plate: 'GR 6610-24',
      perSeat: '7.00',
      solo: '12.00',
      seats: ['9'],
      status: BookingStatus.refundPending,
      reference: 'TS-RF9P',
    );
    book(
      from: 'Circle',
      to: 'Tema',
      departs: at(-1, 17, 15),
      minutes: 55,
      vehicle: VehicleType.bus,
      plate: 'GN 7781-22',
      perSeat: '9.00',
      solo: '9.00',
      seats: ['5', '6'],
      status: BookingStatus.completed,
      reference: 'TS-W3TE',
      trip: TripStatus.completed,
    );
    book(
      from: 'Accra Central',
      to: 'Kaneshie',
      departs: at(-2, 7, 45),
      minutes: 20,
      vehicle: VehicleType.minibus,
      plate: 'GE 2207-23',
      perSeat: '4.50',
      solo: '8.00',
      seats: ['1'],
      status: BookingStatus.completed,
      reference: 'TS-KN45',
      trip: TripStatus.completed,
    );
    book(
      from: 'Madina',
      to: 'Circle',
      departs: at(-3, 8, 30),
      minutes: 40,
      vehicle: VehicleType.minibus,
      plate: 'GR 1234-24',
      perSeat: '6.00',
      solo: '14.00',
      seats: ['8'],
      status: BookingStatus.completed,
      reference: 'TS-MD60',
      trip: TripStatus.completed,
    );
    book(
      from: 'Tema',
      to: 'Circle',
      departs: at(-4, 18, 0),
      minutes: 55,
      vehicle: VehicleType.bus,
      plate: 'GN 4402-22',
      perSeat: '9.00',
      solo: '9.00',
      seats: ['10'],
      status: BookingStatus.cancelled,
      reference: 'TS-TC90',
      trip: TripStatus.completed,
    );
    book(
      from: 'Kaneshie',
      to: 'Lapaz',
      departs: at(-5, 9, 10),
      minutes: 25,
      vehicle: VehicleType.minibus,
      plate: 'GE 8815-24',
      perSeat: '5.00',
      solo: '9.00',
      seats: ['2'],
      status: BookingStatus.refunded,
      reference: 'TS-RD50',
      trip: TripStatus.cancelled,
    );
    book(
      from: 'Lapaz',
      to: 'Madina',
      departs: at(-6, 16, 40),
      minutes: 50,
      vehicle: VehicleType.minibus,
      plate: 'GW 1029-22',
      perSeat: '6.50',
      solo: '12.00',
      seats: ['11'],
      status: BookingStatus.expired,
      reference: 'TS-EX65',
      trip: TripStatus.completed,
    );
  }

  String _reference() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final n = ++_counter * 7919;
    return [
      for (var i = 0; i < 4; i++) letters[(n ~/ (i + 1) + i * 5) % 32],
    ].join();
  }

  // ---------------------------------------------------------------------
  // Test controls
  // ---------------------------------------------------------------------

  /// Another rider takes the seat [number] of [tripId] (it must be free).
  void takeSeat(String tripId, String number) {
    final trip = _tripIndex[tripId]!;
    trip.takenByOthers.add(trip.seats.firstWhere((s) => s.number == number).id);
  }

  /// [tripId] stops taking bookings (it started, or was cancelled).
  void closeTrip(String tripId) => _tripIndex[tripId]!.closed = true;

  /// The account with [phone] has not verified its phone or email.
  void markUnverified(String phone) {
    final user = _byPhone(normalizePhoneNumber(phone))!;
    user
      ..phoneVerifiedAt = null
      ..emailVerifiedAt = null;
  }

  /// The booking [bookingId] as the backend holds it now.
  BookingStatus bookingStatus(String bookingId) {
    _expireHolds();
    return _bookings[bookingId]!.status;
  }

  /// The trip the booking [bookingId] is on now (it changes when it moves).
  String bookingTripId(String bookingId) {
    _expireHolds();
    return _bookings[bookingId]!.trip.result.tripId;
  }

  /// The driver accepts the booking [bookingId], as
  /// `POST /driver-trips/{trip_id}/bookings/{booking_id}/accept` does.
  void acceptBooking(String bookingId) {
    _expireHolds();
    final booking = _bookings[bookingId]!;
    assert(booking.status == BookingStatus.awaitingAcceptance);
    _accept(booking, _now().toUtc());
  }

  /// The driver declines the booking [bookingId]: it moves to another
  /// vehicle going the same way, if one has seats ([move]), or ends
  /// `cancelled`.
  void declineBooking(String bookingId, {bool move = true}) {
    _expireHolds();
    final booking = _bookings[bookingId]!;
    assert(booking.status == BookingStatus.awaitingAcceptance);
    if (move) {
      _moveOrEnd(booking, BookingStatus.cancelled, from: _now().toUtc());
    } else {
      _end(booking, BookingStatus.cancelled);
    }
  }

  /// Removes every favourite route of the account with [phone].
  void clearFavouriteRoutes(String phone) =>
      _favourites.remove(_byPhone(normalizePhoneNumber(phone))!.id);

  /// Suspends the account with [phone], as an admin would.
  void suspend(String phone, {String reason = 'Under review'}) =>
      _byPhone(normalizePhoneNumber(phone))!.suspendedReason = reason;

  /// Gives the account with [phone] a driver profile in [status], as
  /// `POST /drivers/me` and an admin review would.
  void setDriverStatus(String phone, ApprovalStatus status) {
    final user = _byPhone(normalizePhoneNumber(phone))!;
    _driverProfiles[user.id] = DriverResponse(
      id: _uuid(),
      userId: user.id,
      licenseNumber: 'GHA-DL-${user.phone.substring(user.phone.length - 7)}',
      licenseExpiry: DateTime.utc(2030),
      status: status,
      createdAt: _now().toUtc(),
    );
  }

  /// Makes every access token expire, as 15 minutes passing would.
  void expireAccessTokens() {
    for (final token in _accessTokens.values) {
      token.expiresAt = _now().subtract(const Duration(seconds: 1));
    }
  }

  /// How many sessions of [phone] are still active.
  int activeSessions(String phone) {
    final user = _byPhone(normalizePhoneNumber(phone))!;
    return _sessions.values
        .where((s) => s.userId == user.id && !s.revoked)
        .length;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  _User? _byPhone(String e164) =>
      _users.where((u) => u.phone == e164).firstOrNull;

  _User? _byEmail(String email) =>
      _users.where((u) => u.email == email).firstOrNull;

  /// `_resolve_user`: a phone number in any form, else an email address.
  _User? _resolve(String identifier) {
    final phone = tryNormalizePhoneNumber(identifier);
    if (phone != null) {
      final user = _byPhone(phone);
      if (user != null) return user;
    }
    return _byEmail(identifier.trim().toLowerCase());
  }

  /// `normalize_otp_target`.
  String _normalizeTarget(String target) {
    if (target.contains('@')) return target.trim().toLowerCase();
    return tryNormalizePhoneNumber(target) ?? target.trim();
  }

  AppFailure? _loginBlocked(_User user) {
    if (user.suspendedReason != null) {
      return _failure(
        403,
        'ACCOUNT_SUSPENDED',
        'This account has been suspended.',
        {'reason': user.suspendedReason},
      );
    }
    final until = user.lockedUntil;
    if (until != null && until.isAfter(_now())) {
      return _failure(
        423,
        'ACCOUNT_LOCKED',
        'This account is temporarily locked due to repeated failed attempts.',
        {'locked_until': until.toIso8601String()},
      );
    }
    return null;
  }

  Err<T> _invalidCredentials<T>() => _error(
    401,
    'INVALID_CREDENTIALS',
    'The provided credentials are incorrect.',
  );

  String _cooldownKey(String target, OtpPurpose purpose) =>
      '${purpose.name}:$target';

  DateTime? _cooldownRunning(String target, OtpPurpose purpose) {
    final until = _cooldowns[_cooldownKey(target, purpose)];
    return until != null && until.isAfter(_now()) ? until : null;
  }

  /// `hold_cooldown`: starts the cooldown, or fails while it runs.
  AppFailure? _holdCooldown(String target, OtpPurpose purpose) {
    if (_cooldownRunning(target, purpose) != null) {
      return _failure(
        429,
        'RATE_LIMIT_EXCEEDED',
        'Please wait before requesting another code.',
        {'cooldown_seconds': otpCooldown.inSeconds},
      );
    }
    _cooldowns[_cooldownKey(target, purpose)] = _now().add(otpCooldown);
    return null;
  }

  /// `request_otp`: a new code keyed on [target], sent to [deliverTo].
  AppFailure? _issue(
    String target,
    OtpChannel channel,
    OtpPurpose purpose, {
    String? deliverTo,
  }) {
    final held = _holdCooldown(target, purpose);
    if (held != null) return held;
    _challenges.add(
      _Challenge(
        target: target,
        purpose: purpose,
        channel: channel,
        expiresAt: _now().add(otpTtl),
      ),
    );
    outbox.add(
      SentCode(
        to: deliverTo ?? target,
        channel: channel,
        purpose: purpose,
        code: otpCode,
      ),
    );
    return null;
  }

  /// `verify_otp` in otp_service.py.
  Result<_Challenge> _verify(String target, OtpPurpose purpose, String code) {
    final challenge = _challenges.reversed
        .where((c) => c.target == target && c.purpose == purpose && !c.used)
        .firstOrNull;
    if (challenge == null) {
      return _error(
        404,
        'OTP_NOT_FOUND',
        'No active OTP challenge was found for this target.',
      );
    }
    if (!challenge.expiresAt.isAfter(_now())) {
      return _error(400, 'OTP_EXPIRED', 'The OTP code has expired.');
    }
    if (challenge.attempts >= otpMaxAttempts) {
      return _error(
        429,
        'OTP_ATTEMPTS_EXCEEDED',
        'Too many incorrect OTP attempts. Request a new code.',
      );
    }
    if (code != otpCode) {
      challenge.attempts++;
      return _error(400, 'OTP_INVALID', 'The OTP code is incorrect.');
    }
    challenge.used = true;
    return Ok(challenge);
  }

  TokenPairResponse _issueTokens(_User user) {
    final session = _Session(id: _uuid(), userId: user.id);
    _sessions[session.id] = session;
    return _tokensForSession(user, session.id);
  }

  TokenPairResponse _tokensForSession(_User user, String sessionId) {
    final access = 'mock.access.${_uuid()}';
    final refresh = 'mock.refresh.${_uuid()}';
    _accessTokens[access] = _AccessToken(
      userId: user.id,
      sessionId: sessionId,
      expiresAt: _now().add(const Duration(seconds: accessTokenTtlSeconds)),
    );
    _refreshTokens[refresh] = _RefreshToken(
      userId: user.id,
      sessionId: sessionId,
      expiresAt: _now().add(refreshTokenTtl),
    );
    return TokenPairResponse(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: accessTokenTtlSeconds,
      sessionId: sessionId,
    );
  }

  /// `resolve_principal`.
  Result<_AccessToken> _authenticate(String? accessToken) {
    if (accessToken == null) {
      return _error(401, 'UNAUTHORIZED', 'Authentication is required.');
    }
    final token = _accessTokens[accessToken];
    if (token == null || !token.expiresAt.isAfter(_now())) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired access token.');
    }
    if (_sessions[token.sessionId]?.revoked ?? true) {
      return _error(401, 'UNAUTHORIZED', 'This session has been revoked.');
    }
    final user = _users.firstWhere((u) => u.id == token.userId);
    if (user.suspendedReason != null) {
      return _error(
        403,
        'ACCOUNT_SUSPENDED',
        'This account has been suspended.',
        {'reason': user.suspendedReason},
      );
    }
    return Ok(token);
  }

  void _revokeSession(String sessionId) {
    _sessions[sessionId]?.revoked = true;
    for (final token in _refreshTokens.values) {
      if (token.sessionId == sessionId) token.revoked = true;
    }
  }

  void _revokeAllSessions(String userId) {
    for (final session in _sessions.values) {
      if (session.userId == userId) _revokeSession(session.id);
    }
  }

  List<String> _passwordViolations(String password) => [
    if (password.length < 8) 'Password must be at least 8 characters.',
    if (!password.contains(RegExp('[A-Z]')))
      'Password must contain at least one uppercase letter.',
    if (!password.contains(RegExp('[a-z]')))
      'Password must contain at least one lowercase letter.',
    if (!password.contains(RegExp('[0-9]')))
      'Password must contain at least one digit.',
  ];

  List<Map<String, Object?>>? _codeFieldErrors(String code) {
    if (code.length < 4) {
      return [_fieldError('code', 'String should have at least 4 characters')];
    }
    if (code.length > 10) {
      return [_fieldError('code', 'String should have at most 10 characters')];
    }
    return null;
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static String _roleSlug(RegistrableRole role) => switch (role) {
    RegistrableRole.passenger => 'passenger',
    RegistrableRole.driver => 'driver',
    RegistrableRole.fleetOwner => 'fleet_owner',
  };

  Map<String, Object?> _fieldError(String field, String message) => {
    'type': 'value_error',
    'loc': ['body', field],
    'msg': message,
  };

  Err<T> _validationError<T>(List<Map<String, Object?>> errors) => _error(
    422,
    'VALIDATION_ERROR',
    'The submitted data is invalid.',
    {'errors': errors},
  );

  /// auth_service.py `_check_signup_location`: a passenger shares where
  /// they are, and it must be in [passengerSignupCountries]. Only checked.
  Err<RegisterResponse>? _checkSignupLocation(RegisterRequest request) {
    final countries = passengerSignupCountries;
    if (request.role != RegistrableRole.passenger || countries.isEmpty) {
      return null;
    }
    final names = countryNamesFor(countries);
    final details = {'countries': countries.toList()..sort()};
    final latitude = request.latitude;
    final longitude = request.longitude;
    if (latitude == null || longitude == null) {
      return _error(
        422,
        'LOCATION_REQUIRED',
        'Turn on your location to sign up: TroSky is available in $names '
            'for now.',
        details,
      );
    }
    if (countryAt(latitude, longitude, countries) == null) {
      return _error(
        422,
        'LOCATION_NOT_SERVED',
        'TroSky is only available in $names for now.',
        details,
      );
    }
    return null;
  }

  Err<T> _error<T>(
    int status,
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) => Err(_failure(status, code, message, details));

  /// The backend's error envelope, mapped exactly as a live response is.
  AppFailure _failure(
    int status,
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) => AppFailure.fromResponse(
    statusCode: status,
    body: {
      'error': {
        'code': code,
        'message': message,
        'details': details,
        'request_id': 'mock-${++_counter}',
      },
    },
  );

  String _uuid() {
    final n = (++_counter).toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$n';
  }
}

const double _metersPerDegree = 111320;

/// Great-circle distance in metres between two points.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371008.8;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a));
}

/// A stop of the mock backend.
class MockStop {
  const MockStop(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;

  /// A stable id made from the name, so favourites can point at the stop.
  String get id {
    final hex = name.codeUnits
        .fold<int>(17, (hash, unit) => (hash * 31 + unit) & 0xffffffff)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$hex-5709-4000-8000-000000000000';
  }
}

/// The backend's name for a [BookingStatus] ("payment_pending").
String bookingStatusValue(BookingStatus status) => status.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

class _MockSeat {
  const _MockSeat(this.id, this.number, this.row, this.column, this.type);

  final String id;
  final String number;
  final int row;
  final int column;
  final SeatType type;
}

/// A trip a search found, with its vehicle's seat map.
class _MockTrip {
  _MockTrip(this.result, this.board, this.alight, this.lastRider)
    : seats = _layout(result),
      status = result.status {
    final available = result.availableSeats;
    final taken = available <= 0
        ? seats.map((s) => s.number)
        : minibus
        ? const ['2', '6', '9', '11', '12']
        : seats.map((s) => s.number).take(seats.length - available);
    takenByOthers.addAll([
      for (final seat in seats)
        if (taken.contains(seat.number)) seat.id,
    ]);
  }

  final TripSearchResultResponse result;
  final MockStop board;
  final MockStop alight;
  final List<_MockSeat> seats;
  final Set<String> takenByOthers = {};
  DateTime lastRider;
  bool closed = false;

  /// Search only finds scheduled and boarding trips; the booking history
  /// also has trips under way and finished.
  TripStatus status;

  bool get minibus => result.vehicleType == VehicleType.minibus;

  /// The per-seat shared fare as [booked] seats fill (P7: from ₵14.00 down
  /// to ₵6.00 as 44 / booked), the solo fare and the floor.
  ({String shared, String solo, String floor}) fares(int booked) {
    if (minibus) {
      final shared = booked <= 5 ? 14.0 : math.max(6, 44 / booked).toDouble();
      return (shared: shared.toStringAsFixed(2), solo: '38.00', floor: '6.00');
    }
    final fare = result.fare;
    return (
      shared: fare?.current ?? result.fareAmount,
      solo: fare?.solo ?? result.fareAmount,
      floor: fare?.minimum ?? result.fareAmount,
    );
  }

  static List<_MockSeat> _layout(TripSearchResultResponse trip) {
    String id(String number) =>
        '${trip.tripId.substring(0, 8)}-5ea7-4000-'
        '8000-${number.padLeft(12, '0')}';
    _MockSeat seat(String number, int row, int column) =>
        _MockSeat(id(number), number, row, column, SeatType.standard);
    return switch (trip.vehicleType) {
      // P7: three rows of 2 + 2, then seats 13 and 14 at the back.
      VehicleType.minibus => [
        for (var i = 0; i < 12; i++) seat('${i + 1}', i ~/ 4 + 1, i % 4 + 1),
        seat('13', 4, 2),
        seat('14', 4, 3),
      ],
      // A saloon car: two rows of two.
      VehicleType.sedan => [
        for (var i = 0; i < 4; i++) seat('${i + 1}', i ~/ 2 + 1, i % 2 + 1),
      ],
      // A 2 + 2 bus coded with an empty aisle column (3) and a full
      // 5-seat back bench.
      _ => [
        for (var row = 1; row <= 4; row++)
          for (final (i, column) in const [1, 2, 4, 5].indexed)
            seat('${(row - 1) * 4 + i + 1}', row, column),
        for (var column = 1; column <= 5; column++)
          seat('${16 + column}', 5, column),
      ],
    };
  }
}

/// How the mock's drivers answer booking requests ([MockBackend.driverScript]).
enum MockDriverScript {
  /// The driver accepts.
  accept,

  /// The first driver doesn't answer in time, so the booking moves to
  /// another vehicle, whose driver accepts.
  moveThenAccept,

  /// The driver declines and no other vehicle going that way has seats:
  /// the booking ends `cancelled`.
  decline,

  /// Takes turns, booking by booking: [accept], [moveThenAccept],
  /// [decline], then again. One build shows every Payment state (the demo
  /// APK).
  rotate;

  /// The script called [name] (`MOCK_DRIVER`), or null for none.
  static MockDriverScript? named(String name) =>
      values.where((s) => s.name == name).firstOrNull;

  /// How the drivers answer the [number]th booking (from 0).
  MockDriverScript forBooking(int number) => this == rotate
      ? const [accept, moveThenAccept, decline][number % 3]
      : this;
}

class _MockBooking {
  _MockBooking({
    required this.number,
    required this.id,
    required this.reference,
    required this.userId,
    required this.trip,
    required this.seatIds,
    required this.originStopId,
    required this.destinationStopId,
    required this.fare,
    required this.fee,
    required this.total,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.passengers,
    this.solo,
    this.seeded = false,
    this.rolling,
  }) : requestedAt = createdAt,
       tried = {trip.result.tripId};

  /// Which booking this is, from 0 ([MockDriverScript.forBooking]).
  final int number;
  final String id;
  final String reference;
  final String userId;
  _MockTrip trip;
  List<String> seatIds;
  final String originStopId;
  final String destinationStopId;
  final String fare;
  final String fee;
  final String total;
  BookingStatus status;

  /// The driver's deadline while [BookingStatus.awaitingAcceptance], then
  /// the deadline to pay.
  DateTime expiresAt;
  final DateTime createdAt;
  List<BookingPassengerResponse> passengers;

  /// When the current trip's driver was asked.
  DateTime requestedAt;

  /// Trips this booking was put to, and how often it moved.
  final Set<String> tried;
  int moves = 0;

  /// What the seats would have cost unshared (the saving on the Trip
  /// History card); null: [fare].
  final String? solo;

  /// Part of the passenger's history ([MockBackend.bookingHistory]): the
  /// drivers' script leaves it alone.
  final bool seeded;

  /// For a seeded booking still waiting or pending: it never lapses, and
  /// its deadline starts again every [rolling], so the demo always has one.
  final Duration? rolling;

  /// Cancelled once its trip had started: waits for an admin, and the
  /// booking stays as it was (no passenger endpoint shows the request).
  bool cancellationRequested = false;

  /// The deadline shown at [now]: [expiresAt], or the current turn of a
  /// [rolling] one.
  DateTime deadlineAt(DateTime now) {
    final window = rolling;
    if (window == null) return expiresAt;
    final turns =
        now.difference(createdAt).inMicroseconds ~/ window.inMicroseconds;
    return createdAt.add(window * (turns + 1));
  }

  BookingResponse toResponse(DateTime now) => BookingResponse(
    id: id,
    bookingReference: reference,
    tripId: trip.result.tripId,
    status: status,
    passengerCount: seatIds.length,
    originStopId: originStopId,
    destinationStopId: destinationStopId,
    fareAmount: fare,
    platformFee: fee,
    totalAmount: total,
    expiresAt:
        status == BookingStatus.awaitingAcceptance ||
            status == BookingStatus.pending
        ? deadlineAt(now)
        : null,
    createdAt: createdAt,
    passengers: passengers,
    trip: BookingTripSummaryResponse(
      scheduledDepartureAt: trip.result.scheduledDepartureAt,
      routeName: trip.result.routeName,
      originStopName: trip.board.name,
      destinationStopName: trip.alight.name,
      status: trip.status,
      vehicleRegistrationNumber: trip.result.vehicleRegistrationNumber,
    ),
    boardingStopName: MockBackend.stops.values
        .firstWhere((s) => s.id == originStopId, orElse: () => trip.board)
        .name,
    alightingStopName: MockBackend.stops.values
        .firstWhere((s) => s.id == destinationStopId, orElse: () => trip.alight)
        .name,
  );
}

/// A code the mock "sent", for tests and the debug screen.
class SentCode {
  const SentCode({
    required this.to,
    required this.channel,
    required this.purpose,
    required this.code,
  });

  final String to;
  final OtpChannel channel;
  final OtpPurpose purpose;
  final String code;
}

class _User {
  _User({
    required this.id,
    required this.phone,
    required this.email,
    required this.password,
    required this.fullName,
    required this.roles,
    required this.createdAt,
    this.preferredLanguage = 'en',
  });

  final String id;
  final String phone;
  final String? email;
  final String password;
  final String fullName;
  final List<String> roles;
  final DateTime createdAt;
  final String preferredLanguage;
  DateTime? phoneVerifiedAt;
  DateTime? emailVerifiedAt;
  String? suspendedReason;
  DateTime? lockedUntil;
  int failedLogins = 0;

  bool get isVerified => phoneVerifiedAt != null || emailVerifiedAt != null;

  UserResponse toResponse() => UserResponse(
    id: id,
    phoneNumber: phone,
    email: email,
    isActive: true,
    phoneVerified: phoneVerifiedAt != null,
    emailVerified: emailVerifiedAt != null,
    roles: roles,
    createdAt: createdAt,
    profile: UserProfileResponse(
      fullName: fullName,
      preferredLanguage: preferredLanguage,
      ghanaCardVerified: false,
    ),
  );
}

class _Challenge {
  _Challenge({
    required this.target,
    required this.purpose,
    required this.channel,
    required this.expiresAt,
  });

  final String target;
  final OtpPurpose purpose;
  final OtpChannel channel;
  final DateTime expiresAt;
  int attempts = 0;
  bool used = false;
}

class _Session {
  _Session({required this.id, required this.userId});

  final String id;
  final String userId;
  bool revoked = false;
}

class _RefreshToken {
  _RefreshToken({
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  });

  final String userId;
  final String sessionId;
  final DateTime expiresAt;
  bool revoked = false;
}

class _AccessToken {
  _AccessToken({
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  });

  final String userId;
  final String sessionId;
  DateTime expiresAt;
}
