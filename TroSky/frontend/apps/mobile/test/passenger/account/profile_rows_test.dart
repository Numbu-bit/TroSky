// Step 21/B2 regression test: Profile should no longer show "Coming
// soon" anywhere except the two backend-blocked rows (Change
// password / Change email), which now read "Coming with the next
// backend release".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The test harness runs with CWD = apps/mobile, so the source path is
// predictable. `Isolate.resolvePackageUri` isn't available in Flutter
// tests, so this reads the file by relative path.
final _profileScreen = File(
  'lib/passenger/account/presentation/profile_screen.dart',
);

void main() {
  test(
    'Profile source: no subtitle: l10n.profileComingSoon left on a Profile row',
    () async {
      final content = await _profileScreen.readAsString();
      expect(
        RegExp(r'subtitle:\s*l10n\.profileComingSoon').hasMatch(content),
        isFalse,
        reason:
            'Profile rows must not use profileComingSoon; use '
            'profileNextBackendRelease for backend-blocked rows or wire '
            'the row to a real screen.',
      );
    },
  );

  test(
    'Profile source: Change password + Change email use profileNextBackendRelease',
    () async {
      final content = await _profileScreen.readAsString();
      expect(
        RegExp(r'profileNextBackendRelease').allMatches(content).length,
        greaterThanOrEqualTo(2),
      );
    },
  );
}
