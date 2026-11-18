// Pins the wire shape of `POST /auth/login` against the backend's
// Pydantic `LoginRequest` model. If the frontend starts sending
// `email`/`username`/`phone` instead of `identifier`, this breaks loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';

void main() {
  test('LoginRequest.toJson sends identifier + password (no renames)', () {
    final json = const LoginRequest(
      identifier: '+233245550201',
      password: 'TroSkyDemo!2026',
    ).toJson();
    expect(json.keys.toSet(), {'identifier', 'password'});
    expect(json['identifier'], '+233245550201');
    expect(json['password'], 'TroSkyDemo!2026');
    // Field names must match backend/app/schemas/auth.LoginRequest exactly:
    // not 'email', 'username', 'phone' or 'phone_number'.
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('username'), isFalse);
    expect(json.containsKey('phone'), isFalse);
    expect(json.containsKey('phone_number'), isFalse);
  });

  test(
    'LoginRequest.toJson includes device only when present, as snake_case '
    'device.device_id',
    () {
      final withoutDevice = const LoginRequest(
        identifier: 'x',
        password: 'y',
      ).toJson();
      expect(withoutDevice.containsKey('device'), isFalse);

      final withDevice = const LoginRequest(
        identifier: 'x',
        password: 'y',
        device: DeviceContext(deviceId: 'abc', deviceName: 'iPhone'),
      ).toJson();
      final device = withDevice['device'] as Map<String, dynamic>;
      expect(device['device_id'], 'abc');
      expect(device['device_name'], 'iPhone');
    },
  );
}
