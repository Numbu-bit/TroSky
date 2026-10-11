@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// Against a running backend. Skipped unless TROSKY_LIVE_API is set:
///
///     TROSKY_LIVE_API=http://localhost:8000/api/v1 \
///       flutter test test/live/live_smoke_test.dart
///
/// Codes are read where the dev backend puts them, set by TROSKY_OTP_SOURCE:
/// `docker:<container>` (console SMS provider, the default:
/// `docker:trosky-api-local`) or `mailhog:<url>` (docker-compose with
/// OTP_DELIVERY_CHANNEL=email).
///
/// It creates one test passenger with a random 024 number and a
/// trosky.smoke.*@gmail.com address. It stays within the backend's rate
/// limits for one run per IP every few minutes (login: 10 per 5 minutes).
final String? _baseUrl = Platform.environment['TROSKY_LIVE_API'];
final String _otpSource =
    Platform.environment['TROSKY_OTP_SOURCE'] ?? 'docker:trosky-api-local';

/// Keeps tokens in memory and refreshes them through the live repository.
class _Tokens implements SessionTokens {
  _Tokens(this._auth);

  final AuthRepository Function() _auth;
  String? refreshToken;

  @override
  String? accessToken;

  void save(TokenPairResponse pair) {
    accessToken = pair.accessToken;
    refreshToken = pair.refreshToken;
  }

  @override
  Future<Result<String>> refresh() async {
    final result = await _auth().refresh(
      RefreshRequest(refreshToken: refreshToken!),
    );
    return result.map((pair) {
      save(pair);
      return pair.accessToken;
    });
  }
}

