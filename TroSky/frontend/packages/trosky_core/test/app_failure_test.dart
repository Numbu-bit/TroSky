import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

/// An error body as backend/app/core/exceptions.py writes it.
Map<String, Object?> _envelope(
  String code, {
  String message = 'msg',
  Map<String, Object?> details = const {},
}) => {
  'error': {
    'code': code,
    'message': message,
    'details': details,
    'request_id': 'req-123',
  },
};

AppFailure _map(int status, Object? body, {String? retryAfter}) =>
    AppFailure.fromResponse(
      statusCode: status,
      body: body,
      retryAfterHeader: retryAfter,
    );

void main() {
  test('every failure keeps the backend code, message and request id', () {
    final failure = _map(
      409,
      _envelope('PHONE_ALREADY_REGISTERED', message: 'Taken.'),
    );
    expect(failure, isA<ConflictFailure>());
    expect(failure.code, 'PHONE_ALREADY_REGISTERED');
    expect(failure.message, 'Taken.');
    expect(failure.requestId, 'req-123');
    expect(failure.statusCode, 409);
  });

  test('maps each status to its failure type', () {
    final cases = <(int, String, Type)>[
      (401, 'INVALID_CREDENTIALS', UnauthorizedFailure),
      (401, 'UNAUTHORIZED', UnauthorizedFailure),
      (401, 'REFRESH_TOKEN_REUSE_DETECTED', UnauthorizedFailure),
      (403, 'ACCOUNT_NOT_VERIFIED', ForbiddenFailure),
      (404, 'NOT_FOUND', NotFoundFailure),
      (404, 'OTP_NOT_FOUND', NotFoundFailure),
      (400, 'OTP_INVALID', UnknownFailure),
      (400, 'OTP_EXPIRED', UnknownFailure),
      (409, 'EMAIL_ALREADY_REGISTERED', ConflictFailure),
      (429, 'OTP_ATTEMPTS_EXCEEDED', RateLimitedFailure),
      (500, 'INTERNAL_SERVER_ERROR', ServerFailure),
      (502, 'PROVIDER_ERROR', ServerFailure),
    ];
    for (final (status, code, type) in cases) {
      final failure = _map(status, _envelope(code));
      expect(failure.runtimeType, type, reason: code);
      expect(failure.code, code);
    }
  });

  test('ACCOUNT_LOCKED carries locked_until', () {
    final failure = _map(
      423,
      _envelope(
        'ACCOUNT_LOCKED',
        details: {'locked_until': '2026-10-01T10:15:00+00:00'},
      ),
    );
    expect(failure, isA<AccountLockedFailure>());
    expect(
      (failure as AccountLockedFailure).lockedUntil,
      DateTime.utc(2026, 10, 1, 10, 15),
    );
  });

  test('ACCOUNT_SUSPENDED is its own type, not just forbidden', () {
    final failure = _map(
      403,
      _envelope('ACCOUNT_SUSPENDED', details: {'reason': 'Fraud review'}),
    );
    expect(failure, isA<AccountSuspendedFailure>());
    expect((failure as AccountSuspendedFailure).reason, 'Fraud review');
  });

  test('pydantic errors become field errors', () {
    final failure = _map(
      422,
      _envelope(
        'VALIDATION_ERROR',
        details: {
          'errors': [
            {
              'type': 'value_error',
              'loc': ['body', 'phone_number'],
              'msg': "Value error, '0241' is not a valid phone number",
            },
            {
              'type': 'string_too_short',
              'loc': ['body', 'full_name'],
              'msg': 'String should have at least 2 characters',
            },
            {
              'type': 'enum',
              'loc': ['body', 'device', 'platform'],
              'msg': "Input should be 'ios', 'android' or 'web'",
            },
          ],
        },
      ),
    );
    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).fieldErrors, {
      'phone_number': ["Value error, '0241' is not a valid phone number"],
      'full_name': ['String should have at least 2 characters'],
      'device.platform': ["Input should be 'ios', 'android' or 'web'"],
    });
  });

  test('a password policy 409 is a validation failure on password', () {
    final failure = _map(
      409,
      _envelope(
        'PASSWORD_POLICY_VIOLATION',
        details: {
          'violations': [
            'Password must contain at least one uppercase letter.',
            'Password must contain at least one digit.',
          ],
        },
      ),
    );
    expect(failure, isA<ValidationFailure>());
    expect(failure.code, 'PASSWORD_POLICY_VIOLATION');
    expect(
      (failure as ValidationFailure).fieldErrors['password'],
      hasLength(2),
    );
  });

  test('email domain errors point at the email field', () {
    for (final code in ['EMAIL_REQUIRED', 'EMAIL_DOMAIN_NOT_ALLOWED']) {
      final failure = _map(
        422,
        _envelope(
          code,
          message: 'Use @gmail.com.',
          details: {
            'allowed_domains': ['gmail.com', 'googlemail.com'],
          },
        ),
      );
      expect((failure as ValidationFailure).fieldErrors, {
        'email': ['Use @gmail.com.'],
      }, reason: code);
    }
  });

  group('retryAfter', () {
    test('from the Retry-After header first', () {
      final failure = _map(
        429,
        _envelope('RATE_LIMIT_EXCEEDED', details: {'cooldown_seconds': 60}),
        retryAfter: '12',
      );
      expect(
        (failure as RateLimitedFailure).retryAfter,
        const Duration(seconds: 12),
      );
    });

    test('then the OTP cooldown', () {
      final failure = _map(
        429,
        _envelope('RATE_LIMIT_EXCEEDED', details: {'cooldown_seconds': 60}),
      );
      expect(
        (failure as RateLimitedFailure).retryAfter,
        const Duration(seconds: 60),
      );
    });

    test('then the rate-limit window', () {
      final failure = _map(
        429,
        _envelope(
          'RATE_LIMIT_EXCEEDED',
          details: {'rule': 'auth:login', 'limit': 10, 'window_seconds': 300},
        ),
      );
      expect(
        (failure as RateLimitedFailure).retryAfter,
        const Duration(seconds: 300),
      );
    });

    test('unknown when the server says nothing', () {
      final failure = _map(429, _envelope('OTP_ATTEMPTS_EXCEEDED'));
      expect((failure as RateLimitedFailure).retryAfter, isNull);
    });
  });

  test('a body without the envelope still maps by status', () {
    final failure = _map(502, '<html>Bad Gateway</html>');
    expect(failure, isA<ServerFailure>());
    expect(failure.code, 'INTERNAL_SERVER_ERROR');
    expect(failure.requestId, isNull);
  });

  test('client-side failures have their own codes', () {
    expect(const NetworkFailure().code, AppFailure.networkCode);
    expect(const TimeoutFailure().code, AppFailure.timeoutCode);
  });

  test('Result helpers', () async {
    const Result<int> ok = Ok(2);
    const Result<int> err = Err(NetworkFailure());
    expect(ok.map((v) => v * 2).valueOrNull, 4);
    expect(err.map((v) => v * 2).failureOrNull, isA<NetworkFailure>());
    expect((await ok.then((v) async => Ok('$v'))).valueOrNull, '2');
    expect((await err.then((v) async => Ok('$v'))).isOk, isFalse);
  });
}
