// Step 21/B2 + B4 regression test: Profile should no longer show
// "Coming soon" anywhere, and the Change password + Change email
// rows must be wired to real screens (step 21/B4), not left as
// "Coming with the next backend release" subtitles.

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
            'Profile rows must not use profileComingSoon; wire the row to '
            'a real screen.',
      );
    },
  );

  test('Profile source: Change password + Change email are wired to their '
      'routes (no profileNextBackendRelease subtitle left)', () async {
    final content = await _profileScreen.readAsString();
    // No row should carry the "coming with the next backend release"
    // subtitle any more — both endpoints shipped in step 21/B4.
    expect(
      RegExp(r'subtitle:\s*l10n\.profileNextBackendRelease').hasMatch(content),
      isFalse,
      reason:
          'profileNextBackendRelease subtitles should have been removed '
          'when Change password + Change email went live (step 21/B4).',
    );
    // Both routes should be referenced from Profile now.
    expect(content, contains('AppRoute.changePassword.name'));
    expect(content, contains('AppRoute.changeEmail.name'));
  });
}
