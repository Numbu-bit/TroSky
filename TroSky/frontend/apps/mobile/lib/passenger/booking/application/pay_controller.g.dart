// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pay_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(payMethodStore)
final payMethodStoreProvider = PayMethodStoreProvider._();

final class PayMethodStoreProvider
    extends $FunctionalProvider<PayMethodStore, PayMethodStore, PayMethodStore>
    with $Provider<PayMethodStore> {
  PayMethodStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'payMethodStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$payMethodStoreHash();

  @$internal
  @override
  $ProviderElement<PayMethodStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PayMethodStore create(Ref ref) {
    return payMethodStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PayMethodStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PayMethodStore>(value),
    );
  }
}

String _$payMethodStoreHash() => r'ca5e31761162d9b5cad0e45a972551429225ddb6';

/// The wallet (`GET /wallet`), the saved MTN MoMo numbers
/// (`GET /users/me/payment-methods`) and the method used last. Fails only
/// when neither could be read.

@ProviderFor(payOptions)
final payOptionsProvider = PayOptionsProvider._();

/// The wallet (`GET /wallet`), the saved MTN MoMo numbers
/// (`GET /users/me/payment-methods`) and the method used last. Fails only
/// when neither could be read.

final class PayOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PayOptions>,
          PayOptions,
          FutureOr<PayOptions>
        >
    with $FutureModifier<PayOptions>, $FutureProvider<PayOptions> {
  /// The wallet (`GET /wallet`), the saved MTN MoMo numbers
  /// (`GET /users/me/payment-methods`) and the method used last. Fails only
  /// when neither could be read.
  PayOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'payOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$payOptionsHash();

  @$internal
  @override
  $FutureProviderElement<PayOptions> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PayOptions> create(Ref ref) {
    return payOptions(ref);
  }
}

String _$payOptionsHash() => r'd6866e1c0dd8ab432d9392455ea050e50f2768f1';

/// Pays for the booking on Payment and follows a mobile money payment until
/// the payer answers: [paymentSyncEvery], backing off after errors, paused
/// in the background ([pause], [resume]). Reopened while the booking is
/// `payment_pending`, it finds the payment under way and follows it.

@ProviderFor(PayController)
final payControllerProvider = PayControllerFamily._();

/// Pays for the booking on Payment and follows a mobile money payment until
/// the payer answers: [paymentSyncEvery], backing off after errors, paused
/// in the background ([pause], [resume]). Reopened while the booking is
/// `payment_pending`, it finds the payment under way and follows it.
final class PayControllerProvider
    extends $NotifierProvider<PayController, PayFlow> {
  /// Pays for the booking on Payment and follows a mobile money payment until
  /// the payer answers: [paymentSyncEvery], backing off after errors, paused
  /// in the background ([pause], [resume]). Reopened while the booking is
  /// `payment_pending`, it finds the payment under way and follows it.
  PayControllerProvider._({
    required PayControllerFamily super.from,
    required PaymentArgs super.argument,
  }) : super(
         retry: null,
         name: r'payControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$payControllerHash();

  @override
  String toString() {
    return r'payControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PayController create() => PayController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PayFlow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PayFlow>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PayControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$payControllerHash() => r'b1341d3740a97321b6c0bcc69c798f90fca1b09a';

/// Pays for the booking on Payment and follows a mobile money payment until
/// the payer answers: [paymentSyncEvery], backing off after errors, paused
/// in the background ([pause], [resume]). Reopened while the booking is
/// `payment_pending`, it finds the payment under way and follows it.

final class PayControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PayController,
          PayFlow,
          PayFlow,
          PayFlow,
          PaymentArgs
        > {
  PayControllerFamily._()
    : super(
        retry: null,
        name: r'payControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pays for the booking on Payment and follows a mobile money payment until
  /// the payer answers: [paymentSyncEvery], backing off after errors, paused
  /// in the background ([pause], [resume]). Reopened while the booking is
  /// `payment_pending`, it finds the payment under way and follows it.

  PayControllerProvider call(PaymentArgs args) =>
      PayControllerProvider._(argument: args, from: this);

  @override
  String toString() => r'payControllerProvider';
}

/// Pays for the booking on Payment and follows a mobile money payment until
/// the payer answers: [paymentSyncEvery], backing off after errors, paused
/// in the background ([pause], [resume]). Reopened while the booking is
/// `payment_pending`, it finds the payment under way and follows it.

abstract class _$PayController extends $Notifier<PayFlow> {
  late final _$args = ref.$arg as PaymentArgs;
  PaymentArgs get args => _$args;

  PayFlow build(PaymentArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PayFlow, PayFlow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PayFlow, PayFlow>,
              PayFlow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
