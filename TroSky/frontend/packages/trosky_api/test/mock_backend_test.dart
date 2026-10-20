import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// The mock must answer like backend/app/services/auth_service.py.
void main() {
  late DateTime now;
  late MockBackend backend;

  setUp(() {
    now = DateTime.utc(2026, 10, 1, 9);
    backend = MockBackend(clock: () => now);
  });

  /// A new passenger signing up in Accra (the phone's position).
  RegisterRequest newPassenger({
    String phone = '0551234567',
    String? email = 'yaw.asante@gmail.com',
    String password = 'Accra2026',
    double? latitude = 5.6037,
    double? longitude = -0.1870,
  }) => RegisterRequest(
    phoneNumber: phone,
    email: email,
    password: password,
    fullName: 'Yaw Asante',
    latitude: latitude,
    longitude: longitude,
  );

  String? code<T>(Result<T> result) => result.failureOrNull?.code;

  String signIn(String phone) => backend
      .login(
        LoginRequest(identifier: phone, password: MockBackend.seedPassword),
      )
      .valueOrNull!
      .accessToken;

  group('Home (P5)', () {
    test('nearby stops: within 1 km, nearest first', () {
      final circle = MockBackend.stops['Circle']!;
      final stops = backend
          .nearbyStops(
            latitude: circle.latitude + 0.001,
            longitude: circle.longitude,
          )
          .valueOrNull!;
      expect(stops.map((s) => s.name), ['Circle']);
      expect(stops.single.distanceM, closeTo(111, 1));
      expect(stops.single.city, 'Accra');
    });

    test('nearby stops: nothing near is an empty list, not an error', () {
      // Kumasi.
      final stops = backend.nearbyStops(latitude: 6.6885, longitude: -1.6244);
      expect(stops.valueOrNull, isEmpty);
    });

    test('favourite routes: the seeded passenger has the design four', () {
      final token = signIn('0241234567');
      final routes = backend.listFavouriteRoutes(token).valueOrNull!;
      expect(
        routes.map((r) => '${r.originStopName} → ${r.destinationStopName}'),
        [
          'Madina → Circle',
          'Legon → Osu',
          'Achimota → Tema',
          'Kaneshie → Lapaz',
        ],
      );
      expect(routes.first.originStopId, MockBackend.stops['Madina']!.id);

      backend.clearFavouriteRoutes('0241234567');
      expect(backend.listFavouriteRoutes(token).valueOrNull, isEmpty);
    });

    test('favourite routes and vehicles need a session', () {
      expect(code(backend.listFavouriteRoutes(null)), 'UNAUTHORIZED');
      expect(
        code(
          backend.nearbyVehicles(
            null,
            latitude: 5.6,
            longitude: -0.19,
            radiusM: 4000,
          ),
        ),
        'UNAUTHORIZED',
      );
    });

    test('vehicles: three around the point, where the design draws them', () {
      final token = signIn('0241234567');
      final vehicles = backend
          .nearbyVehicles(
            token,
            latitude: 5.6037,
            longitude: -0.1870,
            radiusM: 4000,
          )
          .valueOrNull!;
      expect(vehicles.map((v) => v.availableSeats), [2, 8, 5]);
      expect(
        vehicles.map((v) => v.distanceM),
        everyElement(lessThanOrEqualTo(4000)),
      );
      // The 5-seat one is up and to the left of the point.
      final five = vehicles.firstWhere((v) => v.availableSeats == 5);
      expect(five.latitude, greaterThan(5.6037));
      expect(five.longitude, lessThan(-0.1870));

      expect(
        backend
            .nearbyVehicles(
              token,
              latitude: 5.6037,
              longitude: -0.1870,
              radiusM: 2000,
            )
            .valueOrNull!
            .map((v) => v.availableSeats),
        [2],
      );
      backend.vehiclesOnTheRoad = false;
      expect(
        backend
            .nearbyVehicles(
              token,
              latitude: 5.6037,
              longitude: -0.1870,
              radiusM: 4000,
            )
            .valueOrNull,
        isEmpty,
      );
    });
  });

  group('Search (P-02, P-03)', () {
    String id(String name) => MockBackend.stops[name]!.id;

    TripSearchQuery fromNow({
      String? origin,
      double? lat,
      double? lng,
      String destination = 'Circle',
      int offset = 0,
      int limit = 20,
      SearchSort sort = SearchSort.departure,
      VehicleType? vehicleType,
    }) => TripSearchQuery(
      originStopId: origin == null ? null : id(origin),
      destinationStopId: id(destination),
      pickupLatitude: lat,
      pickupLongitude: lng,
      travelDate: now,
      departureAfter: Duration(hours: now.hour, minutes: now.minute),
      sort: sort,
      vehicleType: vehicleType,
      offset: offset,
      limit: limit,
    );

    test('stop search: 2 characters or more, by name', () {
      expect(code(backend.searchStops('m')), 'VALIDATION_ERROR');
      expect(backend.searchStops('ma').valueOrNull!.map((s) => s.name), [
        'Madina',
        'Tema',
      ]);
      expect(backend.searchStops('A').failureOrNull?.statusCode, 422);
      expect(backend.searchStops('ac').valueOrNull!.map((s) => s.name), [
        'Accra Central',
        'Achimota',
      ]);
    });

    test('from now: the three P6 vehicles on the way, then every 15 minutes, '
        'the two that passed last', () {
      final page = backend.searchTrips(fromNow(origin: 'Madina')).valueOrNull!;
      final first = page.items.take(3).toList();
      expect(first.map((t) => t.vehicleRegistrationNumber), [
        'GR-4821',
        'GR-2204',
        'GR-7743',
      ]);
      expect(first.map((t) => t.hasPassedPickup), everyElement(isFalse));
      expect(first.map((t) => t.vehicleEtaToPickupMinutes), [3, 7, 12]);
      final best = first.first;
      expect(best.scheduledDepartureAt, DateTime.utc(2026, 10, 1, 9, 3));
      expect(best.scheduledArrivalAt, DateTime.utc(2026, 10, 1, 9, 53));
      expect(
        (best.fare?.current, best.fare?.solo, best.fare?.minimum),
        ('14.00', '38.00', '6.00'),
      );
      expect((best.fare?.platformFee, best.fare?.total), ('0.50', '14.50'));
      expect(best.rideMinutes, 50);
      expect(best.pickupSource, PickupSource.manual);
      expect(best.pickupStopName, 'Madina');
      // 09:30 onwards, every 15 minutes to 22:00.
      expect(
        page.items[3].scheduledDepartureAt,
        DateTime.utc(2026, 10, 1, 9, 30),
      );
      expect(page.items[3].vehicleEtaToPickupMinutes, isNull);
      expect(page.total, 5 + 51);
      expect(page.items, hasLength(20));
      expect(page.hasMore, isTrue);
      // As the backend: vehicles that passed the pickup come last.
      final all = backend
          .searchTrips(fromNow(origin: 'Madina', limit: 100))
          .valueOrNull!
          .items;
      expect(all.reversed.take(2).map((t) => t.vehicleRegistrationNumber), [
        'GR-5531',
        'GR-1190',
      ]);
      expect(all.where((t) => t.hasPassedPickup), hasLength(2));
    });

    test('sort: cheapest and fastest, still with passed vehicles last', () {
      final cheapest = backend
          .searchTrips(
            fromNow(origin: 'Madina', limit: 100, sort: SearchSort.cheapest),
          )
          .valueOrNull!
          .items;
      final prices = [
        for (final t in cheapest.where((t) => !t.hasPassedPickup))
          double.parse(t.fare!.current),
      ];
      expect(prices, [...prices]..sort());
      expect(cheapest.last.hasPassedPickup, isTrue);
      final fastest = backend
          .searchTrips(
            fromNow(origin: 'Madina', limit: 100, sort: SearchSort.fastest),
          )
          .valueOrNull!
          .items;
      expect(fastest.first.vehicleRegistrationNumber, 'GR-2204');
      expect(fastest.first.rideMinutes, 48);
    });

    test('vehicle_type: only that kind', () {
      final minibuses = backend
          .searchTrips(
            fromNow(
              origin: 'Madina',
              limit: 100,
              vehicleType: VehicleType.minibus,
            ),
          )
          .valueOrNull!;
      expect(
        minibuses.items.map((t) => t.vehicleType),
        everyElement(VehicleType.minibus),
      );
      expect(minibuses.total, lessThan(56));
    });

    test('pages follow on without repeats', () {
      final a = backend.searchTrips(fromNow(origin: 'Madina')).valueOrNull!;
      final b = backend
          .searchTrips(fromNow(origin: 'Madina', offset: 20))
          .valueOrNull!;
      final c = backend
          .searchTrips(fromNow(origin: 'Madina', offset: 40))
          .valueOrNull!;
      final ids = [...a.items, ...b.items, ...c.items].map((t) => t.tripId);
      expect(ids.toSet(), hasLength(56));
      expect(c.hasMore, isFalse);
    });

    test('a scheduled search: that day from that time, no G21 fields', () {
      final page = backend
          .searchTrips(
            TripSearchQuery(
              originStopId: id('Madina'),
              destinationStopId: id('Circle'),
              travelDate: DateTime.utc(2026, 10, 3),
              departureAfter: const Duration(hours: 17),
            ),
          )
          .valueOrNull!;
      expect(
        page.items.first.scheduledDepartureAt,
        DateTime.utc(2026, 10, 3, 17),
      );
      expect(page.items.map((t) => t.hasPassedPickup), everyElement(isFalse));
      expect(
        page.items.map((t) => t.vehicleEtaToPickupMinutes),
        everyElement(isNull),
      );
      expect(page.total, 21);
    });

    test('GPS pickup: the nearest stop within walking distance', () {
      final madina = MockBackend.stops['Madina']!;
      final page = backend
          .searchTrips(
            fromNow(lat: madina.latitude + 0.002, lng: madina.longitude),
          )
          .valueOrNull!;
      expect(page.items.first.pickupSource, PickupSource.gps);
      expect(page.items.first.pickupStopName, 'Madina');
      expect(page.items.first.pickupDistanceM, closeTo(222, 2));
    });

    test('GPS pickup with no stop near: NO_PICKUP_NEARBY', () {
      final result = backend.searchTrips(fromNow(lat: 6.6885, lng: -1.6244));
      expect(code(result), 'NO_PICKUP_NEARBY');
      expect(result.failureOrNull?.statusCode, 422);
    });

    test('same stop twice, or one coordinate only', () {
      expect(
        backend.searchTrips(fromNow(origin: 'Circle')).valueOrNull!.total,
        0,
      );
      expect(code(backend.searchTrips(fromNow(lat: 5.6))), 'VALIDATION_ERROR');
    });

    test('saving a favourite route: created, then exists, then the limit', () {
      final token = signIn('0241234567');
      FavouriteRouteCreateRequest route(String from, String to) =>
          FavouriteRouteCreateRequest(
            originStopId: id(from),
            destinationStopId: id(to),
          );
      final saved = backend.addFavouriteRoute(token, route('Osu', 'Tema'));
      expect(saved.valueOrNull?.originStopName, 'Osu');
      expect(
        code(backend.addFavouriteRoute(token, route('Osu', 'Tema'))),
        'FAVOURITE_ROUTE_EXISTS',
      );
      expect(
        backend
            .listFavouriteRoutes(token)
            .valueOrNull!
            .last
            .destinationStopName,
        'Tema',
      );
      // 5 saved; 15 more reach 20.
      final names = MockBackend.stops.keys.toList();
      var added = 0;
      for (final from in names) {
        for (final to in names) {
          if (added == 15 || from == to) continue;
          if (backend.addFavouriteRoute(token, route(from, to)).isOk) added++;
        }
      }
      expect(
        code(backend.addFavouriteRoute(token, route('Lapaz', 'Accra Central'))),
        'FAVOURITE_ROUTES_LIMIT',
      );
    });
  });

  group('Seats and bookings (P-05)', () {
    late String token;
    late TripSearchResultResponse minibus;

    setUp(() {
      token = signIn('0241234567');
      final page = backend
          .searchTrips(
            TripSearchQuery(
              originStopId: MockBackend.stops['Madina']!.id,
              destinationStopId: MockBackend.stops['Circle']!.id,
              travelDate: now,
              departureAfter: Duration(hours: now.hour, minutes: now.minute),
            ),
          )
          .valueOrNull!;
      minibus = page.items.firstWhere(
        (t) => t.vehicleRegistrationNumber == 'GR-4821',
      );
    });

    TripSeatsResponse seats() => backend.tripSeats(minibus.tripId).valueOrNull!;
    String seatId(String number) =>
        seats().seats.firstWhere((s) => s.seatNumber == number).id;
    BookingCreateRequest request(List<String> numbers) => BookingCreateRequest(
      tripId: minibus.tripId,
      passengers: [
        for (final (i, n) in numbers.indexed)
          PassengerInput(seatId: seatId(n), fullName: 'Ama guest $i'),
      ],
    );

    test('the P7 map: 14 seats, 2 6 9 11 12 taken, a back bench', () {
      backend.simulateRiders = false;
      final map = seats();
      expect(map.totalSeats, 14);
      expect(map.seats.where((s) => !s.isAvailable).map((s) => s.seatNumber), [
        '2',
        '6',
        '9',
        '11',
        '12',
      ]);
      final bench = map.seats.where((s) => s.rowNumber == 4);
      expect(bench.map((s) => (s.seatNumber, s.columnNumber)), [
        ('13', 2),
        ('14', 3),
      ]);
      final quote = backend.fareQuote(minibus.tripId).valueOrNull!;
      expect(
        (quote.current, quote.solo, quote.minimum),
        ('14.00', '38.00', '6.00'),
      );
    });

    test('the fare quote: per seat, the fee per seat, the stops', () {
      backend.simulateRiders = false;
      final quote = backend
          .fareQuote(
            minibus.tripId,
            originStopId: minibus.originStopId,
            destinationStopId: minibus.destinationStopId,
            seats: 2,
          )
          .valueOrNull!;
      expect(
        (quote.current, quote.platformFee, quote.total, quote.seats),
        ('14.00', '1.00', '29.00', 2),
      );
      expect(quote.ridersCount, 5);
      expect(
        backend
            .fareQuote(
              minibus.tripId,
              originStopId: MockBackend.stops['Osu']!.id,
            )
            .failureOrNull
            ?.code,
        'STOP_NOT_ON_ROUTE',
      );
      expect(backend.fareQuote('nope').failureOrNull?.statusCode, 404);
    });

    test('riders join every 10 s and the fare drops to the floor', () {
      expect(seats().availableSeats, 9);
      now = now.add(const Duration(seconds: 11));
      final after = seats();
      expect(after.availableSeats, 8);
      expect(backend.fareQuote(minibus.tripId).valueOrNull!.current, '7.33');
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 11));
        seats();
      }
      expect(seats().availableSeats, 2);
      expect(backend.fareQuote(minibus.tripId).valueOrNull!.current, '6.00');
    });

    test('a hold: pending, 10 minutes, the seats taken, the fare and fee', () {
      backend.simulateRiders = false;
      final booking = backend
          .createBooking(token, request(['4', '7']))
          .valueOrNull!;
      expect(booking.status, BookingStatus.pending);
      expect(booking.bookingReference, startsWith('TS-'));
      expect(booking.expiresAt, now.toUtc().add(const Duration(minutes: 10)));
      expect(
        (booking.fareAmount, booking.platformFee, booking.totalAmount),
        ('28.00', '1.00', '29.00'),
      );
      expect(booking.trip?.vehicleRegistrationNumber, 'GR-4821');
      expect(booking.boardingStopName, 'Madina');
      final map = seats();
      expect(
        map.seats
            .where((s) => ['4', '7'].contains(s.seatNumber))
            .map((s) => s.isAvailable),
        [false, false],
      );

      // Someone else on the same seat.
      expect(
        code(backend.createBooking(token, request(['7']))),
        'SEAT_NOT_AVAILABLE',
      );
    });

    test('the hold lapses after 10 minutes and the seats come back', () {
      backend.simulateRiders = false;
      final booking = backend.createBooking(token, request(['4'])).valueOrNull!;
      now = now.add(const Duration(minutes: 10, seconds: 1));
      expect(backend.bookingStatus(booking.id), BookingStatus.expired);
      expect(
        seats().seats.firstWhere((s) => s.seatNumber == '4').isAvailable,
        isTrue,
      );
    });

    test('cancel releases the seats; cancelling again is refused', () {
      backend.simulateRiders = false;
      final booking = backend.createBooking(token, request(['4'])).valueOrNull!;
      final cancelled = backend.cancelBooking(token, booking.id).valueOrNull!;
      expect(cancelled.status, BookingStatus.cancelled);
      expect(cancelled.expiresAt, isNull);
      expect(
        seats().seats.firstWhere((s) => s.seatNumber == '4').isAvailable,
        isTrue,
      );
      expect(
        code(backend.cancelBooking(token, booking.id)),
        'INVALID_STATE_TRANSITION',
      );
    });

    test('the held booking is found by status', () {
      backend.simulateRiders = false;
      final booking = backend.createBooking(token, request(['4'])).valueOrNull!;
      final held = backend
          .listBookings(
            token,
            statuses: [BookingStatus.pending, BookingStatus.paymentPending],
            upcoming: true,
          )
          .valueOrNull!;
      expect(held.items.single.id, booking.id);
    });

    test(
      'refusals: unverified, closed trip, 11 seats, the same seat twice',
      () {
        backend.simulateRiders = false;
        final all = [for (final s in seats().seats) s.seatNumber];
        expect(
          code(backend.createBooking(token, request(all.take(11).toList()))),
          'VALIDATION_ERROR',
        );
        expect(
          code(backend.createBooking(token, request(['4', '4']))),
          'VALIDATION_ERROR',
        );
        backend.closeTrip(minibus.tripId);
        expect(
          code(backend.createBooking(token, request(['4']))),
          'TRIP_NOT_BOOKABLE',
        );
        backend.markUnverified('0241234567');
        expect(
          code(backend.createBooking(token, request(['5']))),
          'ACCOUNT_NOT_VERIFIED',
        );
      },
    );
  });

  group('register', () {
    test('a new phone gets a code by SMS, sent to the E.164 number', () {
      final result = backend.register(newPassenger());

      expect(result.valueOrNull?.otpSentTo, '+233551234567');
      expect(result.valueOrNull?.phoneNumber, '+233551234567');
      expect(backend.outbox.first.to, '+233551234567');
      expect(backend.outbox.first.purpose, OtpPurpose.registration);
      // Plus the best-effort email verification code.
      expect(backend.outbox.last.purpose, OtpPurpose.emailVerification);
    });

    test('with codes by email, the code and otp_sent_to are the email', () {
      backend = MockBackend(clock: () => now, codesByEmail: true);
      final result = backend.register(newPassenger());
      expect(result.valueOrNull?.otpSentTo, 'yaw.asante@gmail.com');
    });

    test('existing phone and email are refused', () {
      expect(
        code(backend.register(newPassenger(phone: '0241234567'))),
        'PHONE_ALREADY_REGISTERED',
      );
      expect(
        code(backend.register(newPassenger(email: 'ama.mensah@gmail.com'))),
        'EMAIL_ALREADY_REGISTERED',
      );
    });

    test('email is required and must be Gmail', () {
      final missing = backend.register(newPassenger(email: null));
      expect(code(missing), 'EMAIL_REQUIRED');
      expect(missing.failureOrNull?.statusCode, 422);

      final wrongDomain = backend.register(
        newPassenger(email: 'yaw@yahoo.com'),
      );
      expect(code(wrongDomain), 'EMAIL_DOMAIN_NOT_ALLOWED');
    });

    test('a weak password is a 409 policy violation', () {
      final result = backend.register(newPassenger(password: 'accra2026'));
      expect(code(result), 'PASSWORD_POLICY_VIOLATION');
      expect(result.failureOrNull?.statusCode, 409);
      expect(
        (result.failureOrNull! as ValidationFailure).fieldErrors['password'],
        ['Password must contain at least one uppercase letter.'],
      );
    });

    test('an invalid phone is a 422 on phone_number', () {
      final result = backend.register(newPassenger(phone: '0251234567'));
      expect(code(result), 'VALIDATION_ERROR');
      expect((result.failureOrNull! as ValidationFailure).fieldErrors.keys, [
        'phone_number',
      ]);
    });
  });

  group('sign-up location (PASSENGER_SIGNUP_COUNTRIES=GH)', () {
    test('a passenger without a position is LOCATION_REQUIRED', () {
      final result = backend.register(
        newPassenger(latitude: null, longitude: null),
      );
      expect(code(result), 'LOCATION_REQUIRED');
      expect(result.failureOrNull?.statusCode, 422);
      expect(result.failureOrNull?.details, {
        'countries': ['GH'],
      });
      expect(backend.outbox, isEmpty);
    });

    test('a position outside Ghana is LOCATION_NOT_SERVED', () {
      // Lagos, Nigeria.
      final result = backend.register(
        newPassenger(latitude: 6.5244, longitude: 3.3792),
      );
      expect(code(result), 'LOCATION_NOT_SERVED');
      expect(result.failureOrNull?.statusCode, 422);
      expect(
        result.failureOrNull?.message,
        'TroSky is only available in Ghana for now.',
      );
    });

    test('border towns pass, and so does Lomé, inside the margin', () {
      const places = {
        'Aflao': (6.1167, 1.1833),
        'Paga': (10.9850, -1.1120),
        'Elubo': (5.2833, -2.7667),
        'Lomé': (6.1319, 1.2228),
      };
      var n = 0;
      for (final MapEntry(key: name, value: (lat, lng)) in places.entries) {
        final result = backend.register(
          newPassenger(
            phone: '055123450${n++}',
            email: 'yaw.$n@gmail.com',
            latitude: lat,
            longitude: lng,
          ),
        );
        expect(result.isOk, isTrue, reason: name);
      }
    });

    test('drivers sign up without a position', () {
      final result = backend.register(
        newPassenger(
          latitude: null,
          longitude: null,
        ).copyWith(role: RegistrableRole.driver),
      );
      expect(result.isOk, isTrue);
    });

    test('an empty country list switches the check off', () {
      backend = MockBackend(clock: () => now, passengerSignupCountries: {});
      final result = backend.register(
        newPassenger(latitude: null, longitude: null),
      );
      expect(result.isOk, isTrue);
    });
  });

  group('sign-up flow', () {
    test('register → verify → login', () {
      backend.register(newPassenger());

      final beforeVerify = backend.login(
        const LoginRequest(identifier: '0551234567', password: 'Accra2026'),
      );
      expect(code(beforeVerify), 'ACCOUNT_NOT_VERIFIED');
      expect(beforeVerify.failureOrNull?.details, {
        'target': '+233551234567',
        'purpose': 'registration',
      });

      final verified = backend.verifyOtp(
        const VerifyOtpRequest(
          target: '+233551234567',
          purpose: OtpPurpose.registration,
          code: MockBackend.otpCode,
        ),
      );
      expect(verified.isOk, isTrue);

      final login = backend.login(
        const LoginRequest(identifier: '0551234567', password: 'Accra2026'),
      );
      expect(login.valueOrNull?.expiresIn, 900);
    });
  });

  group('OTP', () {
    test('resend for a phone with no account succeeds and sends nothing', () {
      final result = backend.resendOtp(
        const ResendOtpRequest(target: '0551234567', purpose: OtpPurpose.login),
      );
      expect(
        result.valueOrNull?.message,
        'A new verification code has been sent.',
      );
      expect(backend.outbox, isEmpty);
    });

    test('a second resend within 60 s is rate limited, then allowed', () {
      const request = ResendOtpRequest(
        target: '0241234567',
        purpose: OtpPurpose.login,
      );
      expect(backend.resendOtp(request).isOk, isTrue);

      final again = backend.resendOtp(request);
      expect(code(again), 'RATE_LIMIT_EXCEEDED');
      expect(
        (again.failureOrNull! as RateLimitedFailure).retryAfter,
        const Duration(seconds: 60),
      );

      now = now.add(const Duration(seconds: 61));
      expect(backend.resendOtp(request).isOk, isTrue);
    });

    test('otp-login with an unknown phone is NOT_FOUND, whatever the code', () {
      final result = backend.otpLogin(
        const OtpLoginRequest(target: '0551234567', code: '000000'),
      );
      expect(code(result), 'NOT_FOUND');
      expect(result.failureOrNull?.statusCode, 404);
    });

    test('otp-login for an existing passenger', () {
      backend.resendOtp(
        const ResendOtpRequest(
          target: '024 123 4567',
          purpose: OtpPurpose.login,
        ),
      );
      final result = backend.otpLogin(
        const OtpLoginRequest(
          target: '+233241234567',
          code: MockBackend.otpCode,
        ),
      );
      expect(result.isOk, isTrue);
    });

    test('no code requested, wrong code, expired code, too many tries', () {
      const login = OtpLoginRequest(target: '0241234567', code: '654321');
      expect(code(backend.otpLogin(login)), 'OTP_NOT_FOUND');

      backend.resendOtp(
        const ResendOtpRequest(target: '0241234567', purpose: OtpPurpose.login),
      );
      for (var i = 0; i < MockBackend.otpMaxAttempts; i++) {
        expect(code(backend.otpLogin(login)), 'OTP_INVALID');
      }
      expect(code(backend.otpLogin(login)), 'OTP_ATTEMPTS_EXCEEDED');

      now = now.add(const Duration(seconds: 61));
      backend.resendOtp(
        const ResendOtpRequest(target: '0241234567', purpose: OtpPurpose.login),
      );
      now = now.add(const Duration(seconds: 301));
      expect(
        code(
          backend.otpLogin(
            const OtpLoginRequest(
              target: '0241234567',
              code: MockBackend.otpCode,
            ),
          ),
        ),
        'OTP_EXPIRED',
      );
    });
  });

  group('login', () {
    test('existing driver with the seed password', () {
      final result = backend.login(
        const LoginRequest(
          identifier: '0201234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(result.isOk, isTrue);
    });

    test('unknown phone and wrong password look the same', () {
      expect(
        code(
          backend.login(
            const LoginRequest(identifier: '0551234567', password: 'x'),
          ),
        ),
        'INVALID_CREDENTIALS',
      );
      expect(
        code(
          backend.login(
            const LoginRequest(identifier: '0241234567', password: 'x'),
          ),
        ),
        'INVALID_CREDENTIALS',
      );
    });

    test('five wrong passwords lock the account for 15 minutes', () {
      const wrong = LoginRequest(identifier: '0241234567', password: 'x');
      for (var i = 0; i < MockBackend.loginMaxFailedAttempts; i++) {
        backend.login(wrong);
      }
      final locked = backend.login(
        const LoginRequest(
          identifier: '0241234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(code(locked), 'ACCOUNT_LOCKED');
      expect(
        (locked.failureOrNull! as AccountLockedFailure).lockedUntil,
        now.add(const Duration(minutes: 15)),
      );
    });

    test('a suspended account', () {
      backend.suspend('0241234567');
      final result = backend.login(
        const LoginRequest(
          identifier: '0241234567',
          password: MockBackend.seedPassword,
        ),
      );
      expect(result.failureOrNull, isA<AccountSuspendedFailure>());
    });
  });

  group('tokens', () {
    TokenPairResponse signIn() => backend
        .login(
          const LoginRequest(
            identifier: '0241234567',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!;

    test('refresh rotates; the old token reused revokes every session', () {
      final first = signIn();
      final other = signIn();
      final rotated = backend.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      expect(rotated.isOk, isTrue);
      expect(backend.activeSessions('0241234567'), 2);

      final reused = backend.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      expect(code(reused), 'REFRESH_TOKEN_REUSE_DETECTED');
      expect(backend.activeSessions('0241234567'), 0);
      expect(code(backend.getMe(other.accessToken)), 'UNAUTHORIZED');
    });

    test(
      'logout revokes the session, so its refresh token counts as reuse',
      () {
        final pair = signIn();
        expect(backend.getMe(pair.accessToken).isOk, isTrue);

        expect(backend.logout(pair.accessToken).isOk, isTrue);
        expect(code(backend.getMe(pair.accessToken)), 'UNAUTHORIZED');
        expect(
          code(
            backend.refresh(RefreshRequest(refreshToken: pair.refreshToken)),
          ),
          'REFRESH_TOKEN_REUSE_DETECTED',
        );
      },
    );

    test('an expired access token is UNAUTHORIZED', () {
      final pair = signIn();
      backend.expireAccessTokens();
      expect(code(backend.getMe(pair.accessToken)), 'UNAUTHORIZED');
    });
  });

  test('GET /users/me returns the profile and roles', () {
    final pair = backend
        .login(
          const LoginRequest(
            identifier: 'kofi.boateng@gmail.com',
            password: MockBackend.seedPassword,
          ),
        )
        .valueOrNull!;
    final me = backend.getMe(pair.accessToken).valueOrNull!;
    expect(me.roles, ['driver']);
    expect(me.profile?.fullName, 'Kofi Boateng');
    expect(me.phoneNumber, MockBackend.driverPhone);
  });
}
