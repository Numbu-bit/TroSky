// Step 21/B2 fix: the Home map SOS FAB must route to AppRoute.sosAlert
// (real P-12 Emergency), not AppRoute.sos (placeholder).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _homeMap = File('lib/passenger/home/presentation/widgets/home_map.dart');

void main() {
  test('home_map pushes AppRoute.sosAlert, not AppRoute.sos', () async {
    final src = await _homeMap.readAsString();
    expect(
      RegExp(r'AppRoute\.sosAlert').hasMatch(src),
      isTrue,
      reason: 'Home SOS FAB must push the real sosAlert route.',
    );
    expect(
      RegExp(r'pushNamed\(AppRoute\.sos\.name').hasMatch(src),
      isFalse,
      reason: 'Home SOS FAB must not push the placeholder sos route.',
    );
  });

  test(
    'home_sheet does not push AppRoute.subscribe (banner removed)',
    () async {
      final sheet = await File(
        'lib/passenger/home/presentation/widgets/home_sheet.dart',
      ).readAsString();
      expect(
        RegExp(r'AppRoute\.subscribe').hasMatch(sheet),
        isFalse,
        reason:
            'Subscribe banner was removed in step 21/B2; its route '
            'push should be gone from home_sheet.',
      );
    },
  );
}
