import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/splash/data/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('onboarding is not seen on a fresh install', () async {
    final store = SharedPreferencesOnboardingStore(SharedPreferencesAsync());

    expect(await store.isSeen(), isFalse);
  });

  test('markSeen is remembered', () async {
    await SharedPreferencesOnboardingStore(SharedPreferencesAsync()).markSeen();

    // A new store stands in for the next app start.
    final store = SharedPreferencesOnboardingStore(SharedPreferencesAsync());
    expect(await store.isSeen(), isTrue);
  });
}
