import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_store.g.dart';

/// Remembers on this device whether the user has finished onboarding.
abstract interface class OnboardingStore {
  Future<bool> isSeen();

  Future<void> markSeen();
}

/// [OnboardingStore] kept in shared preferences.
class SharedPreferencesOnboardingStore implements OnboardingStore {
  SharedPreferencesOnboardingStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const String key = 'onboarding_seen';

  @override
  Future<bool> isSeen() async => await _preferences.getBool(key) ?? false;

  @override
  Future<void> markSeen() => _preferences.setBool(key, true);
}

@Riverpod(keepAlive: true)
OnboardingStore onboardingStore(Ref ref) =>
    SharedPreferencesOnboardingStore(SharedPreferencesAsync());
