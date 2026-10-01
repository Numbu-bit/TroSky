import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';

import 'support.dart';

void main() {
  test('passenger until switched; the switch survives a restart', () async {
    final backend = MockBackend();
    final store = InMemoryRefreshTokenStore();
    final modes = InMemoryAppModeStore();

    final first = appContainer(
      backend: backend,
      store: store,
      modeStore: modes,
    );
    expect(
      await first.read(appModeControllerProvider.future),
      AppMode.passenger,
    );
    await first.read(appModeControllerProvider.notifier).set(AppMode.driver);

    final second = appContainer(
      backend: backend,
      store: store,
      modeStore: modes,
    );
    expect(await second.read(appModeControllerProvider.future), AppMode.driver);
  });

  test('the shared-preferences store reads back what it wrote', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = SharedPreferencesAppModeStore(SharedPreferencesAsync());

    expect(await store.read(), isNull);
    await store.write(AppMode.driver);
    expect(
      await SharedPreferencesAppModeStore(SharedPreferencesAsync()).read(),
      AppMode.driver,
    );
  });

  test('a signed-in user may use a mode only with its role', () {
    final passenger = SessionAuthenticated(
      UserResponse(
        id: 'u',
        phoneNumber: '+233241234567',
        isActive: true,
        phoneVerified: true,
        emailVerified: false,
        roles: const ['passenger'],
        createdAt: DateTime.utc(2026),
      ),
    );
    expect(sessionAllowsMode(passenger, AppMode.passenger), isTrue);
    expect(sessionAllowsMode(passenger, AppMode.driver), isFalse);
    expect(
      sessionAllowsMode(const SessionUnauthenticated(), AppMode.passenger),
      isFalse,
    );
  });
}
