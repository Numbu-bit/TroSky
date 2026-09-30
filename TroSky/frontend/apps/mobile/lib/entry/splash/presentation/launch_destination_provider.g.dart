// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_destination_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Completes when the first frame is on screen, which is when the native
/// launch screen gives way to the splash. On a slow phone that can be over
/// a second after the splash is first built.

@ProviderFor(firstFrameShown)
final firstFrameShownProvider = FirstFrameShownProvider._();

/// Completes when the first frame is on screen, which is when the native
/// launch screen gives way to the splash. On a slow phone that can be over
/// a second after the splash is first built.

final class FirstFrameShownProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Completes when the first frame is on screen, which is when the native
  /// launch screen gives way to the splash. On a slow phone that can be over
  /// a second after the splash is first built.
  FirstFrameShownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstFrameShownProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstFrameShownHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return firstFrameShown(ref);
  }
}

String _$firstFrameShownHash() => r'29240b72f72b9bd2e8d0e264b82d6cbafe3fdf51';

/// Reads the onboarding flag and looks for a saved session while the splash
/// is shown for [splashMinimumDuration], then picks where to go.

@ProviderFor(launchDestination)
final launchDestinationProvider = LaunchDestinationProvider._();

/// Reads the onboarding flag and looks for a saved session while the splash
/// is shown for [splashMinimumDuration], then picks where to go.

final class LaunchDestinationProvider
    extends
        $FunctionalProvider<
          AsyncValue<LaunchDestination>,
          LaunchDestination,
          FutureOr<LaunchDestination>
        >
    with
        $FutureModifier<LaunchDestination>,
        $FutureProvider<LaunchDestination> {
  /// Reads the onboarding flag and looks for a saved session while the splash
  /// is shown for [splashMinimumDuration], then picks where to go.
  LaunchDestinationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'launchDestinationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$launchDestinationHash();

  @$internal
  @override
  $FutureProviderElement<LaunchDestination> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LaunchDestination> create(Ref ref) {
    return launchDestination(ref);
  }
}

String _$launchDestinationHash() => r'6562f1be70fe03a3e900d590e1823f6f0087ed44';
