// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. If the network is down the state is an error (the saved
/// session is kept); [restore] tries again.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. If the network is down the state is an error (the saved
/// session is kept); [restore] tries again.
final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, SessionState> {
  /// The session: restores it on app start and signs in and out.
  ///
  /// On start, a saved refresh token is exchanged for a new pair and the user
  /// is loaded. If the network is down the state is an error (the saved
  /// session is kept); [restore] tries again.
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noRetry,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();
}

String _$sessionControllerHash() => r'7c12804462a55a0426f9c65500e7d8f0b568b87b';

/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. If the network is down the state is an error (the saved
/// session is kept); [restore] tries again.

abstract class _$SessionController extends $AsyncNotifier<SessionState> {
  FutureOr<SessionState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SessionState>, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SessionState>, SessionState>,
              AsyncValue<SessionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
