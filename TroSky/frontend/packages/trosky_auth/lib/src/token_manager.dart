import 'dart:async';

import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

import 'token_storage.dart';

/// Holds the session's tokens: the access token in memory, the refresh
/// token in [RefreshTokenStore].
///
/// The backend rotates refresh tokens and treats a second use of one as
/// theft, revoking every session of the account. So a new pair is saved
/// before its access token is used, refreshes are single-flight, and a
/// refresh token is deleted the moment the session ends.
class TokenManager implements SessionTokens {
  TokenManager({
    required this._store,
    required Future<Result<TokenPairResponse>> Function(String refreshToken)
    refresh,
  }) : _refreshCall = refresh;

  final RefreshTokenStore _store;
  final Future<Result<TokenPairResponse>> Function(String) _refreshCall;
  final StreamController<AppFailure> _ended = StreamController.broadcast();
  String? _accessToken;
  Future<Result<String>>? _refreshing;

  @override
  String? get accessToken => _accessToken;

  /// Fires when a refresh shows the session is over (revoked, reused,
  /// suspended…), after the tokens have been deleted.
  Stream<AppFailure> get sessionEnded => _ended.stream;

  Future<bool> get hasSavedSession async => await _store.read() != null;

  /// Saves a pair from login or refresh: the refresh token is persisted
  /// first, so it survives a crash before the access token is used.
  Future<void> save(TokenPairResponse pair) async {
    await _store.write(pair.refreshToken);
    _accessToken = pair.accessToken;
  }

  /// Forgets both tokens.
  Future<void> clear() async {
    _accessToken = null;
    await _store.delete();
  }

  /// Deletes the saved refresh token but keeps the access token in memory,
  /// for one last authenticated call such as logout.
  Future<void> forgetRefreshToken() => _store.delete();

  @override
  Future<Result<String>> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Result<String>> _refresh() async {
    final token = await _store.read();
    if (token == null) {
      _accessToken = null;
      return const Err(
        UnauthorizedFailure(code: 'NO_SESSION', message: 'No saved session.'),
      );
    }
    final result = await _refreshCall(token);
    switch (result) {
      case Ok(:final value):
        await save(value);
        return Ok(value.accessToken);
      case Err(:final failure):
        if (endsSession(failure)) {
          await clear();
          _ended.add(failure);
        }
        return Err(failure);
    }
  }

  /// Whether [failure] from a refresh means the session cannot continue.
  /// Network and server trouble do not: the saved token is kept to try
  /// again.
  static bool endsSession(AppFailure failure) => switch (failure) {
    UnauthorizedFailure() ||
    ForbiddenFailure() ||
    AccountSuspendedFailure() ||
    AccountLockedFailure() ||
    ValidationFailure() => true,
    _ => false,
  };

  Future<void> dispose() => _ended.close();
}
