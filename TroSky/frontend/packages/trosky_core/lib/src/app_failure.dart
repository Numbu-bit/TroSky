/// Why a call failed, mapped from the backend's error envelope
/// (backend/app/core/exceptions.py):
///
/// ```json
/// {"error": {"code": "...", "message": "...", "details": {}, "request_id": "..."}}
/// ```
///
/// Every failure keeps the backend's [code] (e.g. `PHONE_ALREADY_REGISTERED`,
/// `OTP_INVALID`) so screens can react to the exact case. Failures that
/// never reached the backend use the client codes [networkCode] and
/// [timeoutCode].
sealed class AppFailure {
  const AppFailure({
    required this.code,
    required this.message,
    this.details = const {},
    this.requestId,
    this.statusCode,
  });

  /// Maps an error response. [body] is the decoded JSON (or anything else
  /// the server sent); [retryAfterHeader] is the `Retry-After` header.
  factory AppFailure.fromResponse({
    required int? statusCode,
    Object? body,
    String? retryAfterHeader,
  }) {
    final envelope = _Envelope.parse(body);
    final code = envelope?.code ?? _codeForStatus(statusCode);
    final message = envelope?.message ?? 'Request failed ($statusCode).';
    final details = envelope?.details ?? const <String, Object?>{};
    final requestId = envelope?.requestId;

    switch (code) {
      case 'ACCOUNT_LOCKED':
        return AccountLockedFailure(
          code: code,
          message: message,
          details: details,
          requestId: requestId,
          statusCode: statusCode,
          lockedUntil: DateTime.tryParse('${details['locked_until']}'),
        );
      case 'ACCOUNT_SUSPENDED':
        return AccountSuspendedFailure(
          code: code,
          message: message,
          details: details,
          requestId: requestId,
          statusCode: statusCode,
          reason: details['reason'] as String?,
        );
      // A 409 in the backend, but it is about one field.
      case 'PASSWORD_POLICY_VIOLATION':
        return ValidationFailure(
          code: code,
          message: message,
          details: details,
          requestId: requestId,
          statusCode: statusCode,
          fieldErrors: {
            'password': [
              for (final violation
                  in details['violations'] as List? ?? const [])
                '$violation',
            ],
          },
        );
      case 'EMAIL_REQUIRED' || 'EMAIL_DOMAIN_NOT_ALLOWED':
        return ValidationFailure(
          code: code,
          message: message,
          details: details,
          requestId: requestId,
          statusCode: statusCode,
          fieldErrors: {
            'email': [message],
          },
        );
    }

    return switch (statusCode) {
      401 => UnauthorizedFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
      403 => ForbiddenFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
      404 => NotFoundFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
      409 => ConflictFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
      422 => ValidationFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
        fieldErrors: _fieldErrors(details),
      ),
      429 => RateLimitedFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
        retryAfter: _retryAfter(retryAfterHeader, details),
      ),
      final status? when status >= 500 => ServerFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
      _ => UnknownFailure(
        code: code,
        message: message,
        details: details,
        requestId: requestId,
        statusCode: statusCode,
      ),
    };
  }

  /// Client code: the request never got a response (no connection, DNS,
  /// connection refused).
  static const String networkCode = 'NETWORK_ERROR';

  /// Client code: the request took longer than the client allows.
  static const String timeoutCode = 'TIMEOUT';

  /// The backend's error code, or [networkCode] / [timeoutCode].
  final String code;

  /// The backend's message. For logs, not for screens: screens show their
  /// own localized text chosen from [code].
  final String message;

  final Map<String, Object?> details;

  /// The backend's `request_id`, to quote when reporting a problem.
  final String? requestId;

  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType($code, status: $statusCode, request: $requestId)';
}

/// No response: no connection, DNS failure or connection refused.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.code = AppFailure.networkCode,
    super.message = 'No connection to the server.',
  });
}

/// The server took too long to answer.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.code = AppFailure.timeoutCode,
    super.message = 'The server took too long to respond.',
  });
}

