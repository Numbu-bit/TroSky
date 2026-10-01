import 'package:trosky_core/trosky_core.dart';

import '../dto/auth_dto.dart';
import '../dto/user_dto.dart';

/// An in-memory stand-in for the backend's auth and user endpoints, for
/// `API_MODE=mock` and tests.
///
/// It follows backend/app/services/auth_service.py and otp_service.py rule
/// for rule, with the same error codes, statuses, messages and details, and
/// the backend's default settings (backend/app/core/config.py).
///
/// Fixed data:
/// * Every code is [otpCode] (`123456`).
/// * `0241234567` is an existing passenger and `0201234567` an existing
///   driver, both verified, both with the password [seedPassword].
/// * Any other phone number is a new user.
class MockBackend {
  MockBackend({DateTime Function()? clock, this.codesByEmail = false})
    : _now = clock ?? DateTime.now {
    _seed();
  }

  /// The code every OTP has.
  static const String otpCode = '123456';

  /// The password of the seeded accounts.
  static const String seedPassword = 'TroSky2026';

  static const String passengerPhone = '+233241234567';
  static const String driverPhone = '+233201234567';

  // Backend defaults.
  static const Duration otpTtl = Duration(seconds: 300);
  static const Duration otpCooldown = Duration(seconds: 60);
  static const int otpMaxAttempts = 5;
  static const int loginMaxFailedAttempts = 5;
  static const Duration loginLockout = Duration(seconds: 900);
  static const int accessTokenTtlSeconds = 900;
  static const Duration refreshTokenTtl = Duration(days: 30);
  static const Set<String> registrationEmailDomains = {
    'gmail.com',
    'googlemail.com',
  };

  /// `OTP_DELIVERY_CHANNEL=email`: codes go to the account's email address,
  /// as in the docker-compose setup. The default sends them by SMS.
  final bool codesByEmail;

  final DateTime Function() _now;
  final List<_User> _users = [];
  final List<_Challenge> _challenges = [];
  final Map<String, DateTime> _cooldowns = {};
  final Map<String, _Session> _sessions = {};
  final Map<String, _RefreshToken> _refreshTokens = {};
  final Map<String, _AccessToken> _accessTokens = {};
  int _counter = 0;

  /// Codes "sent" so far, newest last: what an SMS or email would carry.
  final List<SentCode> outbox = [];

  void _seed() {
    final created = DateTime.utc(2026, 7, 1, 8);
    _users
      ..add(
        _User(
          id: '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41',
          phone: passengerPhone,
          email: 'ama.mensah@gmail.com',
          password: seedPassword,
          fullName: 'Ama Mensah',
          roles: ['passenger'],
          createdAt: created,
        )..phoneVerifiedAt = created,
      )
      ..add(
        _User(
          id: '8c4d2a91-3b7e-4f60-a2d5-9e1b6c7f0a28',
          phone: driverPhone,
          email: 'kofi.boateng@gmail.com',
          password: seedPassword,
          fullName: 'Kofi Boateng',
          roles: ['driver'],
          createdAt: created,
        )..phoneVerifiedAt = created,
      );
  }

  // ---------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------

