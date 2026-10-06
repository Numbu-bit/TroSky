import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

/// The header backend/app/middleware/request_context.py reads and echoes.
const String requestIdHeader = 'X-Request-ID';

/// Gives every request an `X-Request-ID`, so a failure can be found in the
/// backend logs. Retries keep the request's ID.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(requestIdHeader, () => uuidV4(_random));
    handler.next(options);
  }
}

/// A random (version 4) UUID, e.g. for `X-Request-ID` or an
/// `Idempotency-Key`.
String uuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}

/// What [AuthInterceptor] needs from the session.
abstract interface class SessionTokens {
  /// The current access token, or null when signed out.
  String? get accessToken;

  /// Exchanges the saved refresh token for a new pair and saves it.
  /// Ok with the new access token, or Err: an auth failure means the
  /// session is over; a network failure means try again later.
  Future<Result<String>> refresh();
}

/// Adds `Authorization: Bearer …` and, when the access token has expired,
/// refreshes it once and repeats the request.
///
/// Refresh tokens rotate and the backend treats a second use of one as
/// theft, revoking every session. So the refresh is single-flight: while
/// one is running, every other request that gets a 401 waits for it and
/// retries with its result.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._tokens, required this._dio});

  /// Set to true in [RequestOptions.extra] for endpoints that take no
  /// token (login, register, refresh…); they are never refreshed.
  static const String skipAuth = 'trosky.skipAuth';

  static const String _retried = 'trosky.retried';

  final SessionTokens Function() _tokens;
  final Dio Function() _dio;
  Future<Result<String>>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipAuth] != true) {
      final token = _tokens().accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sent = options.headers['Authorization'];
    if (options.extra[skipAuth] == true ||
        options.extra[_retried] == true ||
        sent is! String ||
        !_isExpiredToken(err.response)) {
      handler.next(err);
      return;
    }

    final tokens = _tokens();
    final current = tokens.accessToken;
    // A refresh that finished while this request was in flight already
    // produced a newer token: use it rather than refreshing again.
    final result = current != null && 'Bearer $current' != sent
        ? Ok(current)
        : await (_refreshing ??= tokens.refresh().whenComplete(
            () => _refreshing = null,
          ));

    switch (result) {
      case Err(:final failure):
        handler.next(err.copyWith(error: failure));
      case Ok(:final value):
        options
          ..headers['Authorization'] = 'Bearer $value'
          ..extra[_retried] = true;
        try {
          handler.resolve(await _dio().fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
    }
  }

  /// 401 `UNAUTHORIZED` is an expired or revoked access token. Other 401s,
  /// such as `INVALID_CREDENTIALS`, are not fixed by a refresh.
  static bool _isExpiredToken(Response<Object?>? response) {
    if (response?.statusCode != 401) return false;
    final body = response?.data;
    final error = body is Map ? body['error'] : null;
    return error is! Map || error['code'] == 'UNAUTHORIZED';
  }
}

/// Repeats GET requests that failed for network reasons, waiting longer
/// each time. Other methods are never repeated: a POST might have reached
/// the server.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.delays = const [Duration(seconds: 1), Duration(seconds: 3)],
  });

  final Dio Function() _dio;

  /// One entry per retry.
  final List<Duration> delays;

  static const String _attempt = 'trosky.retryAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = options.extra[_attempt] as int? ?? 0;
    if (options.method.toUpperCase() != 'GET' ||
        attempt >= delays.length ||
        !_isRetryable(err)) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(delays[attempt]);
    options.extra[_attempt] = attempt + 1;
    try {
      handler.resolve(await _dio().fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static bool _isRetryable(DioException err) => switch (err.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => const {
      502,
      503,
      504,
    }.contains(err.response?.statusCode),
    _ => false,
  };
}

/// Puts an [AppFailure] in [DioException.error], so repositories never deal
/// with raw HTTP errors.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: failureFromDioException(err)));
  }
}

/// The [AppFailure] for [err].
AppFailure failureFromDioException(DioException err) {
  final error = err.error;
  if (error is AppFailure) return error;
  return switch (err.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const TimeoutFailure(),
    DioExceptionType.badResponse => AppFailure.fromResponse(
      statusCode: err.response?.statusCode,
      body: err.response?.data,
      retryAfterHeader: err.response?.headers.value('retry-after'),
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown => const NetworkFailure(),
    DioExceptionType.cancel => const UnknownFailure(
      code: 'CANCELLED',
      message: 'The request was cancelled.',
    ),
  };
}
