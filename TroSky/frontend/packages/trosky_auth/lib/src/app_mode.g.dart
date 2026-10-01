// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appModeStore)
final appModeStoreProvider = AppModeStoreProvider._();

final class AppModeStoreProvider
    extends $FunctionalProvider<AppModeStore, AppModeStore, AppModeStore>
    with $Provider<AppModeStore> {
  AppModeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModeStoreHash();

  @$internal
  @override
  $ProviderElement<AppModeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppModeStore create(Ref ref) {
    return appModeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppModeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppModeStore>(value),
    );
  }
}

String _$appModeStoreHash() => r'baa7b42669eb67f4097a2bedd9b9b5f0bcc8cc24';

/// The current mode; passenger until switched.

@ProviderFor(AppModeController)
final appModeControllerProvider = AppModeControllerProvider._();

/// The current mode; passenger until switched.
final class AppModeControllerProvider
    extends $AsyncNotifierProvider<AppModeController, AppMode> {
  /// The current mode; passenger until switched.
  AppModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModeControllerHash();

  @$internal
  @override
  AppModeController create() => AppModeController();
}

String _$appModeControllerHash() => r'93f369bcfe30948bf7607e27c88a0683288775bd';

/// The current mode; passenger until switched.

abstract class _$AppModeController extends $AsyncNotifier<AppMode> {
  FutureOr<AppMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppMode>, AppMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppMode>, AppMode>,
              AsyncValue<AppMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
