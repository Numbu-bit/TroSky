// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signup_location.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(signUpLocator)
final signUpLocatorProvider = SignUpLocatorProvider._();

final class SignUpLocatorProvider
    extends $FunctionalProvider<SignUpLocator, SignUpLocator, SignUpLocator>
    with $Provider<SignUpLocator> {
  SignUpLocatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signUpLocatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signUpLocatorHash();

  @$internal
  @override
  $ProviderElement<SignUpLocator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignUpLocator create(Ref ref) {
    return signUpLocator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignUpLocator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignUpLocator>(value),
    );
  }
}

String _$signUpLocatorHash() => r'13687d38973d2cdd866bfeaf4a3fcf3f8d896af3';
