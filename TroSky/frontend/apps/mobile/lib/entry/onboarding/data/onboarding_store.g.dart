// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(onboardingStore)
final onboardingStoreProvider = OnboardingStoreProvider._();

final class OnboardingStoreProvider
    extends
        $FunctionalProvider<OnboardingStore, OnboardingStore, OnboardingStore>
    with $Provider<OnboardingStore> {
  OnboardingStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingStoreHash();

  @$internal
  @override
  $ProviderElement<OnboardingStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OnboardingStore create(Ref ref) {
    return onboardingStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingStore>(value),
    );
  }
}

String _$onboardingStoreHash() => r'760ea246dcaa80594d59ff771f2978f5e726efd0';
