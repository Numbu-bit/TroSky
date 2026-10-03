// Creates trips for today on the LOCAL backend, so live-mode Search finds
// something (Step 9, Part 3). Local database only: it talks to the API on
// localhost and refuses anything else.
//
// From TroSky/frontend:
//
//   dart run tool/seed_local_trips.dart
//   dart run tool/seed_local_trips.dart --api http://127.0.0.1:8000/api/v1
//
// It needs the local docker stack (backend/docker-compose or the
// `trosky-api-local` container) with the dev seed loaded
// (`python -m scripts.seed_dev_data`), and `docker` on the PATH: new accounts
// are verified with the code the console SMS provider writes to the
// container's log (`--container`, default trosky-api-local).
//
// What it makes, reusing whatever already exists (safe to run again):
// * the dev admin logs in (DEV_ADMIN_PASSWORD, else the seed's fallback);
// * a fleet owner (+233 20 000 0301) with "TroSky Dev Fleet" and three
//   approved vehicles with seat layouts: a 14-seat minibus, an 18-seat bus
//   and a 2-seat saloon car;
// * an approved driver (+233 20 000 0302) assigned to the vehicles;
// * trips on the seeded "Madina - Circle" route in the next hours, from
//   20 minutes from now, each with a vehicle and the driver. Times that
//   already have a trip are skipped.

import 'dart:convert';
import 'dart:io';

const _adminEmail = 'admin@trosky.africa';
const _adminPasswordFallback = 'TroSkyDevAdmin!2026';
const _routeName = 'Madina - Circle';
const _fare = '8.00';
const _rideMinutes = 45;

/// Minutes from now, rounded up to 5, for the trips.
const _departuresIn = [20, 40, 65, 100, 140, 190, 250];

const _fleetOwner = _Account(
  phone: '+233200000301',
  email: 'trosky.dev.fleet@gmail.com',
  password: 'DevFleet2026',
  fullName: 'Dev Fleet Owner',
  role: 'passenger',
);

const _driver = _Account(
  phone: '+233200000302',
  email: 'trosky.dev.driver@gmail.com',
  password: 'DevDriver2026',
  fullName: 'Kwesi Mensah',
  role: 'driver',
);

const _vehicles = [
  _Vehicle('GT 4402-26', 'minibus', 'Toyota', 'Hiace', 14, columns: 3),
  _Vehicle('GR 7781-26', 'bus', 'Yutong', 'ZK6729', 18, columns: 4),
  _Vehicle('GE 2210-26', 'sedan', 'Toyota', 'Corolla', 2, columns: 2),
];

