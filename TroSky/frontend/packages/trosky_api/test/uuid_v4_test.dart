// `uuidV4()` is the shared Idempotency-Key source for wallet top-ups
// (step 11) and, since step 21/B4, P-23 Change password + P-24 Change
// email. Verify shape + variant/version bits so a future refactor
// can't downgrade to a weaker format silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('uuidV4 returns a canonical 8-4-4-4-12 hex string', () {
    final value = uuidV4();
    expect(_uuidPattern.hasMatch(value), isTrue, reason: value);
    expect(value.length, 36);
  });

  test('uuidV4 pins version 4 (nibble 13) + RFC 4122 variant (nibble 17)', () {
    for (var i = 0; i < 64; i++) {
      final value = uuidV4();
      expect(value[14], '4', reason: '$value: version nibble must be 4');
      expect(
        {'8', '9', 'a', 'b'}.contains(value[19]),
        isTrue,
        reason: '$value: variant nibble must be 8/9/a/b',
      );
    }
  });

  test('uuidV4 is distinct across many calls', () {
    final seen = <String>{};
    for (var i = 0; i < 128; i++) {
      seen.add(uuidV4());
    }
    expect(seen.length, 128);
  });
}