/// 401: no, invalid or expired credentials (`UNAUTHORIZED`,
/// `INVALID_CREDENTIALS`, `REFRESH_TOKEN_REUSE_DETECTED`).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

/// 403: not allowed (`FORBIDDEN`, `ACCOUNT_NOT_VERIFIED`).
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

/// 404 (`NOT_FOUND`, `OTP_NOT_FOUND`).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

/// The submitted data is invalid. [fieldErrors] maps a request field
/// (`phone_number`, `email`, `password`, `device.platform`) to its messages.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
    this.fieldErrors = const {},
  });

  final Map<String, List<String>> fieldErrors;
}

/// 409: clashes with existing data (`PHONE_ALREADY_REGISTERED`,
/// `EMAIL_ALREADY_REGISTERED`).
final class ConflictFailure extends AppFailure {
  const ConflictFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

/// 429: too many requests (`RATE_LIMIT_EXCEEDED`, `OTP_ATTEMPTS_EXCEEDED`).
/// [retryAfter] is when to try again, if the server said: the OTP resend
/// cooldown, or at most the rate-limit window.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
    this.retryAfter,
  });

  final Duration? retryAfter;
}

/// 423 `ACCOUNT_LOCKED`: too many wrong passwords.
final class AccountLockedFailure extends AppFailure {
  const AccountLockedFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
    this.lockedUntil,
  });

  final DateTime? lockedUntil;
}

/// 403 `ACCOUNT_SUSPENDED`.
final class AccountSuspendedFailure extends AppFailure {
  const AccountSuspendedFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
    this.reason,
  });

  final String? reason;
}

/// 5xx.
final class ServerFailure extends AppFailure {
  const ServerFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

/// Anything else.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    required super.code,
    required super.message,
    super.details,
    super.requestId,
    super.statusCode,
  });
}

class _Envelope {
  const _Envelope(this.code, this.message, this.details, this.requestId);

  static _Envelope? parse(Object? body) {
    if (body is! Map || body['error'] is! Map) return null;
    final error = body['error'] as Map;
    final code = error['code'];
    if (code is! String) return null;
    final details = error['details'];
    return _Envelope(
      code,
      error['message'] is String ? error['message'] as String : code,
      details is Map ? details.cast<String, Object?>() : const {},
      error['request_id'] as String?,
    );
  }

  final String code;
  final String message;
  final Map<String, Object?> details;
  final String? requestId;
}

/// The code the backend would use for a bare status (see
/// `handle_http_exception`).
String _codeForStatus(int? status) => switch (status) {
  401 => 'UNAUTHORIZED',
  403 => 'FORBIDDEN',
  404 => 'NOT_FOUND',
  422 => 'VALIDATION_ERROR',
  429 => 'RATE_LIMIT_EXCEEDED',
  final s? when s >= 500 => 'INTERNAL_SERVER_ERROR',
  _ => 'HTTP_ERROR',
};

/// Pydantic's `details.errors`: each has `loc` (e.g. `["body",
/// "phone_number"]`) and `msg`.
Map<String, List<String>> _fieldErrors(Map<String, Object?> details) {
  final errors = details['errors'];
  if (errors is! List) return const {};
  final result = <String, List<String>>{};
  for (final error in errors.whereType<Map<Object?, Object?>>()) {
    final loc = [for (final part in error['loc'] as List? ?? const []) '$part'];
    if (loc.isNotEmpty &&
        const {'body', 'query', 'path', 'header'}.contains(loc.first)) {
      loc.removeAt(0);
    }
    final field = loc.isEmpty ? 'body' : loc.join('.');
    (result[field] ??= []).add('${error['msg']}');
  }
  return result;
}

Duration? _retryAfter(String? header, Map<String, Object?> details) {
  final seconds =
      int.tryParse(header ?? '') ??
      details['cooldown_seconds'] ??
      details['window_seconds'];
  return seconds is int ? Duration(seconds: seconds) : null;
}