Future<void> main(List<String> args) async {
  final api = Uri.parse(
    _option(args, '--api') ?? 'http://localhost:8000/api/v1',
  );
  if (!{'localhost', '127.0.0.1'}.contains(api.host)) {
    stderr.writeln('Refusing ${api.host}: this script only seeds localhost.');
    exit(64);
  }
  final container = _option(args, '--container') ?? 'trosky-api-local';
  final client = _Api(api);
  try {
    await _seed(client, container);
  } on _Failure catch (failure) {
    stderr.writeln('Failed: $failure');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<void> _seed(_Api api, String container) async {
  _say('API ${api.base}');
  final admin = await api.login(
    _adminEmail,
    Platform.environment['DEV_ADMIN_PASSWORD'] ?? _adminPasswordFallback,
  );
  _say('Admin signed in');

  // Fleet owner, fleet and vehicles.
  var owner = await _account(api, _fleetOwner, container);
  final profile = await api.call('GET', '/fleet-owners/me', token: owner);
  // 404 with the role but no profile; 403 before the role exists.
  if (profile.status != 200) {
    await api.expect(
      'POST',
      '/fleet-owners/me',
      token: owner,
      body: {'business_name': 'TroSky Dev Fleet'},
    );
    // The new role is in the next access token.
    owner = await api.login(_fleetOwner.phone, _fleetOwner.password);
    _say('Fleet owner profile created');
  }
  final fleets = await api.expect('GET', '/fleets', token: owner) as List;
  final fleetId = fleets.isNotEmpty
      ? (fleets.first as Map)['id'] as String
      : ((await api.expect(
                  'POST',
                  '/fleets',
                  token: owner,
                  body: {'name': 'TroSky Dev Fleet'},
                ))
                as Map)['id']
            as String;
  final existing = {
    for (final v
        in await api.expect('GET', '/fleets/$fleetId/vehicles', token: owner)
            as List)
      (v as Map)['registration_number'] as String: v,
  };
  final vehicleIds = <String>[];
  for (final spec in _vehicles) {
    var vehicle = existing[spec.plate];
    if (vehicle == null) {
      vehicle =
          await api.expect(
                'POST',
                '/fleets/$fleetId/vehicles',
                token: owner,
                body: {
                  'registration_number': spec.plate,
                  'vehicle_type': spec.type,
                  'make': spec.make,
                  'model': spec.model,
                  'year': 2024,
                  'capacity': spec.seats,
                },
              )
              as Map;
      _say('Vehicle ${spec.plate} added');
    }
    final id = vehicle['id'] as String;
    final layout = await api.call(
      'GET',
      '/vehicles/$id/seat-layout',
      token: owner,
    );
    if (layout.status == 404) {
      await api.expect(
        'PUT',
        '/vehicles/$id/seat-layout',
        token: owner,
        body: spec.layout(),
      );
      _say('  seat layout: ${spec.seats} seats');
    }
    if (vehicle['status'] != 'approved') {
      await api.expect(
        'POST',
        '/admin/vehicles/$id/approve',
        token: admin,
        body: {'notes': 'Local test data'},
      );
      _say('  approved');
    }
    vehicleIds.add(id);
  }

  // Driver.
  var driverToken = await _account(api, _driver, container);
  var driverProfile = await api.call('GET', '/drivers/me', token: driverToken);
  if (driverProfile.status != 200) {
    await api.expect(
      'POST',
      '/drivers/me',
      token: driverToken,
      body: {
        'license_number': 'GHA-DL-DEV0302',
        'license_expiry': '2030-12-31',
        'license_class': 'C',
        'years_of_experience': 6,
      },
    );
    driverToken = await api.login(_driver.phone, _driver.password);
    driverProfile = await api.call('GET', '/drivers/me', token: driverToken);
    _say('Driver profile created');
  }
  final driver = driverProfile.json! as Map;
  final driverId = driver['id'] as String;
  if (driver['status'] != 'approved') {
    await api.expect(
      'POST',
      '/admin/drivers/$driverId/approve',
      token: admin,
      body: {'notes': 'Local test data'},
    );
    _say('Driver approved');
  }
  for (final vehicleId in vehicleIds) {
    // 409 when already assigned: fine.
    await api.call(
      'POST',
      '/vehicles/$vehicleId/assign-driver',
      token: owner,
      body: {'driver_id': driverId},
    );
  }

  // Trips.
  final routes =
      ((await api.expect('GET', '/routes', query: {'limit': '100'}))
              as Map)['items']
          as List;
  final route = routes.cast<Map<String, dynamic>>().firstWhere(
    (r) => r['name'] == _routeName,
    orElse: () => throw _Failure(
      'No "$_routeName" route: run the dev seed (scripts.seed_dev_data).',
    ),
  );
  final routeId = route['id'] as String;
  final now = DateTime.now().toUtc();
  final today = _date(now);
  final listed =
      ((await api.expect(
                'GET',
                '/admin/trips',
                token: admin,
                query: {'date': today, 'route_id': routeId, 'limit': '100'},
              ))
              as Map)['items']
          as List;
  final taken = {
    for (final t in listed)
      _minute(DateTime.parse((t as Map)['scheduled_departure_at'] as String)),
  };
  var made = 0;
  for (final (i, minutes) in _departuresIn.indexed) {
    final departs = _roundUp(now.add(Duration(minutes: minutes)));
    if (_date(departs) != today || taken.contains(_minute(departs))) continue;
    final trip =
        await api.expect(
              'POST',
              '/admin/trips',
              token: admin,
              body: {
                'route_id': routeId,
                'scheduled_departure_at': departs.toIso8601String(),
                'scheduled_arrival_at': departs
                    .add(const Duration(minutes: _rideMinutes))
                    .toIso8601String(),
                'fare_amount': _fare,
              },
            )
            as Map;
    final tripId = trip['id'] as String;
    final vehicleId = vehicleIds[i % vehicleIds.length];
    await api.expect(
      'POST',
      '/admin/trips/$tripId/assign-vehicle',
      token: admin,
      body: {'vehicle_id': vehicleId},
    );
    await api.expect(
      'POST',
      '/admin/trips/$tripId/assign-driver',
      token: admin,
      body: {'driver_id': driverId},
    );
    made++;
    _say(
      'Trip ${_clock(departs)} UTC on $_routeName · '
      '${_vehicles[i % _vehicles.length].plate}',
    );
  }
  _say(
    made == 0
        ? 'No new trips: the next departures already exist.'
        : '$made trip(s) created for $today.',
  );
}

/// Signs [account] in, registering and verifying it first if needed.
Future<String> _account(_Api api, _Account account, String container) async {
  final login = await api.call(
    'POST',
    '/auth/login',
    body: {'identifier': account.phone, 'password': account.password},
  );
  if (login.status == 200) {
    return (login.json! as Map)['access_token'] as String;
  }
  final code = login.errorCode;
  if (code == 'ACCOUNT_NOT_VERIFIED') {
    final target =
        ((login.json! as Map)['error'] as Map)['details']['target']
            as String? ??
        account.phone;
    final since = DateTime.now();
    await api.call(
      'POST',
      '/auth/resend-otp',
      body: {'target': target, 'purpose': 'registration'},
    );
    await _verify(api, target, container, since);
  } else if (code == 'INVALID_CREDENTIALS' || login.status == 401) {
    final since = DateTime.now();
    final registered =
        await api.expect(
              'POST',
              '/auth/register',
              body: {
                'phone_number': account.phone,
                'email': account.email,
                'password': account.password,
                'full_name': account.fullName,
                'role': account.role,
              },
            )
            as Map;
    _say('Registered ${account.fullName} (${account.phone})');
    await _verify(api, registered['otp_sent_to'] as String, container, since);
  } else if (login.status == 429) {
    throw _Failure(
      'The backend rate-limited logins (10 per 5 minutes per address). '
      'Wait a few minutes and run the script again.',
    );
  } else {
    throw _Failure('Login for ${account.phone}: ${login.status} ${login.body}');
  }
  return api.login(account.phone, account.password);
}

/// Reads the code sent to [target] from the container's log and verifies.
Future<void> _verify(
  _Api api,
  String target,
  String container,
  DateTime since,
) async {
  final pattern = RegExp(r'code is (\d{4,8})');
  for (var attempt = 0; attempt < 10; attempt++) {
    final logs = await Process.run('docker', [
      'logs',
      '--since',
      since.subtract(const Duration(seconds: 5)).toUtc().toIso8601String(),
      container,
    ]);
    final lines = '${logs.stdout}\n${logs.stderr}'
        .split('\n')
        .where((line) => line.contains(target) && pattern.hasMatch(line));
    if (lines.isNotEmpty) {
      final code = pattern.firstMatch(lines.last)!.group(1)!;
      await api.expect(
        'POST',
        '/auth/verify-otp',
        body: {'target': target, 'code': code, 'purpose': 'registration'},
      );
      _say('  verified $target');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw _Failure('No code for $target in the "$container" log.');
}

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

String _clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String _minute(DateTime t) => '${_date(t.toUtc())} ${_clock(t.toUtc())}';

DateTime _roundUp(DateTime t) {
  final extra = (5 - t.minute % 5) % 5;
  return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute + extra);
}

void _say(String line) => stdout.writeln(line);

class _Account {
  const _Account({
    required this.phone,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
  });

  final String phone;
  final String email;
  final String password;
  final String fullName;
  final String role;
}

class _Vehicle {
  const _Vehicle(
    this.plate,
    this.type,
    this.make,
    this.model,
    this.seats, {
    required this.columns,
  });

  final String plate;
  final String type;
  final String make;
  final String model;
  final int seats;
  final int columns;

  Map<String, Object> layout() {
    final rows = (seats / columns).ceil();
    return {
      'name': '$seats seats',
      'rows': rows,
      'columns': columns,
      'seats': [
        for (var i = 0; i < seats; i++)
          {
            'seat_number':
                '${String.fromCharCode(65 + i ~/ columns)}'
                '${i % columns + 1}',
            'row_number': i ~/ columns + 1,
            'column_number': i % columns + 1,
          },
      ],
    };
  }
}

class _Failure implements Exception {
  _Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Response {
  _Response(this.status, this.body);

  final int status;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);

  String? get errorCode => switch (json) {
    {'error': {'code': final String code}} => code,
    _ => null,
  };
}

class _Api {
  _Api(this.base);

  final Uri base;
  final HttpClient _http = HttpClient();

  Future<_Response> call(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String>? query,
  }) async {
    final uri = base.replace(path: '${base.path}$path', queryParameters: query);
    final request = await _http.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    return _Response(
      response.statusCode,
      await response.transform(utf8.decoder).join(),
    );
  }

  /// [call], failing on anything but a 2xx.
  Future<Object?> expect(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String>? query,
  }) async {
    final response = await call(
      method,
      path,
      token: token,
      body: body,
      query: query,
    );
    if (response.status == 429) {
      throw _Failure(
        'The backend rate-limited $method $path (logins: 10 per 5 minutes '
        'per address). Wait a few minutes and run the script again.',
      );
    }
    if (response.status < 200 || response.status > 299) {
      throw _Failure('$method $path: ${response.status} ${response.body}');
    }
    return response.json;
  }

  Future<String> login(String identifier, String password) async {
    final tokens =
        await expect(
              'POST',
              '/auth/login',
              body: {'identifier': identifier, 'password': password},
            )
            as Map;
    return tokens['access_token'] as String;
  }

  void close() => _http.close(force: true);
}
