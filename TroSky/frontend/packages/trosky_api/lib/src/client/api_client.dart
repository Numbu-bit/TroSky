import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import 'interceptors.dart';
import 'server_wake.dart';

/// Timeouts for slow mobile networks: allow a slow connection to open, and
/// a slow response to arrive, without hanging forever.
const Duration connectTimeout = Duration(seconds: 15);
const Duration sendTimeout = Duration(seconds: 30);
const Duration receiveTimeout = Duration(seconds: 30);

/// The HTTP client for the backend at [Env.apiBaseUrl].
///
/// With a [wake], requests wait until the server is up (see [ServerWake]).
/// Every request gets an `X-Request-ID`. Requests carry the access token
/// from [tokens] unless marked [AuthInterceptor.skipAuth], and an expired
/// token is refreshed once for all waiting requests. GETs are retried on
/// network errors. Every error carries an [AppFailure].
Dio createApiClient({
  required Env env,
  required SessionTokens Function() tokens,
  ServerWake? wake,
  List<Duration> retryDelays = const [
    Duration(seconds: 1),
    Duration(seconds: 3),
  ],
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.addAll([
    if (wake != null) ServerWakeInterceptor(wake),
    RequestIdInterceptor(),
    AuthInterceptor(tokens: tokens, dio: () => dio),
    RetryInterceptor(dio: () => dio, delays: retryDelays),
    ErrorInterceptor(),
  ]);
  return dio;
}

/// Options for an endpoint that takes no access token.
Options publicEndpoint() => Options(extra: {AuthInterceptor.skipAuth: true});

/// Runs [send] and turns the response into an [Ok] via [parse], or the
/// error into an [Err].
Future<Result<T>> apiCall<T>(
  Future<Response<Object?>> Function() send,
  T Function(Object? data) parse,
) async {
  final Response<Object?> response;
  try {
    response = await send();
  } on DioException catch (err) {
    return Err(failureFromDioException(err));
  }
  try {
    return Ok(parse(response.data));
  } on Object catch (error) {
    return Err(
      UnknownFailure(
        code: 'INVALID_RESPONSE',
        message: 'Unexpected response from the server: $error',
        statusCode: response.statusCode,
      ),
    );
  }
}

/// [data] as a JSON object.
Map<String, dynamic> jsonObject(Object? data) =>
    (data as Map).cast<String, dynamic>();
