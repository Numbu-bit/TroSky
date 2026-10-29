import 'package:shared_preferences/shared_preferences.dart';

/// The payment method each passenger used last on this device, so Payment
/// offers it first: "wallet" or a saved number's id.
abstract interface class PayMethodStore {
  Future<String?> lastMethod(String userId);

  Future<void> saveLastMethod(String userId, String key);
}

/// [PayMethodStore] in shared preferences. Holds no number, only the id
/// the backend gave it.
class SharedPreferencesPayMethodStore implements PayMethodStore {
  SharedPreferencesPayMethodStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  static String keyFor(String userId) => 'payment.last_method.$userId';

  @override
  Future<String?> lastMethod(String userId) =>
      _preferences.getString(keyFor(userId));

  @override
  Future<void> saveLastMethod(String userId, String key) =>
      _preferences.setString(keyFor(userId), key);
}

/// [PayMethodStore] in memory, for tests.
class InMemoryPayMethodStore implements PayMethodStore {
  final Map<String, String> methods = {};

  @override
  Future<String?> lastMethod(String userId) async => methods[userId];

  @override
  Future<void> saveLastMethod(String userId, String key) async =>
      methods[userId] = key;
}