  Result<RegisterResponse> register(RegisterRequest request) {
    final phone = tryNormalizePhoneNumber(request.phoneNumber);
    final invalid = [
      if (phone == null)
        _fieldError(
          'phone_number',
          "Value error, '${request.phoneNumber}' is not a valid phone number",
        ),
      if (request.email != null && !_looksLikeEmail(request.email!))
        _fieldError(
          'email',
          'value is not a valid email address: An email address must have '
              'an @-sign.',
        ),
      if (request.password.length < 8)
        _fieldError('password', 'String should have at least 8 characters'),
      if (request.fullName.length < 2)
        _fieldError('full_name', 'String should have at least 2 characters'),
    ];
    if (invalid.isNotEmpty) return _validationError(invalid);

    final violations = _passwordViolations(request.password);
    if (violations.isNotEmpty) {
      return _error(
        409,
        'PASSWORD_POLICY_VIOLATION',
        'Password does not meet the required policy.',
        {'violations': violations},
      );
    }

    final email = request.email?.trim().toLowerCase();
    final domains = (registrationEmailDomains.toList()..sort())
        .map((d) => '@$d')
        .join(' or ');
    if (email == null) {
      return _error(
        422,
        'EMAIL_REQUIRED',
        'An email address ending in $domains is required to register.',
        {'allowed_domains': registrationEmailDomains.toList()..sort()},
      );
    }
    if (!registrationEmailDomains.contains(email.split('@').last)) {
      return _error(
        422,
        'EMAIL_DOMAIN_NOT_ALLOWED',
        'Please register with an email address ending in $domains.',
        {'allowed_domains': registrationEmailDomains.toList()..sort()},
      );
    }
    if (_byPhone(phone!) != null) {
      return _error(
        409,
        'PHONE_ALREADY_REGISTERED',
        'An account with this phone number already exists.',
      );
    }
    if (_byEmail(email) != null) {
      return _error(
        409,
        'EMAIL_ALREADY_REGISTERED',
        'An account with this email already exists.',
      );
    }

    final user = _User(
      id: _uuid(),
      phone: phone,
      email: email,
      password: request.password,
      fullName: request.fullName,
      roles: [_roleSlug(request.role)],
      createdAt: _now().toUtc(),
      preferredLanguage: request.preferredLanguage,
    );
    _users.add(user);

    // If the code can't be issued, the backend's transaction rolls back and
    // no account is left behind.
    if (codesByEmail) {
      final failed = _issue(email, OtpChannel.email, OtpPurpose.registration);
      if (failed != null) {
        _users.remove(user);
        return Err(failed);
      }
      return Ok(
        RegisterResponse(
          userId: user.id,
          phoneNumber: phone,
          otpSentTo: email,
          message:
              'Registration successful. Verify your email address with the '
              'code sent.',
        ),
      );
    }
    final failed = _issue(phone, OtpChannel.sms, OtpPurpose.registration);
    if (failed != null) {
      _users.remove(user);
      return Err(failed);
    }
    // Best effort in the backend; a cooldown clash is ignored there too.
    if (_cooldownRunning(email, OtpPurpose.emailVerification) == null) {
      _issue(email, OtpChannel.email, OtpPurpose.emailVerification);
    }
    return Ok(
      RegisterResponse(
        userId: user.id,
        phoneNumber: phone,
        otpSentTo: phone,
        message:
            'Registration successful. Verify your phone number with the OTP '
            'sent.',
      ),
    );
  }

  Result<MessageResponse> verifyOtp(VerifyOtpRequest request) {
    final invalid = _codeFieldErrors(request.code);
    if (invalid != null) return _validationError(invalid);
    final target = _normalizeTarget(request.target);
    final verified = _verify(target, request.purpose, request.code);
    if (verified case Err(:final failure)) return Err(failure);
    final challenge = verified.valueOrNull!;

    final bool provesEmail;
    switch (request.purpose) {
      case OtpPurpose.registration:
        provesEmail = challenge.channel == OtpChannel.email;
      case OtpPurpose.phoneVerification || OtpPurpose.emailVerification:
        provesEmail = request.purpose == OtpPurpose.emailVerification;
      case OtpPurpose.login || OtpPurpose.passwordReset:
        return const Ok(MessageResponse(message: 'OTP verified successfully.'));
    }
    final user = _resolve(target);
    if (user == null) {
      return _error(
        404,
        'NOT_FOUND',
        'No account found for this phone number or email.',
      );
    }
    if (provesEmail) {
      user.emailVerifiedAt = _now().toUtc();
    } else {
      user.phoneVerifiedAt = _now().toUtc();
    }
    return const Ok(MessageResponse(message: 'OTP verified successfully.'));
  }

  Result<MessageResponse> resendOtp(ResendOtpRequest request) {
    const sent = MessageResponse(
      message: 'A new verification code has been sent.',
    );
    final target = _normalizeTarget(request.target);
    final user = _resolve(request.target);
    if (user == null) {
      // Nothing is sent, but the answer and the cooldown are the same.
      final held = _holdCooldown(target, request.purpose);
      return held == null ? const Ok(sent) : Err(held);
    }
    final channel = switch (request.purpose) {
      OtpPurpose.emailVerification => OtpChannel.email,
      OtpPurpose.phoneVerification => OtpChannel.sms,
      _ => codesByEmail ? OtpChannel.email : request.channel,
    };
    final deliverTo = channel == OtpChannel.email ? user.email : user.phone;
    if (deliverTo == null) {
      final held = _holdCooldown(target, request.purpose);
      return held == null ? const Ok(sent) : Err(held);
    }
    final issued = _issue(
      target,
      channel,
      request.purpose,
      deliverTo: deliverTo,
    );
    return issued == null ? const Ok(sent) : Err(issued);
  }

