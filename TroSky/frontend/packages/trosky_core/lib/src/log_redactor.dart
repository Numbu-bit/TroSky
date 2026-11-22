/// H5 of the 21 Nov 2026 pre-launch audit. A single redaction surface
/// for anything that could end up in a log line, breadcrumb, telemetry
/// payload, or crash report — so a future Sentry/Crashlytics wiring
/// does not need to repeat the list.
///
/// What this redacts (case-insensitive):
/// - HTTP headers: Authorization, Proxy-Authorization, Cookie,
///   Set-Cookie, X-Refresh-Token, X-Api-Key.
/// - URL query parameters: `token`, `access_token`, `refresh_token`,
///   `password`, `otp`, `code`.
/// - Ghana phone numbers in any form (+233…, 024…, 054…, etc.).
/// - Email addresses.
/// - Lat/lng coordinates and decimal-degree-looking pairs.
/// - Bearer-shaped strings (JWT, API key).
///
/// What this does NOT replace:
/// - Access control. A log line that should never exist (a raw
///   response body dump) must be removed, not redacted.
/// - The telemetry schema in `apps/mobile/lib/app/telemetry.dart` (C5)
///   which is the primary analytics guard. The redactor runs below
///   that, for free-form strings like Dio exception messages.
library;

final class LogRedactor {
  const LogRedactor();

  /// Headers that must never ship their value anywhere. Compared
  /// case-insensitively against the trimmed header name.
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-refresh-token',
    'x-api-key',
    'x-access-token',
    'x-auth-token',
  };

  /// Query parameters whose value is always redacted.
  static const Set<String> _sensitiveQuery = {
    'token',
    'access_token',
    'refresh_token',
    'password',
    'otp',
    'code',
    'api_key',
    'bearer',
  };

  static final RegExp _phone = RegExp(r'\+?233\d{9}|\b0[2-5]\d{8}\b');
  static final RegExp _email = RegExp(
    r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  // 4 or more decimal places looks like lat/lng (Accra is ~5.5°N, so a
  // 4-decimal value is accurate to ~10 m).
  static final RegExp _coord = RegExp(
    r'[-+]?\d{1,3}\.\d{4,}[,\s]+[-+]?\d{1,3}\.\d{4,}',
  );
  // A JWT or a long base64 bearer.
  static final RegExp _bearer = RegExp(
    r'\b[Bb]earer\s+[A-Za-z0-9_\-\.]{20,}'
    r'|'
    r'\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\b',
  );

  /// Redacts [headers] in place-safely: returns a new map with
  /// sensitive values replaced by `"<redacted>"`.
  Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
    final out = <String, Object?>{};
    headers.forEach((k, v) {
      out[k] = _sensitiveHeaders.contains(k.toLowerCase()) ? '<redacted>' : v;
    });
    return out;
  }

  /// Replaces values of known-sensitive query params in [uri] with
  /// `"<redacted>"` and returns the string form.
  String redactUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    final clean = Map<String, String>.from(uri.queryParameters);
    clean.updateAll((k, v) {
      return _sensitiveQuery.contains(k.toLowerCase()) ? '<redacted>' : v;
    });
    return uri.replace(queryParameters: clean).toString();
  }

  /// Applies all the string-shape redactions (phone, email, coord,
  /// bearer) to free-form text that might end up in a log line, a
  /// crash breadcrumb, or an exception `.toString()`.
  String redactString(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll(_bearer, '<bearer-redacted>')
        .replaceAll(_phone, '<phone-redacted>')
        .replaceAll(_email, '<email-redacted>')
        .replaceAll(_coord, '<coord-redacted>');
  }
}

/// A convenience const for call sites that don't inject the redactor.
const LogRedactor troskyRedactor = LogRedactor();
