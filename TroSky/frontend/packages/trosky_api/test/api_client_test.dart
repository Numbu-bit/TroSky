import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'support/fake_adapter.dart';

final _env = Env.parse(
  apiBaseUrl: 'http://api.test/api/v1',
  wsBaseUrl: '',
  apiMode: 'live',
);

/// Refreshes by swapping 'old' for 'new' after a short wait, so concurrent
/// requests overlap the refresh.
class _FakeTokens implements SessionTokens {
  _FakeTokens({this.result});

  @override
  String? accessToken = 'old';

  int refreshCalls = 0;
  Result<String>? result;

  @override
  Future<Result<String>> refresh() async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final outcome = result ?? const Ok('new');
    if (outcome case Ok(:final value)) accessToken = value;
    return outcome;
  }
}

String? _bearer(RequestOptions options) =>
    options.headers['Authorization'] as String?;

void main() {
  group('single-flight refresh', () {
    test('5 parallel 401s → exactly 1 refresh, all 5 retried', () async {
      final tokens = _FakeTokens();
      final adapter = FakeAdapter(
        (options) async => _bearer(options) == 'Bearer new'
            ? const FakeReply(200, {'ok': true})
            : FakeReply(401, errorBody('UNAUTHORIZED')),
      );
      final dio = createApiClient(
        env: _env,
        tokens: () => tokens,
        adapter: adapter,
      );

      final responses = await Future.wait([
        for (var i = 0; i < 5; i++) dio.get<Object?>('/users/me'),
      ]);

      expect(tokens.refreshCalls, 1);
      expect(responses.map((r) => r.statusCode), everyElement(200));
      final sent = adapter.sentHeaders.map((h) => h['Authorization']).toList();
      expect(sent.where((b) => b == 'Bearer old'), hasLength(5));
      expect(sent.where((b) => b == 'Bearer new'), hasLength(5));
    });

    test('a 401 arriving after the refresh reuses the new token', () async {
      final tokens = _FakeTokens();
      final slow = Completer<void>();
      final adapter = FakeAdapter((options) async {
        if (_bearer(options) == 'Bearer new') {
          return const FakeReply(200, {'ok': true});
        }
        // The second request's 401 is held back until the first has
        // refreshed.
        if (options.path == '/slow') await slow.future;
        return FakeReply(401, errorBody('UNAUTHORIZED'));
      });
      final dio = createApiClient(
        env: _env,
        tokens: () => tokens,
        adapter: adapter,
      );

      final slowRequest = dio.get<Object?>('/slow');
      await dio.get<Object?>('/fast');
      slow.complete();
      await slowRequest;

      expect(tokens.refreshCalls, 1);
    });

    test(
      'a failed refresh fails the waiting requests with its failure',
      () async {
        final tokens = _FakeTokens(
          result: Err(
            AppFailure.fromResponse(
              statusCode: 401,
              body: errorBody('REFRESH_TOKEN_REUSE_DETECTED'),
            ),
          ),
        );
        final dio = createApiClient(
          env: _env,
          tokens: () => tokens,
          adapter: FakeAdapter(
            (_) async => FakeReply(401, errorBody('UNAUTHORIZED')),
          ),
        );
        final repo = LiveUserRepository(dio);

        final results = await Future.wait([repo.getMe(), repo.getMe()]);

        expect(tokens.refreshCalls, 1);
        for (final result in results) {
          expect(result.failureOrNull?.code, 'REFRESH_TOKEN_REUSE_DETECTED');
        }
      },
    );

    test('wrong credentials are not "fixed" by a refresh', () async {
      final tokens = _FakeTokens();
      final dio = createApiClient(
        env: _env,
        tokens: () => tokens,
        adapter: FakeAdapter(
          (_) async => FakeReply(401, errorBody('INVALID_CREDENTIALS')),
        ),
      );

      final result = await LiveAuthRepository(
        dio,
      ).login(const LoginRequest(identifier: '0241234567', password: 'x'));

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(result.failureOrNull?.code, 'INVALID_CREDENTIALS');
      expect(tokens.refreshCalls, 0);
    });
  });

  group('auth header', () {
    test('public endpoints send no token; logout and /users/me do', () async {
      final adapter = FakeAdapter((options) async {
        return switch (options.path) {
          '/auth/logout' => const FakeReply(204),
          '/users/me' => const FakeReply(200, _userJson),
          _ => const FakeReply(200, {'message': 'ok'}),
        };
      });
      final dio = createApiClient(
        env: _env,
        tokens: _FakeTokens.new,
        adapter: adapter,
      );
      final auth = LiveAuthRepository(dio);

      await auth.resendOtp(
        const ResendOtpRequest(target: '0241234567', purpose: OtpPurpose.login),
      );
      await auth.logout();
      await LiveUserRepository(dio).getMe();

      expect(_bearer(adapter.requests[0]), isNull);
      expect(_bearer(adapter.requests[1]), 'Bearer old');
      expect(_bearer(adapter.requests[2]), 'Bearer old');
    });
  });

  test('every request carries a UUID X-Request-ID', () async {
    final adapter = FakeAdapter((_) async => const FakeReply(200, _userJson));
    final dio = createApiClient(
      env: _env,
      tokens: _FakeTokens.new,
      adapter: adapter,
    );
    await LiveUserRepository(dio).getMe();
    await LiveUserRepository(dio).getMe();

    final ids = adapter.requests.map((r) => r.headers[requestIdHeader]);
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
    expect(ids.toSet(), hasLength(2));
  });

  group('retry', () {
    Dio client(FakeAdapter adapter) => createApiClient(
      env: _env,
      tokens: _FakeTokens.new,
      adapter: adapter,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    test(
      'a GET is retried twice on connection errors, same request ID',
      () async {
        var calls = 0;
        final adapter = FakeAdapter((options) async {
          calls++;
          if (calls < 3) {
            return FakeReply.fail(
              DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              ),
            );
          }
          return const FakeReply(200, _userJson);
        });

        final result = await LiveUserRepository(client(adapter)).getMe();

        expect(result.isOk, isTrue);
        expect(calls, 3);
        final ids = adapter.requests.map((r) => r.headers[requestIdHeader]);
        expect(ids.toSet(), hasLength(1));
      },
    );

    test('gives up with a NetworkFailure after the last retry', () async {
      final adapter = FakeAdapter(
        (options) async => FakeReply.fail(
          DioException.connectionError(requestOptions: options, reason: 'x'),
        ),
      );

      final result = await LiveUserRepository(client(adapter)).getMe();

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(adapter.requests, hasLength(3));
    });

    test('503 is retried, 500 is not', () async {
      final unavailable = FakeAdapter(
        (_) async => FakeReply(503, errorBody('SERVICE_UNAVAILABLE')),
      );
      await LiveUserRepository(client(unavailable)).getMe();
      expect(unavailable.requests, hasLength(3));

      final broken = FakeAdapter(
        (_) async => FakeReply(500, errorBody('INTERNAL_SERVER_ERROR')),
      );
      final result = await LiveUserRepository(client(broken)).getMe();
      expect(broken.requests, hasLength(1));
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('a POST is never retried', () async {
      final adapter = FakeAdapter(
        (options) async => FakeReply.fail(
          DioException.connectionError(requestOptions: options, reason: 'x'),
        ),
      );

      final result = await LiveAuthRepository(client(adapter)).login(
        const LoginRequest(identifier: '0241234567', password: 'TroSky2026'),
      );

      expect(adapter.requests, hasLength(1));
      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  test('timeouts become TimeoutFailure', () async {
    final adapter = FakeAdapter(
      (options) async => FakeReply.fail(
        DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: options,
        ),
      ),
    );
    final result = await LiveAuthRepository(
      createApiClient(env: _env, tokens: _FakeTokens.new, adapter: adapter),
    ).refresh(RefreshRequest(refreshToken: 'x' * 30));
    expect(result.failureOrNull, isA<TimeoutFailure>());
  });

  test('requests use the backend field names', () async {
    final adapter = FakeAdapter(
      (_) async => const FakeReply(201, {
        'user_id': 'u1',
        'phone_number': '+233241234567',
        'otp_sent_to': '+233241234567',
        'message': 'Registration successful.',
      }),
    );
    final result =
        await LiveAuthRepository(
          createApiClient(env: _env, tokens: _FakeTokens.new, adapter: adapter),
        ).register(
          const RegisterRequest(
            phoneNumber: '0241234567',
            email: 'ama.mensah@gmail.com',
            password: 'TroSky2026',
            fullName: 'Ama Mensah',
            role: RegistrableRole.driver,
          ),
        );

    expect(adapter.requests.single.path, '/auth/register');
    expect(adapter.requests.single.data, {
      'phone_number': '0241234567',
      'email': 'ama.mensah@gmail.com',
      'password': 'TroSky2026',
      'full_name': 'Ama Mensah',
      'role': 'driver',
      'preferred_language': 'en',
    });
    expect(result.valueOrNull?.otpSentTo, '+233241234567');
  });

  test("a passenger's position goes in the register body", () async {
    final adapter = FakeAdapter(
      (_) async => const FakeReply(201, {
        'user_id': 'u2',
        'phone_number': '+233551234567',
        'otp_sent_to': 'yaw.asante@gmail.com',
        'message': 'Registration successful.',
      }),
    );
    await LiveAuthRepository(
      createApiClient(env: _env, tokens: _FakeTokens.new, adapter: adapter),
    ).register(
      const RegisterRequest(
        phoneNumber: '0551234567',
        email: 'yaw.asante@gmail.com',
        password: 'Accra2026',
        fullName: 'Yaw Asante',
        latitude: 5.6037,
        longitude: -0.187,
      ),
    );

    expect(adapter.requests.single.data, {
      'phone_number': '0551234567',
      'email': 'yaw.asante@gmail.com',
      'password': 'Accra2026',
      'full_name': 'Yaw Asante',
      'role': 'passenger',
      'preferred_language': 'en',
      'latitude': 5.6037,
      'longitude': -0.187,
    });
  });

  group('Home endpoints parse what the backend sends', () {
    Dio dio(FakeAdapter adapter) =>
        createApiClient(env: _env, tokens: _FakeTokens.new, adapter: adapter);

    test('GET /stops/nearby is public and takes the query', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, [
          {
            'id': 's1',
            'name': 'Madina Zongo Junction',
            'code': null,
            'address': null,
            'city': 'Accra',
            'region': 'Greater Accra',
            'latitude': 5.6731,
            'longitude': -0.1661,
            'distance_m': 212.4,
          },
        ]),
      );
      final stops = await LiveRouteRepository(
        dio(adapter),
      ).nearbyStops(latitude: 5.67, longitude: -0.166, limit: 1);

      final request = adapter.requests.single;
      expect(request.path, '/stops/nearby');
      expect(request.queryParameters, {
        'latitude': 5.67,
        'longitude': -0.166,
        'limit': 1,
      });
      expect(request.headers['Authorization'], isNull);
      expect(stops.valueOrNull?.single.name, 'Madina Zongo Junction');
      expect(stops.valueOrNull?.single.distanceM, 212.4);
    });

    test('GET /vehicles/nearby: Decimal heading as a string, new types '
        'as other', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, [
          {
            'trip_id': 't1',
            'vehicle_id': 'v1',
            'vehicle_registration_number': 'GR 1234-24',
            'vehicle_type': 'trotro',
            'route_id': 'r1',
            'route_name': 'Madina → Circle',
            'latitude': 5.6,
            'longitude': -0.19,
            'heading': '182.50',
            'distance_m': 812.3,
            'available_seats': 5,
            'updated_at': '2026-10-01T09:00:00Z',
          },
        ]),
      );
      final vehicles = await LiveTrackingRepository(
        dio(adapter),
      ).nearbyVehicles(latitude: 5.6, longitude: -0.19, radiusM: 4000);

      expect(adapter.requests.single.queryParameters['radius_m'], 4000);
      final vehicle = vehicles.valueOrNull!.single;
      expect(vehicle.heading, 182.5);
      expect(vehicle.vehicleType, VehicleType.other);
      expect(vehicle.availableSeats, 5);
    });

    test('GET /trips/search: query names and formats; Decimal fare as sent; '
        'G20/G21 fields absent → null', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, {
          'items': [
            {
              'trip_id': 't1',
              'route_id': 'r1',
              'route_name': 'Madina - Circle',
              'origin_stop_id': 's1',
              'destination_stop_id': 's4',
              'scheduled_departure_at': '2026-10-02T07:15:00Z',
              'scheduled_arrival_at': null,
              'estimated_duration_minutes': 45,
              'distance_km': '14.00',
              'fare_amount': '8.00',
              'status': 'scheduled',
              'available_seats': 12,
              'vehicle_registration_number': 'GT 4402-26',
              'vehicle_type': 'minibus',
              'pickup_stop_id': 's1',
              'pickup_stop_name': 'Accra Madina',
              'pickup_distance_m': 350.4,
              'pickup_source': 'gps',
              'fare': {
                'current': '6.50',
                'solo': '8.00',
                'minimum': '2.00',
                'platform_fee': '0.50',
                'total': '7.00',
                'currency': 'GHS',
                'riders_count': 3,
                'seats': 1,
              },
              'ride_minutes': 45,
              'vehicle_eta_to_pickup_minutes': 4,
              'has_passed_pickup': false,
            },
          ],
          'total': 21,
          'limit': 20,
          'offset': 0,
        }),
      );
      final page = await LiveRouteRepository(dio(adapter)).searchTrips(
        TripSearchQuery(
          destinationStopId: 's4',
          travelDate: DateTime.utc(2026, 10, 2),
          departureAfter: const Duration(hours: 7, minutes: 5, seconds: 9),
          pickupLatitude: 5.67,
          pickupLongitude: -0.166,
          sort: SearchSort.cheapest,
          vehicleType: VehicleType.minibus,
        ),
      );

      final request = adapter.requests.single;
      expect(request.path, '/trips/search');
      expect(request.queryParameters, {
        'destination_stop_id': 's4',
        'travel_date': '2026-10-02',
        'departure_after': '07:05:09',
        'pickup_latitude': 5.67,
        'pickup_longitude': -0.166,
        'sort': 'cheapest',
        'vehicle_type': 'minibus',
        'limit': 20,
        'offset': 0,
      });
      expect(request.headers['Authorization'], isNull);
      final trip = page.valueOrNull!.items.single;
      expect(trip.fareAmount, '8.00');
      expect(trip.distanceKm, 14);
      expect(trip.vehicleType, VehicleType.minibus);
      expect(trip.pickupSource, PickupSource.gps);
      expect(
        (trip.fare?.current, trip.fare?.solo, trip.fare?.minimum),
        ('6.50', '8.00', '2.00'),
      );
      expect((trip.fare?.total, trip.fare?.ridersCount), ('7.00', 3));
      expect(
        (
          trip.rideMinutes,
          trip.vehicleEtaToPickupMinutes,
          trip.hasPassedPickup,
        ),
        (45, 4, false),
      );
      expect(page.valueOrNull!.hasMore, isTrue);
    });

    test('a 0.12.0 search result (no fare) still reads', () {
      final trip = TripSearchResultResponse.fromJson(const {
        'trip_id': 't1',
        'route_id': 'r1',
        'route_name': 'Madina - Circle',
        'origin_stop_id': 's1',
        'destination_stop_id': 's4',
        'scheduled_departure_at': '2026-10-02T07:15:00Z',
        'fare_amount': '8.00',
        'status': 'scheduled',
        'available_seats': 12,
      });
      expect((trip.fare, trip.hasPassedPickup), (null, false));
    });

    test(
      'GET /trips/{id}/fare-quote: the stops and seats, money as sent',
      () async {
        final adapter = FakeAdapter(
          (_) async => const FakeReply(200, {
            'current': '4.00',
            'solo': '8.00',
            'minimum': '2.00',
            'platform_fee': '1.00',
            'total': '9.00',
            'currency': 'GHS',
            'riders_count': 0,
            'seats': 2,
            'trip_id': 't1',
            'origin_stop_id': 's1',
            'destination_stop_id': 's4',
          }),
        );
        final quote = await LiveRouteRepository(dio(adapter)).fareQuote(
          't1',
          originStopId: 's1',
          destinationStopId: 's4',
          seats: 2,
        );
        final request = adapter.requests.single;
        expect(request.path, '/trips/t1/fare-quote');
        expect(request.queryParameters, {
          'origin_stop_id': 's1',
          'destination_stop_id': 's4',
          'seats': 2,
        });
        expect(request.headers['Authorization'], isNull);
        final value = quote.valueOrNull!;
        expect(
          (value.current, value.solo, value.total),
          ('4.00', '8.00', '9.00'),
        );
        expect(value.summary.platformFee, '1.00');
      },
    );

    test('GET /stops?q= reads the page of stops', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, {
          'items': [
            {
              'id': 's1',
              'name': 'Accra Madina',
              'code': 'ACC-MAD',
              'address': null,
              'city': 'Accra',
              'region': null,
              'latitude': 5.6687,
              'longitude': -0.1664,
            },
          ],
          'total': 1,
          'limit': 20,
          'offset': 0,
        }),
      );
      final stops = await LiveRouteRepository(
        dio(adapter),
      ).searchStops(' mad ');
      expect(adapter.requests.single.queryParameters, {
        'q': 'mad',
        'limit': 20,
      });
      expect(stops.valueOrNull?.single.code, 'ACC-MAD');
    });

    test('POST /users/me/favourite-routes sends only what is set', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(201, {
          'id': 'f1',
          'origin_stop_id': 's1',
          'origin_stop_name': 'Accra Madina',
          'destination_stop_id': 's4',
          'destination_stop_name': 'Accra Circle',
          'label': null,
          'created_at': '2026-10-02T09:00:00Z',
        }),
      );
      await LiveUserRepository(dio(adapter)).addFavouriteRoute(
        const FavouriteRouteCreateRequest(
          originStopId: 's1',
          destinationStopId: 's4',
        ),
      );
      expect(adapter.requests.single.data, {
        'origin_stop_id': 's1',
        'destination_stop_id': 's4',
      });
    });

    test('GET /trips/{id}/seats is public; G20 fields absent → null', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, {
          'trip_id': 't1',
          'vehicle_id': 'v1',
          'total_seats': 2,
          'available_seats': 1,
          'seats': [
            {
              'id': 's1',
              'seat_number': 'A1',
              'row_number': 1,
              'column_number': 1,
              'seat_type': 'window',
              'is_available': true,
            },
            {
              'id': 's2',
              'seat_number': 'A2',
              'row_number': 1,
              'column_number': 2,
              'seat_type': 'recliner',
              'is_available': false,
            },
          ],
        }),
      );
      final seats = await LiveRouteRepository(dio(adapter)).tripSeats('t1');
      expect(adapter.requests.single.path, '/trips/t1/seats');
      expect(adapter.requests.single.headers['Authorization'], isNull);
      final map = seats.valueOrNull!;
      expect(map.seats.last.seatType, SeatType.standard);
    });

    test('POST /bookings: the backend names, an Idempotency-Key, money as '
        'sent', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(201, {
          'id': 'b1',
          'booking_reference': 'TS-8KQ2',
          'trip_id': 't1',
          'status': 'pending',
          'passenger_count': 2,
          'origin_stop_id': null,
          'destination_stop_id': 's4',
          'fare_amount': '16.00',
          'platform_fee': '1.00',
          'total_amount': '17.00',
          'expires_at': '2026-10-02T09:10:00Z',
          'created_at': '2026-10-02T09:00:00Z',
          'passengers': [
            {
              'id': 'p1',
              'seat_id': 's1',
              'full_name': 'Kwame Asante',
              'phone_number': '+233240950580',
            },
            {
              'id': 'p2',
              'seat_id': 's2',
              'full_name': "Kwame's guest 2",
              'phone_number': null,
            },
          ],
          'trip': {
            'scheduled_departure_at': '2026-10-02T09:30:00Z',
            'route_name': 'Madina - Circle',
            'origin_stop_name': 'Accra Madina',
            'destination_stop_name': 'Accra Circle',
            'status': 'scheduled',
            'vehicle_registration_number': 'GT 4402-26',
          },
          'boarding_stop_name': 'Accra Madina',
          'alighting_stop_name': 'Accra Circle',
        }),
      );
      final booking = await LiveBookingRepository(dio(adapter)).create(
        const BookingCreateRequest(
          tripId: 't1',
          passengers: [
            PassengerInput(
              seatId: 's1',
              fullName: 'Kwame Asante',
              phoneNumber: '+233240950580',
            ),
            PassengerInput(seatId: 's2', fullName: "Kwame's guest 2"),
          ],
          destinationStopId: 's4',
          pickupLatitude: 5.67,
          pickupLongitude: -0.166,
        ),
        idempotencyKey: 'k-1',
      );
      final request = adapter.requests.single;
      expect(request.path, '/bookings');
      expect(request.headers['Idempotency-Key'], 'k-1');
      expect(request.data, {
        'trip_id': 't1',
        'passengers': [
          {
            'seat_id': 's1',
            'full_name': 'Kwame Asante',
            'phone_number': '+233240950580',
          },
          {'seat_id': 's2', 'full_name': "Kwame's guest 2"},
        ],
        'destination_stop_id': 's4',
        'pickup_latitude': 5.67,
        'pickup_longitude': -0.166,
      });
      final b = booking.valueOrNull!;
      expect(
        (b.fareAmount, b.platformFee, b.totalAmount),
        ('16.00', '1.00', '17.00'),
      );
      expect(b.expiresAt, DateTime.utc(2026, 10, 2, 9, 10));
      expect(b.status, BookingStatus.pending);
    });

    test(
      'GET /bookings?status=pending,payment_pending&upcoming=true',
      () async {
        final adapter = FakeAdapter(
          (_) async => const FakeReply(200, {
            'items': <Object>[],
            'total': 0,
            'limit': 20,
            'offset': 0,
          }),
        );
        await LiveBookingRepository(dio(adapter)).list(
          statuses: [BookingStatus.pending, BookingStatus.paymentPending],
          upcoming: true,
        );
        expect(adapter.requests.single.queryParameters, {
          'status': 'pending,payment_pending',
          'upcoming': true,
          'limit': 20,
          'offset': 0,
        });
      },
    );

    test('POST /bookings/{id}/cancel', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(409, {
          'error': {
            'code': 'INVALID_STATE_TRANSITION',
            'message': "A booking in status 'expired' cannot be cancelled.",
            'details': <String, Object?>{},
            'request_id': 'r',
          },
        }),
      );
      final result = await LiveBookingRepository(dio(adapter)).cancel('b1');
      expect(adapter.requests.single.path, '/bookings/b1/cancel');
      expect(adapter.requests.single.data, <String, Object?>{});
      expect(result.failureOrNull?.code, 'INVALID_STATE_TRANSITION');
    });

    test('GET /users/me/favourite-routes', () async {
      final adapter = FakeAdapter(
        (_) async => const FakeReply(200, [
          {
            'id': 'f1',
            'origin_stop_id': 's1',
            'origin_stop_name': 'Madina',
            'destination_stop_id': 's2',
            'destination_stop_name': 'Circle',
            'label': null,
            'created_at': '2026-10-01T09:00:00Z',
          },
        ]),
      );
      final routes = await LiveUserRepository(
        dio(adapter),
      ).listFavouriteRoutes();

      expect(adapter.requests.single.path, '/users/me/favourite-routes');
      expect(routes.valueOrNull?.single.destinationStopName, 'Circle');
    });
  });
}

const _userJson = {
  'id': '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41',
  'phone_number': '+233241234567',
  'email': 'ama.mensah@gmail.com',
  'is_active': true,
  'phone_verified': true,
  'email_verified': false,
  'roles': ['passenger'],
  'created_at': '2026-07-01T08:00:00+00:00',
  'profile': {
    'full_name': 'Ama Mensah',
    'date_of_birth': null,
    'gender': null,
    'preferred_language': 'en',
    'avatar_url': null,
    'ghana_card_number': null,
    'ghana_card_verified': false,
  },
};
