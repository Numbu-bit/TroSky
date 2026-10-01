import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// [AppModeStore] in memory.
class InMemoryAppModeStore implements AppModeStore {
  AppMode? mode;

  @override
  Future<AppMode?> read() async => mode;

  @override
  Future<void> write(AppMode mode) async => this.mode = mode;
}

/// One app start in mock mode. Pass the same [backend] and [store] to a
/// second container to simulate restarting the app.
ProviderContainer appContainer({
  required MockBackend backend,
  required RefreshTokenStore store,
  AppModeStore? modeStore,
  List<Object> extra = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      envProvider.overrideWithValue(
        Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: 'mock'),
      ),
      mockBackendProvider.overrideWithValue(backend),
      mockLatencyProvider.overrideWithValue(Duration.zero),
      refreshTokenStoreProvider.overrideWithValue(store),
      appModeStoreProvider.overrideWithValue(
        modeStore ?? InMemoryAppModeStore(),
      ),
      ...extra.cast(),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