  Result<TokenPairResponse> login(LoginRequest request) {
    if (request.password.isEmpty) {
      return _validationError([
        _fieldError('password', 'String should have at least 1 character'),
      ]);
    }
    final user = _resolve(request.identifier);
    if (user == null) return _invalidCredentials();
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    if (request.password != user.password) {
      user.failedLogins++;
      if (user.failedLogins >= loginMaxFailedAttempts) {
        user.lockedUntil = _now().toUtc().add(loginLockout);
      }
      return _invalidCredentials();
    }
    if (!user.isVerified) {
      return _error(
        403,
        'ACCOUNT_NOT_VERIFIED',
        'Verify your account with the code sent to you before logging in.',
        {
          'target': codesByEmail && user.email != null
              ? user.email
              : user.phone,
          'purpose': 'registration',
        },
      );
    }
    user
      ..failedLogins = 0
      ..lockedUntil = null;
    return Ok(_issueTokens(user));
  }

  Result<TokenPairResponse> otpLogin(OtpLoginRequest request) {
    final invalid = _codeFieldErrors(request.code);
    if (invalid != null) return _validationError(invalid);
    final user = _resolve(request.target);
    if (user == null) {
      return _error(404, 'NOT_FOUND', 'No account found for this identifier.');
    }
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    final verified = _verify(
      _normalizeTarget(request.target),
      OtpPurpose.login,
      request.code,
    );
    if (verified case Err(:final failure)) return Err(failure);
    // The code reached the user, which proves where it went.
    if (verified.valueOrNull!.channel == OtpChannel.email) {
      user.emailVerifiedAt ??= _now().toUtc();
    } else {
      user.phoneVerifiedAt ??= _now().toUtc();
    }
    user
      ..failedLogins = 0
      ..lockedUntil = null;
    return Ok(_issueTokens(user));
  }

