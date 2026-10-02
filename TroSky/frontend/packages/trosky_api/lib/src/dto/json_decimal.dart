// Pydantic writes `Decimal` fields as JSON strings ("182.50") to keep their
// precision; numbers are accepted too.

/// A money `Decimal` exactly as sent ("8.00"), never through a double.
String decimalString(Object? json) => switch (json) {
  final String s => s,
  final num n => n.toString(),
  _ => throw FormatException('Not a decimal: $json'),
};

/// [decimalString] for a `Decimal | None` field.
String? decimalStringOrNull(Object? json) =>
    json == null ? null : decimalString(json);

/// A `Decimal | None` field as a double, for values that are measurements
/// rather than money (headings, distances).
double? decimalOrNull(Object? json) => switch (json) {
  null => null,
  final num n => n.toDouble(),
  final String s => double.parse(s),
  _ => throw FormatException('Not a decimal: $json'),
};
