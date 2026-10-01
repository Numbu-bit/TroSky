import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';

/// The last `GET /users/me`, kept so the app can open offline with a saved
/// session (docs/design-decisions.md, decision 9).
abstract interface class UserCache {
  Future<UserResponse?> read();

  Future<void> write(UserResponse user);

  Future<void> clear();
}

/// [UserCache] in shared preferences. Holds no secrets: the same fields
/// the profile screen shows.
class SharedPreferencesUserCache implements UserCache {
  SharedPreferencesUserCache(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const String key = 'session.last_user';

  @override
  Future<UserResponse?> read() async {
    final json = await _preferences.getString(key);
    if (json == null) return null;
    try {
      return UserResponse.fromJson(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );
    } on Object {
      // An older or damaged entry is just a missing cache.
      return null;
    }
  }

  @override
  Future<void> write(UserResponse user) =>
      _preferences.setString(key, jsonEncode(user.toJson()));

  @override
  Future<void> clear() => _preferences.remove(key);
}

/// [UserCache] in memory, for tests.
class InMemoryUserCache implements UserCache {
  InMemoryUserCache([this.user]);

  UserResponse? user;

  @override
  Future<UserResponse?> read() async => user;

  @override
  Future<void> write(UserResponse user) async => this.user = user;

  @override
  Future<void> clear() async => user = null;
}