  Result<TokenPairResponse> refresh(RefreshRequest request) {
    if (request.refreshToken.length < 20) {
      return _validationError([
        _fieldError(
          'refresh_token',
          'String should have at least 20 characters',
        ),
      ]);
    }
    final stored = _refreshTokens[request.refreshToken];
    if (stored == null) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired refresh token.');
    }
    if (stored.revoked) {
      // A rotated token used again: assume it was stolen.
      _revokeAllSessions(stored.userId);
      return _error(
        401,
        'REFRESH_TOKEN_REUSE_DETECTED',
        'This refresh token has already been used. All sessions have been '
            'revoked.',
      );
    }
    if (!stored.expiresAt.isAfter(_now())) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired refresh token.');
    }
    final session = _sessions[stored.sessionId];
    if (session == null || session.revoked) {
      return _error(401, 'UNAUTHORIZED', 'This session has been revoked.');
    }
    final user = _users.firstWhere((u) => u.id == stored.userId);
    final blocked = _loginBlocked(user);
    if (blocked != null) return Err(blocked);

    final pair = _tokensForSession(user, session.id);
    stored.revoked = true;
    return Ok(pair);
  }

  Result<void> logout(String? accessToken) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    _revokeSession(auth.valueOrNull!.sessionId);
    return const Ok(null);
  }

  Result<UserResponse> getMe(String? accessToken) {
    final auth = _authenticate(accessToken);
    if (auth case Err(:final failure)) return Err(failure);
    final user = _users.firstWhere((u) => u.id == auth.valueOrNull!.userId);
    return Ok(user.toResponse());
  }

  // ---------------------------------------------------------------------
  // Test controls
  // ---------------------------------------------------------------------

  /// Suspends the account with [phone], as an admin would.
  void suspend(String phone, {String reason = 'Under review'}) =>
      _byPhone(normalizePhoneNumber(phone))!.suspendedReason = reason;

  /// Makes every access token expire, as 15 minutes passing would.
  void expireAccessTokens() {
    for (final token in _accessTokens.values) {
      token.expiresAt = _now().subtract(const Duration(seconds: 1));
    }
  }

  /// How many sessions of [phone] are still active.
  int activeSessions(String phone) {
    final user = _byPhone(normalizePhoneNumber(phone))!;
    return _sessions.values
        .where((s) => s.userId == user.id && !s.revoked)
        .length;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  _User? _byPhone(String e164) =>
      _users.where((u) => u.phone == e164).firstOrNull;

  _User? _byEmail(String email) =>
      _users.where((u) => u.email == email).firstOrNull;

  /// `_resolve_user`: a phone number in any form, else an email address.
  _User? _resolve(String identifier) {
    final phone = tryNormalizePhoneNumber(identifier);
    if (phone != null) {
      final user = _byPhone(phone);
      if (user != null) return user;
    }
    return _byEmail(identifier.trim().toLowerCase());
  }

  /// `normalize_otp_target`.
  String _normalizeTarget(String target) {
    if (target.contains('@')) return target.trim().toLowerCase();
    return tryNormalizePhoneNumber(target) ?? target.trim();
  }

  AppFailure? _loginBlocked(_User user) {
    if (user.suspendedReason != null) {
      return _failure(
        403,
        'ACCOUNT_SUSPENDED',
        'This account has been suspended.',
        {'reason': user.suspendedReason},
      );
    }
    final until = user.lockedUntil;
    if (until != null && until.isAfter(_now())) {
      return _failure(
        423,
        'ACCOUNT_LOCKED',
        'This account is temporarily locked due to repeated failed attempts.',
        {'locked_until': until.toIso8601String()},
      );
    }
    return null;
  }

  Err<T> _invalidCredentials<T>() => _error(
    401,
    'INVALID_CREDENTIALS',
    'The provided credentials are incorrect.',
  );

  String _cooldownKey(String target, OtpPurpose purpose) =>
      '${purpose.name}:$target';

  DateTime? _cooldownRunning(String target, OtpPurpose purpose) {
    final until = _cooldowns[_cooldownKey(target, purpose)];
    return until != null && until.isAfter(_now()) ? until : null;
  }

  /// `hold_cooldown`: starts the cooldown, or fails while it runs.
  AppFailure? _holdCooldown(String target, OtpPurpose purpose) {
    if (_cooldownRunning(target, purpose) != null) {
      return _failure(
        429,
        'RATE_LIMIT_EXCEEDED',
        'Please wait before requesting another code.',
        {'cooldown_seconds': otpCooldown.inSeconds},
      );
    }
    _cooldowns[_cooldownKey(target, purpose)] = _now().add(otpCooldown);
    return null;
  }

  /// `request_otp`: a new code keyed on [target], sent to [deliverTo].
  AppFailure? _issue(
    String target,
    OtpChannel channel,
    OtpPurpose purpose, {
    String? deliverTo,
  }) {
    final held = _holdCooldown(target, purpose);
    if (held != null) return held;
    _challenges.add(
      _Challenge(
        target: target,
        purpose: purpose,
        channel: channel,
        expiresAt: _now().add(otpTtl),
      ),
    );
    outbox.add(
      SentCode(
        to: deliverTo ?? target,
        channel: channel,
        purpose: purpose,
        code: otpCode,
      ),
    );
    return null;
  }

  /// `verify_otp` in otp_service.py.
  Result<_Challenge> _verify(String target, OtpPurpose purpose, String code) {
    final challenge = _challenges.reversed
        .where((c) => c.target == target && c.purpose == purpose && !c.used)
        .firstOrNull;
    if (challenge == null) {
      return _error(
        404,
        'OTP_NOT_FOUND',
        'No active OTP challenge was found for this target.',
      );
    }
    if (!challenge.expiresAt.isAfter(_now())) {
      return _error(400, 'OTP_EXPIRED', 'The OTP code has expired.');
    }
    if (challenge.attempts >= otpMaxAttempts) {
      return _error(
        429,
        'OTP_ATTEMPTS_EXCEEDED',
        'Too many incorrect OTP attempts. Request a new code.',
      );
    }
    if (code != otpCode) {
      challenge.attempts++;
      return _error(400, 'OTP_INVALID', 'The OTP code is incorrect.');
    }
    challenge.used = true;
    return Ok(challenge);
  }

  TokenPairResponse _issueTokens(_User user) {
    final session = _Session(id: _uuid(), userId: user.id);
    _sessions[session.id] = session;
    return _tokensForSession(user, session.id);
  }

  TokenPairResponse _tokensForSession(_User user, String sessionId) {
    final access = 'mock.access.${_uuid()}';
    final refresh = 'mock.refresh.${_uuid()}';
    _accessTokens[access] = _AccessToken(
      userId: user.id,
      sessionId: sessionId,
      expiresAt: _now().add(const Duration(seconds: accessTokenTtlSeconds)),
    );
    _refreshTokens[refresh] = _RefreshToken(
      userId: user.id,
      sessionId: sessionId,
      expiresAt: _now().add(refreshTokenTtl),
    );
    return TokenPairResponse(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: accessTokenTtlSeconds,
      sessionId: sessionId,
    );
  }

  /// `resolve_principal`.
  Result<_AccessToken> _authenticate(String? accessToken) {
    if (accessToken == null) {
      return _error(401, 'UNAUTHORIZED', 'Authentication is required.');
    }
    final token = _accessTokens[accessToken];
    if (token == null || !token.expiresAt.isAfter(_now())) {
      return _error(401, 'UNAUTHORIZED', 'Invalid or expired access token.');
    }
    if (_sessions[token.sessionId]?.revoked ?? true) {
      return _error(401, 'UNAUTHORIZED', 'This session has been revoked.');
    }
    final user = _users.firstWhere((u) => u.id == token.userId);
    if (user.suspendedReason != null) {
      return _error(
        403,
        'ACCOUNT_SUSPENDED',
        'This account has been suspended.',
        {'reason': user.suspendedReason},
      );
    }
    return Ok(token);
  }

  void _revokeSession(String sessionId) {
    _sessions[sessionId]?.revoked = true;
    for (final token in _refreshTokens.values) {
      if (token.sessionId == sessionId) token.revoked = true;
    }
  }

  void _revokeAllSessions(String userId) {
    for (final session in _sessions.values) {
      if (session.userId == userId) _revokeSession(session.id);
    }
  }

  List<String> _passwordViolations(String password) => [
    if (password.length < 8) 'Password must be at least 8 characters.',
    if (!password.contains(RegExp('[A-Z]')))
      'Password must contain at least one uppercase letter.',
    if (!password.contains(RegExp('[a-z]')))
      'Password must contain at least one lowercase letter.',
    if (!password.contains(RegExp('[0-9]')))
      'Password must contain at least one digit.',
  ];

  List<Map<String, Object?>>? _codeFieldErrors(String code) {
    if (code.length < 4) {
      return [_fieldError('code', 'String should have at least 4 characters')];
    }
    if (code.length > 10) {
      return [_fieldError('code', 'String should have at most 10 characters')];
    }
    return null;
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static String _roleSlug(RegistrableRole role) => switch (role) {
    RegistrableRole.passenger => 'passenger',
    RegistrableRole.driver => 'driver',
    RegistrableRole.fleetOwner => 'fleet_owner',
  };

  Map<String, Object?> _fieldError(String field, String message) => {
    'type': 'value_error',
    'loc': ['body', field],
    'msg': message,
  };

  Err<T> _validationError<T>(List<Map<String, Object?>> errors) => _error(
    422,
    'VALIDATION_ERROR',
    'The submitted data is invalid.',
    {'errors': errors},
  );

  Err<T> _error<T>(
    int status,
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) => Err(_failure(status, code, message, details));

  /// The backend's error envelope, mapped exactly as a live response is.
  AppFailure _failure(
    int status,
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) => AppFailure.fromResponse(
    statusCode: status,
    body: {
      'error': {
        'code': code,
        'message': message,
        'details': details,
        'request_id': 'mock-${++_counter}',
      },
    },
  );

  String _uuid() {
    final n = (++_counter).toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$n';
  }
}

/// A code the mock "sent", for tests and the debug screen.
class SentCode {
  const SentCode({
    required this.to,
    required this.channel,
    required this.purpose,
    required this.code,
  });

  final String to;
  final OtpChannel channel;
  final OtpPurpose purpose;
  final String code;
}

class _User {
  _User({
    required this.id,
    required this.phone,
    required this.email,
    required this.password,
    required this.fullName,
    required this.roles,
    required this.createdAt,
    this.preferredLanguage = 'en',
  });

  final String id;
  final String phone;
  final String? email;
  final String password;
  final String fullName;
  final List<String> roles;
  final DateTime createdAt;
  final String preferredLanguage;
  DateTime? phoneVerifiedAt;
  DateTime? emailVerifiedAt;
  String? suspendedReason;
  DateTime? lockedUntil;
  int failedLogins = 0;

  bool get isVerified => phoneVerifiedAt != null || emailVerifiedAt != null;

  UserResponse toResponse() => UserResponse(
    id: id,
    phoneNumber: phone,
    email: email,
    isActive: true,
    phoneVerified: phoneVerifiedAt != null,
    emailVerified: emailVerifiedAt != null,
    roles: roles,
    createdAt: createdAt,
    profile: UserProfileResponse(
      fullName: fullName,
      preferredLanguage: preferredLanguage,
      ghanaCardVerified: false,
    ),
  );
}

class _Challenge {
  _Challenge({
    required this.target,
    required this.purpose,
    required this.channel,
    required this.expiresAt,
  });

  final String target;
  final OtpPurpose purpose;
  final OtpChannel channel;
  final DateTime expiresAt;
  int attempts = 0;
  bool used = false;
}

class _Session {
  _Session({required this.id, required this.userId});

  final String id;
  final String userId;
  bool revoked = false;
}

class _RefreshToken {
  _RefreshToken({
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  });

  final String userId;
  final String sessionId;
  final DateTime expiresAt;
  bool revoked = false;
}

class _AccessToken {
  _AccessToken({
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  });

  final String userId;
  final String sessionId;
  DateTime expiresAt;
}
