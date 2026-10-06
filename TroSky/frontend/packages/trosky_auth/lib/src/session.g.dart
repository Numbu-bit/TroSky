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
/// is loaded. Without a network the app still opens, signed in as the last
/// user seen ([SessionAuthenticated.offline]); [restore] checks again. Only
/// the backend rejecting the session signs the user out (decision 9).

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. Without a network the app still opens, signed in as the last
/// user seen ([SessionAuthenticated.offline]); [restore] checks again. Only
/// the backend rejecting the session signs the user out (decision 9).
final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, SessionState> {
  /// The session: restores it on app start and signs in and out.
  ///
  /// On start, a saved refresh token is exchanged for a new pair and the user
  /// is loaded. Without a network the app still opens, signed in as the last
  /// user seen ([SessionAuthenticated.offline]); [restore] checks again. Only
  /// the backend rejecting the session signs the user out (decision 9).
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

String _$sessionControllerHash() => r'64d23590ecfceb8c0fb6263df59d19211f3ee6db';

/// The session: restores it on app start and signs in and out.
///
/// On start, a saved refresh token is exchanged for a new pair and the user
/// is loaded. Without a network the app still opens, signed in as the last
/// user seen ([SessionAuthenticated.offline]); [restore] checks again. Only
/// the backend rejecting the session signs the user out (decision 9).

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
