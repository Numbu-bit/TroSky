// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

import 'package:flutter/painting.dart';

/// Every text style in the Figma Make designs.
///
/// Names read family, size, weight, then modifiers: H120 = line-height 1.2,
/// Ls4 = letter-spacing 0.04em. Without an H the line height is 1.5, the
/// Tailwind preflight default the designs inherit. Styles prefixed `svg` come
/// from SVG `<text>` in illustrations and have no line height.
///
/// Colours are applied where the style is used.
abstract final class TroskyTypography {
  /// Plus Jakarta Sans, bundled in this package.
  static const String headingFamily = 'PlusJakartaSans';

  /// Inter, bundled in this package.
  static const String bodyFamily = 'Inter';

  /// CSS `monospace`. Not bundled, so the platform's monospace font is used.
  static const String monoFamily = 'monospace';

  static const String _package = 'trosky_ui';

  /// Inter 32 / 400 · line-height 1.5
  /// Used on: P11 — e.g. "👨🏿‍💼"
  static const TextStyle body32Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 30 / 400 · line-height 1.5
  /// Used on: D5 — e.g. "👩🏿‍💼"
  static const TextStyle body30Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 28 / 400 · line-height 1.5
  /// Used on: A:Fraud
  static const TextStyle body28Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 24 / 400 · line-height 1.5
  /// Used on: P8, P10, P11, D8 — e.g. "📷"
  static const TextStyle body24Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 22 / 400 · line-height 1.5
  /// Used on: D1 — e.g. "📍"
  static const TextStyle body22Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 20 / 400 · line-height 1.5
  /// Used on: D1, A:Overview, A:Reports — e.g. "📲"
  static const TextStyle body20Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 20 / 800 · line-height 1.5
  /// The design asks for 800; the loaded font stops at 700, which is what the browser renders.
  /// Used on: A:Drivers
  static const TextStyle body20ExtraBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 18 / 400 · line-height 1.5
  /// Used on: P4, D1, D5, D8 — e.g. "📄"
  static const TextStyle body18Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 17 / 400 · line-height 1.5
  /// Used on: P11, A:Shell
  static const TextStyle body17Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 16 / 400 · line-height 1.5
  /// Used on: P4, P5, P8, P9, P14, D2, D4, A:Fraud, A:Reports, A:Shell — e.g. "👤"
  static const TextStyle body16Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 14 / 400 · line-height 1.5
  /// Used on: P4, P5, P7, P10, P15, D2, D3, A:Login — e.g. "👤"
  static const TextStyle body14Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 14 / 400 · line-height 1.6
  /// Used on: P1, P2, P3 — e.g. "Find a shared vehicle going your w"
  static const TextStyle body14RegularH160 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 14 / 500 · line-height 1.5
  /// Used on: P4 — e.g. "Continue with Email"
  static const TextStyle body14Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 14 / 600 · line-height 1.5
  /// Used on: P4, P8, P11, P15 — e.g. "+233"
  static const TextStyle body14SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 14 / 700 · line-height 1.5
  /// Used on: P9, P12, D2 — e.g. "Decline"
  static const TextStyle body14Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 13 / 400 · line-height 1.5
  /// Used on: Splash, P4, P6, P7, P11, P12, P14, P15, P16, D5, D7, D8, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports — e.g. "Thursday, 31 Jul 2026 · Refreshed "
  static const TextStyle body13Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 13 / 500 · line-height 1.5
  /// Used on: P1, P2, P3, P9, P10, D4, A:Analytics, A:Fraud, A:Overview, A:Shell — e.g. "Skip"
  static const TextStyle body13Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 13 / 600 · line-height 1.5
  /// Used on: P8, P9, P13, P15, D1, D5, D6, D7, D8, D9, A:Fleet, A:Fraud, A:Overview, A:Shell — e.g. "Export CSV"
  static const TextStyle body13SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 13 / 700 · line-height 1.5
  /// Used on: P16, D3, D4, D6, D7, A:Drivers, A:Fleet, A:Fraud, A:Reports — e.g. "⭐"
  static const TextStyle body13Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 400 · line-height 1.5
  /// Used on: P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D2, D4, D5, D7, D8, D9, A:Analytics, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports — e.g. "184 vehicles online"
  static const TextStyle body12Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 400 · line-height 1.5 · letter-spacing 0.05em
  /// Used on: P9 — e.g. "TROSKY WALLET"
  static const TextStyle body12RegularLs5 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.6,
  );

  /// Inter 12 / 500 · line-height 1.4
  /// Used on: D2 — e.g. "No new ride requests while a trip "
  static const TextStyle body12MediumH140 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 500 · line-height 1.5
  /// Used on: P5, P6, D2, A:Fraud — e.g. "Dismiss"
  static const TextStyle body12Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 600 · line-height 1.3333
  /// Used on: Chip — e.g. "Chip label"
  static const TextStyle body12SemiBoldH133 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3333,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 600 · line-height 1.4
  /// Used on: D3
  static const TextStyle body12SemiBoldH140 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 600 · line-height 1.5
  /// Used on: P5, P6, P9, P13, P14, P16, D1, D3, D6, D8, D9, A:Demand, A:Drivers, A:Fraud, A:Overview, A:Reports — e.g. "Review"
  static const TextStyle body12SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 12 / 600 · line-height 1.5 · letter-spacing 0.04em
  /// Used on: P4, A:Login — e.g. "PHONE NUMBER"
  static const TextStyle body12SemiBoldLs4 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.48,
  );

  /// Inter 12 / 700 · line-height 1.5
  /// Used on: P5, P10, P11, P12, D3, D5, D7, A:Demand, A:Drivers — e.g. "%"
  static const TextStyle body12Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 11 / 400 · line-height 1.5
  /// Used on: P5, P6, P7, P9, P10, P11, P12, P13, P14, P15, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Overview, A:Reports, A:Shell — e.g. "Low → High demand"
  static const TextStyle body11Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 11 / 500 · line-height 1.5
  /// Used on: P5, P7, A:Drivers — e.g. "Madina, Accra"
  static const TextStyle body11Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 11 / 600 · line-height 1.5
  /// Used on: P6, P10, P14, P15, D2, D4, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports — e.g. "↑"
  static const TextStyle body11SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 11 / 600 · line-height 1.5 · letter-spacing 0.04em
  /// Used on: D6, A:Fleet, A:Fraud, A:Overview — e.g. "SHOW THIS TO BOARDING PASSENGERS"
  static const TextStyle body11SemiBoldLs4 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.44,
  );

  /// Inter 11 / 700 · line-height 1.5 · letter-spacing 0.04em
  /// Used on: A:Drivers, A:Reports
  static const TextStyle body11BoldLs4 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.44,
  );

  /// Inter 11 / 700 · line-height 1.5 · letter-spacing 0.05em
  /// Used on: P10, D7, D8, D9, A:Drivers — e.g. "PERFORMANCE"
  static const TextStyle body11BoldLs5 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.55,
  );

  /// Inter 11 / 700 · line-height 1.5
  /// Used on: P6, P7, P10, P12, D2 — e.g. "Save"
  static const TextStyle body11Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 11 / 700 · line-height 1.5 · letter-spacing 0.06em
  /// Used on: P15 — e.g. "TRUSTED CONTACTS NOTIFIED"
  static const TextStyle body11BoldLs6 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.66,
  );

  /// Inter 10 / 400 · line-height 1.4
  /// Used on: D3 — e.g. "Seat · →"
  static const TextStyle body10RegularH140 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.4,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 10 / 400 · line-height 1.5
  /// Used on: P6, P7, P8, P10, P12, P13, P14, P16, D1, D6, D7, D8, D9, A:Analytics, A:Drivers, A:Overview — e.g. "GR-"
  static const TextStyle body10Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 10 / 400 · line-height 1.5 · letter-spacing 0.06em
  /// Used on: A:Shell — e.g. "ADMIN CONSOLE"
  static const TextStyle body10RegularLs6 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.6,
  );

  /// Inter 10 / 500 · line-height 1.5
  /// Used on: D1, D4
  static const TextStyle body10Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 10 / 600 · line-height 1.5
  /// Used on: P6, P7, D1, D2 — e.g. "Drop off passengers first"
  static const TextStyle body10SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 10 / 700 · line-height 1.5
  /// Used on: P6, P7, P11, P13, D1, A:Reports, A:Shell — e.g. "Drop Off"
  static const TextStyle body10Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 10 / 700 · line-height 1.5 · letter-spacing 0.07em
  /// Used on: D6 — e.g. "RECENTLY BOARDED"
  static const TextStyle body10BoldLs7 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.7,
  );

  /// Inter 10 / 700 · line-height 1.5 · letter-spacing 0.06em
  /// Used on: P5 — e.g. "NEW FEATURE"
  static const TextStyle body10BoldLs6 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.6,
  );

  /// Inter 10 / 700 · line-height 1.5 · letter-spacing 0.05em
  /// Used on: P11
  static const TextStyle body10BoldLs5 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.5,
  );

  /// Inter 9 / 400 · line-height 1.5
  /// Used on: D2, D6 — e.g. "BOARDED"
  static const TextStyle body9Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Inter 9 / 400 · line-height 1.5 · letter-spacing 0.05em
  /// Used on: P15 — e.g. "HOLD 3 SEC"
  static const TextStyle body9RegularLs5 = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.45,
  );

  /// Inter 9 / 700 · line-height 1.5
  /// Used on: P10 — e.g. "BEST VALUE"
  static const TextStyle body9Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 42 / 800 · line-height 1
  /// Used on: D5 — e.g. "4.9"
  static const TextStyle heading42ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 42,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 38 / 800 · line-height 1
  /// Used on: P9, D4 — e.g. "₵1,414.00"
  static const TextStyle heading38ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 38 / 800 · line-height 1.5
  /// Used on: D9 — e.g. "₵1,414.50"
  static const TextStyle heading38ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 34 / 800 · line-height 1.5
  /// Used on: D7 — e.g. "₵48.00"
  static const TextStyle heading34ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 32 / 800 · line-height 1.5
  /// Used on: P13 — e.g. "₵128.50"
  static const TextStyle heading32ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 30 / 800 · line-height 1
  /// Used on: P7 — e.g. "₵"
  static const TextStyle heading30ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 28 / 800 · line-height 1
  /// Used on: A:Fraud, A:Overview
  static const TextStyle heading28ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 28 / 800 · line-height 1.5
  /// Used on: P16 — e.g. "K"
  static const TextStyle heading28ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 26 / 800 · line-height 1
  /// Used on: A:Reports
  static const TextStyle heading26ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 26 / 800 · line-height 1.2
  /// Used on: P1, P2, P3 — e.g. "Book a Seat, Not a Whole Car"
  static const TextStyle heading26ExtraBoldH120 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 26 / 800 · line-height 1.5
  /// Used on: A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports — e.g. "Overview"
  static const TextStyle heading26ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 24 / 800 · line-height 1.2
  /// Used on: P4 — e.g. "Welcome to TroSky"
  static const TextStyle heading24ExtraBoldH120 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 24 / 800 · line-height 1.5
  /// Used on: D2, D9 — e.g. "₵28.50"
  static const TextStyle heading24ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 22 / 800 · line-height 1
  /// Used on: P6, D2 — e.g. "₵"
  static const TextStyle heading22ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 22 / 800 · line-height 1.5
  /// Used on: P9, P10, P15, D4, A:Login — e.g. "Admin Console"
  static const TextStyle heading22ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 22 / 900 · line-height 1.5 · letter-spacing 0.05em
  /// The design asks for 900; the loaded font stops at 800, which is what the browser renders.
  /// Used on: P15 — e.g. "SOS"
  static const TextStyle heading22BlackLs5 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 1.1,
  );

  /// Plus Jakarta Sans 20 / 700 · line-height 1.5
  /// Used on: P5, D1 — e.g. "Akosua Boateng"
  static const TextStyle heading20Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 20 / 800 · line-height 1
  /// Used on: D6 — e.g. "/"
  static const TextStyle heading20ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 20 / 800 · line-height 1.5
  /// Used on: P10, P11, P13, P14, D2, D7, D8, D9 — e.g. "Payment Receipts"
  static const TextStyle heading20ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 19 / 800 · line-height 1.5
  /// Used on: P16, D2, D5 — e.g. "Show QR to Passengers"
  static const TextStyle heading19ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 18 / 700 · line-height 1.5
  /// Used on: D2 — e.g. "Incoming Request"
  static const TextStyle heading18Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 18 / 800 · line-height 1.5 · letter-spacing -0.3px
  /// Used on: A:Login — e.g. "TroSky"
  static const TextStyle heading18ExtraBoldLsNeg0p3px = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: -0.3,
  );

  /// Plus Jakarta Sans 18 / 800 · line-height 1.5
  /// Used on: D2, D6 — e.g. "Madina → Circle"
  static const TextStyle heading18ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 17 / 600 · line-height 1.5 · letter-spacing 0.01em
  /// Used on: Splash — e.g. "Your Journey. On Time."
  static const TextStyle heading17SemiBoldLs1 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.17,
  );

  /// Plus Jakarta Sans 17 / 700 · line-height 1.5
  /// Used on: P7, P16, D3 — e.g. "Active Route"
  static const TextStyle heading17Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 17 / 800 · line-height 1.5
  /// Used on: P12 — e.g. "Madina → Circle"
  static const TextStyle heading17ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 16 / 700 · line-height 1.5
  /// Used on: P1, P2, P3, P6, P8, P13, A:Drivers — e.g. "Next"
  static const TextStyle heading16Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 16 / 800 · line-height 1.5
  /// Used on: P7, P12, D1 — e.g. "K"
  static const TextStyle heading16ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 15 / 700 · line-height 1.5
  /// Used on: P4, P5, P8, P10, P14, P16, D7, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports — e.g. "Live Fleet Map"
  static const TextStyle heading15Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 14 / 700 · line-height 1.5
  /// Used on: P6, P7, P10, P11, P12, P13, P14, D1, D2, D4, D7, D9, A:Analytics — e.g. "Revenue Over Time"
  static const TextStyle heading14Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 14 / 800 · line-height 1
  /// Used on: A:Shell — e.g. "TroSky"
  static const TextStyle heading14ExtraBoldH100 = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 14 / 800 · line-height 1.5
  /// Used on: D9 — e.g. "M"
  static const TextStyle heading14ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 13 / 600 · line-height 1.5
  /// Used on: D2 — e.g. "Passengers boarding"
  static const TextStyle heading13SemiBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 13 / 700 · line-height 1.5
  /// Used on: P5, P8, P9, P16, D1, D2, D3, D5, D6, D9 — e.g. "QR Boarding Active"
  static const TextStyle heading13Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 12 / 800 · line-height 1.5
  /// Used on: P15, A:Demand — e.g. "TroSky"
  static const TextStyle heading12ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 11 / 700 · line-height 1.5
  /// Used on: P7
  static const TextStyle heading11Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Plus Jakarta Sans 10 / 800 · line-height 1.5
  /// Used on: P5 — e.g. "SOS"
  static const TextStyle heading10ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// monospace 12 / 700 · line-height 1.5 · letter-spacing 0.1em
  /// Used on: D6 — e.g. "TSKY-2026-8431"
  static const TextStyle mono12BoldLs10 = TextStyle(
    fontFamily: monoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 1.2,
  );

  /// monospace 11 / 400 · line-height 1.5
  /// Used on: P12, A:Fraud, A:Reports — e.g. "TRO-2024-MDN-CCL-004"
  static const TextStyle mono11Regular = TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// monospace 11 / 700 · line-height 1.5 · letter-spacing 0.05em
  /// Used on: D2 — e.g. "TSKY-2026-8431"
  static const TextStyle mono11BoldLs5 = TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0.55,
  );

  /// Inter 16 / 400
  /// Used on: P8 — e.g. "🚌"
  static const TextStyle svgBody16Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  /// Inter 14 / 400
  /// Used on: D1, D2, D3 — e.g. "🚌"
  static const TextStyle svgBody14Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Inter 13 / 400
  /// Used on: A:Demand, A:Fleet, A:Overview — e.g. "🚌"
  static const TextStyle svgBody13Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// Inter 10 / 400
  /// Used on: A:Demand, A:Fleet, A:Overview
  static const TextStyle svgBody10Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  /// Inter 10 / 600
  /// Used on: P2 — e.g. "price drops"
  static const TextStyle svgBody10SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  /// Inter 9 / 400
  /// Used on: P3 — e.g. "Madina → Circle"
  static const TextStyle svgBody9Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w400,
  );

  /// Inter 9 / 600
  /// Used on: P8 — e.g. "DESTINATION"
  static const TextStyle svgBody9SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );

  /// Inter 9 / 700
  /// Used on: P1 — e.g. "YOUR SEAT"
  static const TextStyle svgBody9Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 9,
    fontWeight: FontWeight.w700,
  );

  /// Inter 8 / 400
  /// Used on: P3
  static const TextStyle svgBody8Regular = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 8,
    fontWeight: FontWeight.w400,
  );

  /// Inter 8 / 500
  /// Used on: P3
  static const TextStyle svgBody8Medium = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 8,
    fontWeight: FontWeight.w500,
  );

  /// Inter 8 / 600
  /// Used on: P3 — e.g. "07:15"
  static const TextStyle svgBody8SemiBold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 8,
    fontWeight: FontWeight.w600,
  );

  /// Inter 8 / 700
  /// Used on: BusPin
  static const TextStyle svgBody8Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 8,
    fontWeight: FontWeight.w700,
  );

  /// Inter 7 / 700
  /// Used on: P2 — e.g. "₵"
  static const TextStyle svgBody7Bold = TextStyle(
    fontFamily: bodyFamily,
    package: _package,
    fontSize: 7,
    fontWeight: FontWeight.w700,
  );

  /// Plus Jakarta Sans 16 / 800
  /// Used on: P2 — e.g. "₵"
  static const TextStyle svgHeading16ExtraBold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// Plus Jakarta Sans 13 / 700
  /// Used on: P3 — e.g. "July 2026"
  static const TextStyle svgHeading13Bold = TextStyle(
    fontFamily: headingFamily,
    package: _package,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// Every style by name, for the design gallery and tests.
  static const Map<String, TextStyle> all = <String, TextStyle>{
    'body32Regular': body32Regular,
    'body30Regular': body30Regular,
    'body28Regular': body28Regular,
    'body24Regular': body24Regular,
    'body22Regular': body22Regular,
    'body20Regular': body20Regular,
    'body20ExtraBold': body20ExtraBold,
    'body18Regular': body18Regular,
    'body17Regular': body17Regular,
    'body16Regular': body16Regular,
    'body14Regular': body14Regular,
    'body14RegularH160': body14RegularH160,
    'body14Medium': body14Medium,
    'body14SemiBold': body14SemiBold,
    'body14Bold': body14Bold,
    'body13Regular': body13Regular,
    'body13Medium': body13Medium,
    'body13SemiBold': body13SemiBold,
    'body13Bold': body13Bold,
    'body12Regular': body12Regular,
    'body12RegularLs5': body12RegularLs5,
    'body12MediumH140': body12MediumH140,
    'body12Medium': body12Medium,
    'body12SemiBoldH133': body12SemiBoldH133,
    'body12SemiBoldH140': body12SemiBoldH140,
    'body12SemiBold': body12SemiBold,
    'body12SemiBoldLs4': body12SemiBoldLs4,
    'body12Bold': body12Bold,
    'body11Regular': body11Regular,
    'body11Medium': body11Medium,
    'body11SemiBold': body11SemiBold,
    'body11SemiBoldLs4': body11SemiBoldLs4,
    'body11BoldLs4': body11BoldLs4,
    'body11BoldLs5': body11BoldLs5,
    'body11Bold': body11Bold,
    'body11BoldLs6': body11BoldLs6,
    'body10RegularH140': body10RegularH140,
    'body10Regular': body10Regular,
    'body10RegularLs6': body10RegularLs6,
    'body10Medium': body10Medium,
    'body10SemiBold': body10SemiBold,
    'body10Bold': body10Bold,
    'body10BoldLs7': body10BoldLs7,
    'body10BoldLs6': body10BoldLs6,
    'body10BoldLs5': body10BoldLs5,
    'body9Regular': body9Regular,
    'body9RegularLs5': body9RegularLs5,
    'body9Bold': body9Bold,
    'heading42ExtraBoldH100': heading42ExtraBoldH100,
    'heading38ExtraBoldH100': heading38ExtraBoldH100,
    'heading38ExtraBold': heading38ExtraBold,
    'heading34ExtraBold': heading34ExtraBold,
    'heading32ExtraBold': heading32ExtraBold,
    'heading30ExtraBoldH100': heading30ExtraBoldH100,
    'heading28ExtraBoldH100': heading28ExtraBoldH100,
    'heading28ExtraBold': heading28ExtraBold,
    'heading26ExtraBoldH100': heading26ExtraBoldH100,
    'heading26ExtraBoldH120': heading26ExtraBoldH120,
    'heading26ExtraBold': heading26ExtraBold,
    'heading24ExtraBoldH120': heading24ExtraBoldH120,
    'heading24ExtraBold': heading24ExtraBold,
    'heading22ExtraBoldH100': heading22ExtraBoldH100,
    'heading22ExtraBold': heading22ExtraBold,
    'heading22BlackLs5': heading22BlackLs5,
    'heading20Bold': heading20Bold,
    'heading20ExtraBoldH100': heading20ExtraBoldH100,
    'heading20ExtraBold': heading20ExtraBold,
    'heading19ExtraBold': heading19ExtraBold,
    'heading18Bold': heading18Bold,
    'heading18ExtraBoldLsNeg0p3px': heading18ExtraBoldLsNeg0p3px,
    'heading18ExtraBold': heading18ExtraBold,
    'heading17SemiBoldLs1': heading17SemiBoldLs1,
    'heading17Bold': heading17Bold,
    'heading17ExtraBold': heading17ExtraBold,
    'heading16Bold': heading16Bold,
    'heading16ExtraBold': heading16ExtraBold,
    'heading15Bold': heading15Bold,
    'heading14Bold': heading14Bold,
    'heading14ExtraBoldH100': heading14ExtraBoldH100,
    'heading14ExtraBold': heading14ExtraBold,
    'heading13SemiBold': heading13SemiBold,
    'heading13Bold': heading13Bold,
    'heading12ExtraBold': heading12ExtraBold,
    'heading11Bold': heading11Bold,
    'heading10ExtraBold': heading10ExtraBold,
    'mono12BoldLs10': mono12BoldLs10,
    'mono11Regular': mono11Regular,
    'mono11BoldLs5': mono11BoldLs5,
    'svgBody16Regular': svgBody16Regular,
    'svgBody14Regular': svgBody14Regular,
    'svgBody13Regular': svgBody13Regular,
    'svgBody10Regular': svgBody10Regular,
    'svgBody10SemiBold': svgBody10SemiBold,
    'svgBody9Regular': svgBody9Regular,
    'svgBody9SemiBold': svgBody9SemiBold,
    'svgBody9Bold': svgBody9Bold,
    'svgBody8Regular': svgBody8Regular,
    'svgBody8Medium': svgBody8Medium,
    'svgBody8SemiBold': svgBody8SemiBold,
    'svgBody8Bold': svgBody8Bold,
    'svgBody7Bold': svgBody7Bold,
    'svgHeading16ExtraBold': svgHeading16ExtraBold,
    'svgHeading13Bold': svgHeading13Bold,
  };
}
