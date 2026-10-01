import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'phone_patterns.dart' as patterns;

/// Thrown when a phone number cannot be parsed or is not a valid number.
class InvalidPhoneNumberException implements Exception {
  const InvalidPhoneNumberException(this.input);

  final String input;

  @override
  String toString() => "'$input' is not a valid phone number";
}

/// Normalises [raw] to E.164 (`+233241234567`) exactly like the backend's
/// `normalize_phone_number` (backend/app/utilities/phone.py), which uses
/// Google's libphonenumber with [region] for numbers without a country code
/// and accepts only valid numbers.
///
/// `0241234567`, `241234567`, `+233 24 123 4567` and `024 123-4567` all
/// give `+233241234567`. Throws [InvalidPhoneNumberException] otherwise.
///
/// libphonenumber's clean-up of the typed text is ported below (leading
/// junk, extensions, repeated plus signs, keypad letters); country codes,
/// trunk prefixes and validity come from `phone_numbers_parser`, a Dart
/// port of the same metadata. test/fixtures/phone_cases.json holds the
/// backend's answers for the inputs the tests check. RFC 3966 `tel:` URIs
/// with a `phone-context` are not handled; nobody types those.
String normalizePhoneNumber(String raw, {String region = 'GH'}) {
  final cleaned = _clean(raw);
  if (cleaned == null) throw InvalidPhoneNumberException(raw);
  final PhoneNumber parsed;
  try {
    parsed = PhoneNumber.parse(
      cleaned,
      callerCountry: IsoCode.values.byName(region.toUpperCase()),
    );
  } on PhoneNumberException {
    throw InvalidPhoneNumberException(raw);
  }
  if (!parsed.isValid()) throw InvalidPhoneNumberException(raw);
  return parsed.international;
}

/// [normalizePhoneNumber], or null for an invalid number.
String? tryNormalizePhoneNumber(String raw, {String region = 'GH'}) {
  try {
    return normalizePhoneNumber(raw, region: region);
  } on InvalidPhoneNumberException {
    return null;
  }
}

/// The region-independent first half of libphonenumber's `parse`: what is
/// left is `+` and digits, or digits only. Null if it can't be a number.
String? _clean(String raw) {
  if (raw.length > patterns.maxInputStringLength) return null;
  var number = _extractPossibleNumber(_asciiDigits(raw));
  final isdn = number.indexOf(patterns.isdnSubaddress);
  if (isdn > 0) number = number.substring(0, isdn);
  if (!_isViable(number)) return null;
  number = _stripExtension(number);
  final plus = patterns.plusChars.matchAsPrefix(number);
  final digits = _normalize(plus == null ? number : number.substring(plus.end));
  if (digits.isEmpty) return null;
  return plus == null ? digits : '+$digits';
}

/// Drops anything before the first `+` or digit (e.g. "Tel:"), trailing
/// punctuation, and a second number after "/x".
String _extractPossibleNumber(String number) {
  final start = patterns.validStartChar.firstMatch(number);
  if (start == null) return '';
  var result = number.substring(start.start);
  final trailing = patterns.unwantedEndChars.firstMatch(result);
  if (trailing != null) result = result.substring(0, trailing.start);
  final second = patterns.secondNumberStart.firstMatch(result);
  if (second != null) result = result.substring(0, second.start);
  return result;
}

bool _isViable(String number) =>
    number.length >= patterns.minLengthForNsn &&
    _fullMatch(patterns.validPhoneNumber, number);

/// Removes an extension such as " ext. 12" or " x12", if what comes before
/// it is still a viable number.
String _stripExtension(String number) {
  final match = patterns.extension.firstMatch(number);
  if (match == null) return number;
  final before = number.substring(0, match.start);
  if (!_isViable(before)) return number;
  for (var i = 1; i <= match.groupCount; i++) {
    if (match.group(i) != null) return before;
  }
  return number;
}

/// Digits only; with three or more letters, letters become keypad digits
/// ("024-ABC-4567" → "0242224567").
String _normalize(String number) {
  final alpha = _fullMatch(patterns.validAlphaPhone, number);
  final out = StringBuffer();
  for (final char in number.split('')) {
    if (_isAsciiDigit(char)) {
      out.write(char);
    } else if (alpha) {
      final digit = patterns.alphaMappings[char.toUpperCase()];
      if (digit != null) out.write(digit);
    }
  }
  return out.toString();
}

bool _isAsciiDigit(String char) {
  final unit = char.codeUnitAt(0);
  return unit >= 0x30 && unit <= 0x39;
}

/// Full-width and Arabic-Indic digits to ASCII, as libphonenumber's
/// Unicode-aware digit handling does.
String _asciiDigits(String input) {
  const zeros = [0xFF10, 0x0660, 0x06F0];
  return String.fromCharCodes(
    input.runes.map((rune) {
      for (final zero in zeros) {
        if (rune >= zero && rune <= zero + 9) return 0x30 + rune - zero;
      }
      return rune;
    }),
  );
}

final Map<RegExp, RegExp> _anchored = {};

bool _fullMatch(RegExp pattern, String input) {
  final anchored = _anchored.putIfAbsent(
    pattern,
    () => RegExp(
      '^(?:${pattern.pattern})\$',
      unicode: pattern.isUnicode,
      caseSensitive: pattern.isCaseSensitive,
    ),
  );
  return anchored.hasMatch(input);
}