void main() {
  final log = <String>[];
  void step(String line) {
    log.add(line);
    // ignore: avoid_print
    print(line);
  }

  late Dio dio;
  late LiveAuthRepository auth;
  late LiveUserRepository users;
  late _Tokens tokens;
  late String phone;
  late String email;
  const password = 'Smoke2026ok';
  final started = DateTime.now().toUtc();

  setUpAll(() {
    // Runs even when every test is skipped.
    if (_baseUrl == null) return;
    tokens = _Tokens(() => auth);
    dio = createApiClient(
      env: Env.parse(
        apiBaseUrl: _baseUrl ?? '',
        wsBaseUrl: '',
        apiMode: 'live',
      ),
      tokens: () => tokens,
    );
    auth = LiveAuthRepository(dio);
    users = LiveUserRepository(dio);
    final random = Random();
    do {
      phone = '024${List.generate(7, (_) => random.nextInt(10)).join()}';
    } while (tryNormalizePhoneNumber(phone) == null);
    email = 'trosky.smoke.${started.millisecondsSinceEpoch}@gmail.com';
  });

  /// GET /users/me with exactly [accessToken], bypassing refresh.
  Future<int?> meStatusWith(String accessToken) async {
    try {
      final response = await dio.get<Object?>(
        '/users/me',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          extra: {AuthInterceptor.skipAuth: true},
        ),
      );
      return response.statusCode;
    } on DioException catch (e) {
      return e.response?.statusCode;
    }
  }

  test(
    'register → OTP → verify → login → /users/me → refresh → logout',
    () async {
      final registered = await auth.register(
        RegisterRequest(
          phoneNumber: phone,
          email: email,
          password: password,
          fullName: 'Smoke Test',
        ),
      );
      expect(registered.failureOrNull, isNull);
      final target = registered.valueOrNull!.otpSentTo;
      step(
        '1 register: 201, user ${registered.valueOrNull!.userId}, code sent to $target',
      );

      final code = await _readOtp(target, since: started);
      step('2 OTP: read $code from $_otpSource');

      final verified = await auth.verifyOtp(
        VerifyOtpRequest(
          target: target,
          purpose: OtpPurpose.registration,
          code: code,
        ),
      );
      expect(verified.failureOrNull, isNull);
      step('3 verify-otp: ${verified.valueOrNull!.message}');

      final login = await auth.login(
        LoginRequest(identifier: phone, password: password),
      );
      expect(login.failureOrNull, isNull);
      tokens.save(login.valueOrNull!);
      step('4 login: token pair, expires_in ${login.valueOrNull!.expiresIn} s');

      final me = await users.getMe();
      expect(me.failureOrNull, isNull);
      expect(me.valueOrNull!.phoneNumber, normalizePhoneNumber(phone));
      step(
        '5 /users/me: ${me.valueOrNull!.phoneNumber}, roles ${me.valueOrNull!.roles}, '
        'phone_verified ${me.valueOrNull!.phoneVerified}',
      );

      final oldRefresh = tokens.refreshToken;
      final oldAccess = tokens.accessToken!;
      final refreshed = await tokens.refresh();
      expect(refreshed.failureOrNull, isNull);
      expect(tokens.refreshToken, isNot(oldRefresh));
      step('6 refresh: new pair, refresh token rotated');

      final out = await auth.logout();
      expect(out.failureOrNull, isNull);
      final afterLogout = await meStatusWith(tokens.accessToken!);
      step(
        '7 logout: 204; the access token afterwards gets $afterLogout '
        '(older one: ${await meStatusWith(oldAccess)})',
      );
      expect(afterLogout, 401);
    },
    skip: _baseUrl == null
        ? 'Set TROSKY_LIVE_API to run against a backend'
        : false,
  );

  // B1 (fixed in backend 0.13.0): the three safeguards keep their writes
  // although the request fails. The lockout runs last: a locked account
  // can't ask for codes.
  test(
    'B1: reusing a refresh token signs out every session',
    () async {
      // Two sessions for the same account.
      final a = (await auth.login(
        LoginRequest(identifier: phone, password: password),
      )).valueOrNull!;
      final b = (await auth.login(
        LoginRequest(identifier: phone, password: password),
      )).valueOrNull!;
      await auth.refresh(RefreshRequest(refreshToken: a.refreshToken));
      final reuse = await auth.refresh(
        RefreshRequest(refreshToken: a.refreshToken),
      );
      final bStatus = await meStatusWith(b.accessToken);
      step(
        'B1 refresh token reused: ${reuse.failureOrNull?.code}; the other '
        'session then gets $bStatus',
      );
      expect(reuse.failureOrNull?.code, 'REFRESH_TOKEN_REUSE_DETECTED');
      expect(bStatus, 401);
    },
    skip: _baseUrl == null
        ? 'Set TROSKY_LIVE_API to run against a backend'
        : false,
  );

  test(
    'B1: wrong codes stop at the attempt limit',
    () async {
      await auth.resendOtp(
        ResendOtpRequest(target: phone, purpose: OtpPurpose.login),
      );
      final codes = <String?>[];
      for (var i = 0; i < 6; i++) {
        final r = await auth.verifyOtp(
          VerifyOtpRequest(
            target: phone,
            purpose: OtpPurpose.login,
            code: '000000',
          ),
        );
        codes.add(r.failureOrNull?.code);
      }
      step('B1 6 wrong codes: ${codes.join(', ')}');
      expect(codes.last, 'OTP_ATTEMPTS_EXCEEDED');
    },
    skip: _baseUrl == null
        ? 'Set TROSKY_LIVE_API to run against a backend'
        : false,
  );

  test(
    'B1: 5 wrong passwords lock the account',
    () async {
      for (var i = 0; i < 5; i++) {
        await auth.login(
          LoginRequest(identifier: phone, password: 'Wrong2026x'),
        );
      }
      final afterWrong = await auth.login(
        LoginRequest(identifier: phone, password: password),
      );
      step(
        'B1 5 wrong passwords, then the right one: '
        '${afterWrong.isOk ? 'signed in' : afterWrong.failureOrNull!.code}',
      );
      expect(afterWrong.failureOrNull?.code, 'ACCOUNT_LOCKED');
    },
    skip: _baseUrl == null
        ? 'Set TROSKY_LIVE_API to run against a backend'
        : false,
  );

  tearDownAll(() {
    if (log.isEmpty) return;
    // ignore: avoid_print
    print('\nSMOKE TEST SUMMARY\n${log.join('\n')}');
  });
}

/// The newest code sent to [target] since [since].
Future<String> _readOtp(String target, {required DateTime since}) async {
  final codePattern = RegExp(r'code is (\d{4,10})');
  for (var attempt = 0; attempt < 20; attempt++) {
    String? code;
    if (_otpSource.startsWith('docker:')) {
      final logs = await Process.run('docker', [
        'logs',
        _otpSource.substring('docker:'.length),
        '--since',
        since.subtract(const Duration(seconds: 5)).toIso8601String(),
      ]);
      for (final line in '${logs.stdout}\n${logs.stderr}'.split('\n')) {
        if (!line.contains('_sent_console')) continue;
        final entry = jsonDecode(line) as Map<String, dynamic>;
        if (entry['to'] == target) {
          code =
              codePattern
                  .firstMatch('${entry['message'] ?? entry['body']}')
                  ?.group(1) ??
              code;
        }
      }
    } else if (_otpSource.startsWith('mailhog:')) {
      final base = _otpSource.substring('mailhog:'.length);
      final response = await Dio().get<Map<String, dynamic>>(
        '$base/api/v2/search',
        queryParameters: {'kind': 'to', 'query': target},
      );
      final items = response.data?['items'] as List? ?? const [];
      if (items.isNotEmpty) {
        final body = '${(items.first as Map)['Content']?['Body']}';
        code = codePattern.firstMatch(body)?.group(1);
      }
    }
    if (code != null) return code;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('No code for $target from $_otpSource');
}
