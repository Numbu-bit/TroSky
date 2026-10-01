import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

void main() {
  test('every extracted value has a token', () {
    // Counts from docs/design-tokens.md.
    expect(TroskyColors.all, hasLength(157));
    expect(TroskyGradients.all, hasLength(22));
    expect(TroskyTypography.all, hasLength(103));
    expect(TroskyShadows.all, hasLength(37));
  });

  test('core colours match globals.css', () {
    expect(TroskyColors.green.toARGB32(), 0xFF0E9E6D);
    expect(TroskyColors.greenDark.toARGB32(), 0xFF0B7E57);
    expect(TroskyColors.navy.toARGB32(), 0xFF12263B);
    expect(TroskyColors.amber.toARGB32(), 0xFFF4B333);
    expect(TroskyColors.background.toARGB32(), 0xFFF5F7FA);
    // --green-lt: rgba(14,158,109,0.12) -> alpha round(0.12 * 255) = 0x1F
    expect(TroskyColors.greenLight.toARGB32(), 0x1F0E9E6D);
    expect(TroskyColors.greenLight, TroskyColors.greenA12);
  });

  test('hex alpha 18 tints keep the accent colour', () {
    expect(TroskyColors.greenTint18.toARGB32(), 0x180E9E6D);
    expect(TroskyColors.redTint18.toARGB32(), 0x18E23D3D);
  });

  test('the splash gradient keeps its CSS stops and angle', () {
    final splash = TroskyGradients.splash;
    expect(splash.colors, [
      TroskyColors.splashGreenDeep,
      TroskyColors.green,
      TroskyColors.splashGreenBright,
    ]);
    expect(splash.stops, [0, 0.5, 1]);
    expect(splash.transform, const CssGradientTransform(160));
  });

  test('text styles resolve to the bundled fonts', () {
    const title = TroskyTypography.heading26ExtraBoldH120;
    expect(title.fontFamily, 'packages/trosky_ui/PlusJakartaSans');
    expect(title.fontSize, 26);
    expect(title.fontWeight, FontWeight.w800);
    expect(title.height, 1.2);
    expect(title.leadingDistribution, TextLeadingDistribution.even);

    const label = TroskyTypography.body12SemiBoldLs4;
    expect(label.fontFamily, 'packages/trosky_ui/Inter');
    expect(label.height, 1.5);
    expect(label.letterSpacing, closeTo(0.48, 1e-9));
  });

  test(
    'weights beyond the loaded fonts render at the nearest loaded weight',
    () {
      // SOS asks for Plus Jakarta Sans 900; the font stops at 800.
      expect(TroskyTypography.heading22BlackLs5.fontWeight, FontWeight.w800);
      // Inter is loaded up to 700.
      expect(TroskyTypography.body20ExtraBold.fontWeight, FontWeight.w700);
    },
  );
}
