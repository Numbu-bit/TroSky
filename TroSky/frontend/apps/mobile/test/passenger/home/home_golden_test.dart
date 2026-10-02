@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/shell/passenger_shell.dart';

import '../../helpers/fakes.dart';
import 'home_helpers.dart';

/// Home in mock mode at 9:00, located next to the Madina stop: compare with
/// design/P-01/home.png.
///
/// Map tiles are one flat colour (tests never reach the tile server), and
/// emoji have no font in tests, so 👋 🔔 and the tab icons show as space.
/// Animations are off, so the location ring stands still at 15 %.
Future<void> _golden(WidgetTester tester, Size size, String name) async {
  final world = TestWorld()..now = DateTime(2026, 10, 1, 9);
  world.location
    ..permission = LocationPermissionStatus.granted
    ..position = nearMadina;
  await openHome(tester, world: world, size: size);
  // Tiles and SVG icons decode off the test clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  debugDisableShadows = false;
  try {
    await expectLater(
      find.byType(PassengerShell),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('P-01 Home at the design frame, 390 x 844', (tester) async {
    await _golden(tester, const Size(390, 844), 'home_390');
  });

  testWidgets('P-01 Home on the TECNO BG6, 360 x 806', (tester) async {
    await _golden(tester, const Size(360, 806), 'home_360');
  });
}
