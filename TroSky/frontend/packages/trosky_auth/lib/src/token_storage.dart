import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the refresh token is kept between app starts. The access token is
/// only ever held in memory (see `TokenManager`).
abstract interface class RefreshTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

/// [RefreshTokenStore] in the platform keystore: Keychain on iOS, an
/// encrypted store backed by the Android Keystore on Android.
class SecureRefreshTokenStore implements RefreshTokenStore {
  const SecureRefreshTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String key = 'trosky.refresh_token';

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: key);
}

/// [RefreshTokenStore] in memory, for tests.
class InMemoryRefreshTokenStore implements RefreshTokenStore {
  InMemoryRefreshTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}
