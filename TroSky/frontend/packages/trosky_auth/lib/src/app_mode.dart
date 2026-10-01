import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

part 'app_mode.g.dart';

/// Which interface the mobile app shows. Drivers sign up through the "Sign
/// up as a driver" link (docs/design-decisions.md, decision 7).
enum AppMode {
  passenger,
  driver;

  /// The backend role slug that allows this mode.
  String get role => name;
}

/// Remembers the mode between app starts.
abstract interface class AppModeStore {
  Future<AppMode?> read();

  Future<void> write(AppMode mode);
}

/// [AppModeStore] in shared preferences.
class SharedPreferencesAppModeStore implements AppModeStore {
  SharedPreferencesAppModeStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const String key = 'app_mode';

  @override
  Future<AppMode?> read() async {
    final value = await _preferences.getString(key);
    return AppMode.values.where((m) => m.name == value).firstOrNull;
  }

  @override
  Future<void> write(AppMode mode) => _preferences.setString(key, mode.name);
}

@Riverpod(keepAlive: true)
AppModeStore appModeStore(Ref ref) =>
    SharedPreferencesAppModeStore(SharedPreferencesAsync());

/// The current mode; passenger until switched.
@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  @override
  Future<AppMode> build() async =>
      await ref.watch(appModeStoreProvider).read() ?? AppMode.passenger;

  Future<void> set(AppMode mode) async {
    await ref.read(appModeStoreProvider).write(mode);
    state = AsyncData(mode);
  }
}

/// Whether the signed-in user may use [mode]: their roles include it.
bool sessionAllowsMode(SessionState session, AppMode mode) =>
    session is SessionAuthenticated && session.roles.contains(mode.role);
