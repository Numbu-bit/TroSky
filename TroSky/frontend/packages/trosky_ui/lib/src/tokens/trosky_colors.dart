// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

import 'dart:ui';

/// Every colour used by the Figma Make designs.
abstract final class TroskyColors {
  // Core palette (globals.css variables)
  /// `--green` · Primary brand green: primary buttons, active dots, links, available seats, map pins
  /// Used on: Splash, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, AcraMap
  static const Color green = Color(0xFF0E9E6D);

  /// `--green-dk` · Dark green: text on the white onboarding button, selected seat, green chip text, gradient dark ends
  /// Used on: P1, P4, P6, P7, P12, P13, P14, D2, D6, D7, D9, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, Chip
  static const Color greenDark = Color(0xFF0B7E57);

  /// `--blue` · Sky blue: "See all" links, promo and wallet gradient ends, info accents
  /// Used on: P5, P8, P9, P12, D2, D4, D6, D7, D8, A:Analytics, A:Drivers, A:Fraud, A:Overview, A:Reports
  static const Color blue = Color(0xFF1F6FB2);

  /// `--navy` · Deep navy: headers, onboarding 2–3 backgrounds, logo pin
  /// Used on: P2, P3, P5, P6, P7, P9, P10, P11, P12, P13, P16, D1, D2, D3, D4, D5, D6, D9, A:Demand, A:Fleet, A:Login, A:Shell
  static const Color navy = Color(0xFF12263B);

  /// `--ink` · Ink: headings and text on amber
  /// Used on: P1, P2, P3, P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports
  static const Color ink = Color(0xFF1D2027);

  /// `--amber` · Amber gold: onboarding-3 CTA, active page dot, "Try it", badges, "NEW FEATURE" label
  /// Used on: P1, P2, P3, P5, P6, P7, P8, P9, P10, P11, P15, P16, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Overview, A:Reports
  static const Color amber = Color(0xFFF4B333);

  /// `--red` · Error red: SOS button, errors, high-severity alerts
  /// Used on: P5, P6, P7, P8, P11, P13, P15, D2, D8, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell
  static const Color red = Color(0xFFE23D3D);

  /// `--success` · Success green (only used for one "₵" glyph in the wallet)
  /// Used on: P9
  static const Color success = Color(0xFF16A34A);

  /// `--txt` · Primary text (same value as ink)
  /// Used on: P1, P2, P3, P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports
  static const Color textPrimary = Color(0xFF1D2027);

  /// `--txt-2` · Secondary text, labels, placeholder text, icons
  /// Used on: P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, Chip
  static const Color textSecondary = Color(0xFF5B6472);

  /// `--border` · Input and card borders, dividers, inactive progress
  /// Used on: P4, P5, P6, P7, P9, P10, P11, P14, P16, D1, D2, D3, D4, D5, D8, D9, A:Analytics, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, Chip
  static const Color border = Color(0xFFE4E8EE);

  /// `--surface` · Cards, inputs, bottom sheets
  /// Used on: Splash, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell, AcraMap, BusPin
  static const Color surface = Color(0xFFFFFFFF);

  /// `--bg` · Screen background
  /// Used on: P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Demand, A:Drivers, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell
  static const Color background = Color(0xFFF5F7FA);

  /// `--green-lt` · Tinted backgrounds (same value as greenA12)
  /// Used on: D2, Chip
  static const Color greenLight = Color(0x1F0E9E6D);

  // Role aliases of core values
  /// White text and icons on dark or coloured backgrounds (CSS `white`)
  /// Used on: Splash, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell, AcraMap, BusPin
  static const Color white = Color(0xFFFFFFFF);

  /// Taken seat body (P7); same value as border
  /// Used on: P4, P5, P6, P7, P9, P10, P11, P14, P16, D1, D2, D3, D4, D5, D8, D9, A:Analytics, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, Chip
  static const Color seatTaken = Color(0xFFE4E8EE);

  /// CSS `transparent` (seat borders, tab backgrounds)
  /// Used on: P12, P13, D4, A:Drivers, A:Shell
  static const Color transparent = Color(0x00000000);

  // Solid colours found only in the screen code
  /// Splash gradient start
  /// Used on: Splash
  static const Color splashGreenDeep = Color(0xFF0A6E4C);

  /// Splash gradient end
  /// Used on: Splash
  static const Color splashGreenBright = Color(0xFF12B87E);

  /// Onboarding 1 gradient end
  /// Used on: P1
  static const Color onboardingGreenEnd = Color(0xFF0D8A61);

  /// Onboarding 1 illustration: bus wheels
  /// Used on: P1
  static const Color busWheel = Color(0xFF0A5E42);

  /// Onboarding 2 illustration: rider avatar
  /// Used on: P2
  static const Color riderMint = Color(0xFF7DD3B8);

  /// Onboarding 2 illustration: rider avatar
  /// Used on: P2
  static const Color riderSky = Color(0xFF89C4F0);

  /// Onboarding 2 illustration: rider avatar
  /// Used on: P2
  static const Color riderLavender = Color(0xFFC3A6F4);

  /// Navy header gradient end (Home, Driver home); Onboarding 2 gradient middle
  /// Used on: P2, P5, D1
  static const Color navyHeaderEnd = Color(0xFF1A3A5C);

  /// Seat selection header gradient end
  /// Used on: P7
  static const Color seatHeaderNavyEnd = Color(0xFF1A3358);

  /// Profile header gradient end; wallet and earnings card middle stop
  /// Used on: P9, P11, D4, D5
  static const Color navySlate = Color(0xFF1F3A5A);

  /// Trip history and withdrawal header gradient end
  /// Used on: P13, D9
  static const Color historyNavyEnd = Color(0xFF1D3A5B);

  /// Rate driver header gradient end
  /// Used on: P16
  static const Color rateDriverNavyEnd = Color(0xFF1F3A5B);

  /// Onboarding 2 gradient end, Onboarding 3 gradient start
  /// Used on: P2, P3
  static const Color navyDeep = Color(0xFF0D1F35);

  /// Onboarding 3 gradient end
  /// Used on: P3
  static const Color onboarding3NavyEnd = Color(0xFF1A2840);

  /// Admin login background gradient start
  /// Used on: A:Login
  static const Color adminLoginNavyStart = Color(0xFF0D1A28);

  /// Admin login background gradient end
  /// Used on: A:Login
  static const Color adminLoginNavyEnd = Color(0xFF0A1820);

  /// Live tracking dark map background (P8)
  /// Used on: P8
  static const Color mapNight = Color(0xFF13181F);

  /// SOS screen background (P15)
  /// Used on: P15
  static const Color sosBackground = Color(0xFF0D1117);

  /// QR scanner background (D6)
  /// Used on: D6
  static const Color scannerBackground = Color(0xFF0D1420);

  /// QR scanner result panel (D6)
  /// Used on: D6
  static const Color mintSurface = Color(0xFFF0F7F4);

  /// Red chip text, SOS gradient end, incident header gradient start
  /// Used on: P15, D8, A:Drivers, A:Fleet, A:Fraud, A:Reports, Chip
  static const Color redDark = Color(0xFFC12B2B);

  /// Blue chip text, favourite routes info text
  /// Used on: P14, Chip
  static const Color blueDark = Color(0xFF1557A0);

  /// Amber chip text, "idle/flagged/medium" status text, mid ratings
  /// Used on: P6, P7, P14, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Reports, Chip
  static const Color goldText = Color(0xFFB8860B);

  /// Incident report: passenger-count heading on amber
  /// Used on: D8
  static const Color amberTextDeep = Color(0xFF7A5F00);

  /// Incident report: notice text on amber
  /// Used on: D8
  static const Color amberTextMid = Color(0xFFA07A00);

  /// Amber avatar gradient end
  /// Used on: P16, D9
  static const Color amberDeep = Color(0xFFE8920A);

  /// Admin rating chart: 2★ slice
  /// Used on: A:Analytics
  static const Color ratingOrange = Color(0xFFE2924A);

  /// Admin detail labels (performance, documents)
  /// Used on: A:Drivers, A:Reports
  static const Color textBody = Color(0xFF3D4552);

  /// Muted captions (QR scanner captions, search results)
  /// Used on: P6, D6
  static const Color textMuted = Color(0xFFA0AAB4);

  /// List chevrons; ticket reference code (P12)
  /// Used on: P11, P12, D1
  static const Color chevron = Color(0xFFC0C8D2);

  /// Taken seat headrest (P7)
  /// Used on: P7
  static const Color seatTakenHeadrest = Color(0xFFB0B8C2);

  /// Taken seat cushion (P7)
  /// Used on: P7
  static const Color seatTakenCushion = Color(0xFFC4CDD6);

  /// Seat legend "Taken" swatch (P7)
  /// Used on: P7
  static const Color seatLegendTaken = Color(0xFFD0D7DF);

  /// QR card border and placeholder (P12)
  /// Used on: P12
  static const Color qrFrame = Color(0xFFE8EAF0);

  /// Admin list dividers
  /// Used on: A:Drivers, A:Reports
  static const Color dividerSubtle = Color(0xFFF0F2F5);

  /// "Share Trip Link" text on the dark SOS screen
  /// Used on: P15
  static const Color skyLink = Color(0xFF7ABDE8);

  /// MoMo logo text and fill (P9)
  /// Used on: P9
  static const Color black = Color(0xFF000000);

  /// MTN MoMo brand yellow (P9 logo, D9 payout option)
  /// Used on: P9, D9
  static const Color mtnYellow = Color(0xFFFFCC00);

  /// Telecel brand red (P9 logo)
  /// Used on: P9
  static const Color telecelRed = Color(0xFFE8001C);

  /// VISA brand navy (P9 logo)
  /// Used on: P9
  static const Color visaNavy = Color(0xFF1A1F71);

  // Translucent colours: base colour + alpha (A06 = 0.06)
  /// rgba(244,179,51,0.04)
  /// Used on: P2
  static const Color amberA04 = Color(0x0AF4B333);

  /// rgba(244,179,51,0.06)
  /// Used on: A:Fraud
  static const Color amberA06 = Color(0x0FF4B333);

  /// rgba(244,179,51,0.1)
  /// Used on: P10, D3, D8, A:Demand
  static const Color amberA10 = Color(0x1AF4B333);

  /// rgba(244,179,51,0.12)
  /// Used on: P11, P14, A:Drivers, A:Fleet, A:Fraud, A:Reports
  static const Color amberA12 = Color(0x1FF4B333);

  /// rgba(244,179,51,0.15)
  /// Used on: P6, P7, Chip
  static const Color amberA15 = Color(0x26F4B333);

  /// rgba(244,179,51,0.2)
  /// Used on: P11
  static const Color amberA20 = Color(0x33F4B333);

  /// rgba(244,179,51,0.25)
  /// Used on: P10
  static const Color amberA25 = Color(0x40F4B333);

  /// rgba(244,179,51,0.3)
  /// Used on: D8
  static const Color amberA30 = Color(0x4DF4B333);

  /// rgba(244,179,51,0.35)
  /// Used on: P3, D9
  static const Color amberA35 = Color(0x59F4B333);

  /// rgba(244,179,51,0.5)
  /// Used on: BusPin
  static const Color amberA50 = Color(0x80F4B333);

  /// rgba(0,0,0,0.04)
  /// Used on: P4
  static const Color blackA04 = Color(0x0A000000);

  /// rgba(0,0,0,0.05)
  /// Used on: P9, P10, P11, D1, D2, D4, D5, A:Drivers, A:Reports
  static const Color blackA05 = Color(0x0D000000);

  /// rgba(0,0,0,0.06)
  /// Used on: P6, P7, P14, D3, A:Analytics, A:Demand, A:Fleet, A:Fraud, A:Overview
  static const Color blackA06 = Color(0x0F000000);

  /// rgba(0,0,0,0.08)
  /// Used on: Splash, P1, P5, P7, P16, D2, D7
  static const Color blackA08 = Color(0x14000000);

  /// rgba(0,0,0,0.1)
  /// Used on: P12
  static const Color blackA10 = Color(0x1A000000);

  /// rgba(0,0,0,0.12)
  /// Used on: A:Analytics
  static const Color blackA12 = Color(0x1F000000);

  /// rgba(0,0,0,0.15)
  /// Used on: P5
  static const Color blackA15 = Color(0x26000000);

  /// rgba(0,0,0,0.2)
  /// Used on: P1, P5
  static const Color blackA20 = Color(0x33000000);

  /// rgba(0,0,0,0.25)
  /// Used on: Splash
  static const Color blackA25 = Color(0x40000000);

  /// rgba(0,0,0,0.3)
  /// Used on: D2
  static const Color blackA30 = Color(0x4D000000);

  /// rgba(0,0,0,0.4)
  /// Used on: A:Login
  static const Color blackA40 = Color(0x66000000);

  /// rgba(0,0,0,0.55)
  /// Used on: A:Demand, A:Fleet, A:Overview
  static const Color blackA55 = Color(0x8C000000);

  /// rgba(31,111,178,0.06)
  /// Used on: D2
  static const Color blueA06 = Color(0x0F1F6FB2);

  /// rgba(31,111,178,0.08)
  /// Used on: P14, D1, A:Reports
  static const Color blueA08 = Color(0x141F6FB2);

  /// rgba(31,111,178,0.1)
  /// Used on: P9, D1, A:Drivers
  static const Color blueA10 = Color(0x1A1F6FB2);

  /// rgba(31,111,178,0.12)
  /// Used on: Chip
  static const Color blueA12 = Color(0x1F1F6FB2);

  /// rgba(31,111,178,0.2)
  /// Used on: P15, D2
  static const Color blueA20 = Color(0x331F6FB2);

  /// rgba(31,111,178,0.25)
  /// Used on: D1
  static const Color blueA25 = Color(0x401F6FB2);

  /// rgba(31,111,178,0.3)
  /// Used on: P15
  static const Color blueA30 = Color(0x4D1F6FB2);

  /// rgba(14,158,109,0)
  /// Used on: A:Analytics
  static const Color greenA00 = Color(0x000E9E6D);

  /// rgba(14,158,109,0.04)
  /// Used on: P10, A:Drivers
  static const Color greenA04 = Color(0x0A0E9E6D);

  /// rgba(14,158,109,0.06)
  /// Used on: P7, A:Fraud
  static const Color greenA06 = Color(0x0F0E9E6D);

  /// rgba(14,158,109,0.07)
  /// Used on: P4, D1, D2
  static const Color greenA07 = Color(0x120E9E6D);

  /// rgba(14,158,109,0.08)
  /// Used on: P6, P13, D3, D4, D9, A:Reports
  static const Color greenA08 = Color(0x140E9E6D);

  /// rgba(14,158,109,0.1)
  /// Used on: P6, P9, P10, P12, P14, D1, D3, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports
  static const Color greenA10 = Color(0x1A0E9E6D);

  /// rgba(14,158,109,0.12)
  /// Used on: D2, Chip
  static const Color greenA12 = Color(0x1F0E9E6D);

  /// rgba(14,158,109,0.15)
  /// Used on: P4, P6, P15, D6
  static const Color greenA15 = Color(0x260E9E6D);

  /// rgba(14,158,109,0.18)
  /// Used on: D2
  static const Color greenA18 = Color(0x2E0E9E6D);

  /// rgba(14,158,109,0.2)
  /// Used on: D1, D6
  static const Color greenA20 = Color(0x330E9E6D);

  /// rgba(14,158,109,0.25)
  /// Used on: D1, D3, D6
  static const Color greenA25 = Color(0x400E9E6D);

  /// rgba(14,158,109,0.3)
  /// Used on: P6, P13, D3, D4, D6
  static const Color greenA30 = Color(0x4D0E9E6D);

  /// rgba(14,158,109,0.35)
  /// Used on: P4, P7, P10, D2, D6, A:Login
  static const Color greenA35 = Color(0x590E9E6D);

  /// rgba(14,158,109,0.4)
  /// Used on: P2, D1
  static const Color greenA40 = Color(0x660E9E6D);

  /// rgba(14,158,109,0.5)
  /// Used on: BusPin
  static const Color greenA50 = Color(0x800E9E6D);

  /// rgba(14,158,109,0.6)
  /// Used on: A:Demand
  static const Color greenA60 = Color(0x990E9E6D);

  /// rgba(14,158,109,0.85)
  /// Used on: P8
  static const Color greenA85 = Color(0xD90E9E6D);

  /// rgba(11,126,87,0.4)
  /// Used on: P7
  static const Color greenDarkA40 = Color(0x660B7E57);

  /// rgba(18,26,38,0.82)
  /// Used on: D1
  static const Color midnightA82 = Color(0xD1121A26);

  /// rgba(18,26,38,0.9)
  /// Used on: D3
  static const Color midnightA90 = Color(0xE6121A26);

  /// rgba(18,26,38,0.97)
  /// Used on: P8
  static const Color midnightA97 = Color(0xF7121A26);

  /// rgba(18,38,59,0.08)
  /// Used on: P10
  static const Color navyA08 = Color(0x1412263B);

  /// rgba(18,38,59,0.3)
  /// Used on: D4
  static const Color navyA30 = Color(0x4D12263B);

  /// rgba(18,38,59,0.35)
  /// Used on: P9
  static const Color navyA35 = Color(0x5912263B);

  /// rgba(18,38,59,0.6)
  /// Used on: D9
  static const Color navyA60 = Color(0x9912263B);

  /// rgba(18,38,59,0.7)
  /// Used on: D9
  static const Color navyA70 = Color(0xB312263B);

  /// rgba(18,38,59,0.92)
  /// Used on: P8
  static const Color navyA92 = Color(0xEB12263B);

  /// rgba(18,38,59,0.95)
  /// Used on: P9
  static const Color navyA95 = Color(0xF212263B);

  /// rgba(226,61,61,0.06)
  /// Used on: P11, A:Fraud
  static const Color redA06 = Color(0x0FE23D3D);

  /// rgba(226,61,61,0.07)
  /// Used on: P6
  static const Color redA07 = Color(0x12E23D3D);

  /// rgba(226,61,61,0.08)
  /// Used on: P13, D2, A:Drivers
  static const Color redA08 = Color(0x14E23D3D);

  /// rgba(226,61,61,0.1)
  /// Used on: A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Reports
  static const Color redA10 = Color(0x1AE23D3D);

  /// rgba(226,61,61,0.12)
  /// Used on: P6, Chip
  static const Color redA12 = Color(0x1FE23D3D);

  /// rgba(226,61,61,0.15)
  /// Used on: P11
  static const Color redA15 = Color(0x26E23D3D);

  /// rgba(226,61,61,0.2)
  /// Used on: P15
  static const Color redA20 = Color(0x33E23D3D);

  /// rgba(226,61,61,0.25)
  /// Used on: D2
  static const Color redA25 = Color(0x40E23D3D);

  /// rgba(226,61,61,0.35)
  /// Used on: P15
  static const Color redA35 = Color(0x59E23D3D);

  /// rgba(226,61,61,0.4)
  /// Used on: D1
  static const Color redA40 = Color(0x66E23D3D);

  /// rgba(226,61,61,0.45)
  /// Used on: P8
  static const Color redA45 = Color(0x73E23D3D);

  /// rgba(226,61,61,0.5)
  /// Used on: P5, P15
  static const Color redA50 = Color(0x80E23D3D);

  /// rgba(226,61,61,0.9)
  /// Used on: D1
  static const Color redA90 = Color(0xE6E23D3D);

  /// rgba(90,100,114,0.85)
  /// Used on: D1
  static const Color slateA85 = Color(0xD95A6472);

  /// rgba(255,255,255,0.04)
  /// Used on: P9
  static const Color whiteA04 = Color(0x0AFFFFFF);

  /// rgba(255,255,255,0.05)
  /// Used on: P2
  static const Color whiteA05 = Color(0x0DFFFFFF);

  /// rgba(255,255,255,0.06)
  /// Used on: Splash, P1, P8, P9, P15, D3, D4, D6, A:Shell
  static const Color whiteA06 = Color(0x0FFFFFFF);

  /// rgba(255,255,255,0.07)
  /// Used on: Splash, P8
  static const Color whiteA07 = Color(0x12FFFFFF);

  /// rgba(255,255,255,0.08)
  /// Used on: Splash, P1, P2, P3, P6, P8, P9, P15, D1, D6
  static const Color whiteA08 = Color(0x14FFFFFF);

  /// rgba(255,255,255,0.1)
  /// Used on: Splash, P2, P3, P5, P6, P7, P15, D1, A:Shell
  static const Color whiteA10 = Color(0x1AFFFFFF);

  /// rgba(255,255,255,0.12)
  /// Used on: P1, P2, P3, P5, P6, P11, P12, P13, P15, D5, D6
  static const Color whiteA12 = Color(0x1FFFFFFF);

  /// rgba(255,255,255,0.15)
  /// Used on: P1, P8, D2
  static const Color whiteA15 = Color(0x26FFFFFF);

  /// rgba(255,255,255,0.2)
  /// Used on: P2, P8, P11, P14, D5
  static const Color whiteA20 = Color(0x33FFFFFF);

  /// rgba(255,255,255,0.25)
  /// Used on: P2, P3, P7
  static const Color whiteA25 = Color(0x40FFFFFF);

  /// rgba(255,255,255,0.3)
  /// Used on: P1, P3, P5
  static const Color whiteA30 = Color(0x4DFFFFFF);

  /// rgba(255,255,255,0.35)
  /// Used on: Splash, P7, D6, A:Shell
  static const Color whiteA35 = Color(0x59FFFFFF);

  /// rgba(255,255,255,0.4)
  /// Used on: P2, P3, P9, P15, D4, D6
  static const Color whiteA40 = Color(0x66FFFFFF);

  /// rgba(255,255,255,0.45)
  /// Used on: P8, D6, A:Login
  static const Color whiteA45 = Color(0x73FFFFFF);

  /// rgba(255,255,255,0.5)
  /// Used on: P2, P6, P8, P9, P10, P15, D1, D3, D4, D5, D6, A:Shell
  static const Color whiteA50 = Color(0x80FFFFFF);

  /// rgba(255,255,255,0.55)
  /// Used on: Splash, P2, P3, P5, P7, P11
  static const Color whiteA55 = Color(0x8CFFFFFF);

  /// rgba(255,255,255,0.6)
  /// Used on: P2, P5, P6, P12, P16, D2, D6, D9
  static const Color whiteA60 = Color(0x99FFFFFF);

  /// rgba(255,255,255,0.65)
  /// Used on: P1, P2, P3
  static const Color whiteA65 = Color(0xA6FFFFFF);

  /// rgba(255,255,255,0.7)
  /// Used on: P2, P4, P7, P15, D2, D7
  static const Color whiteA70 = Color(0xB3FFFFFF);

  /// rgba(255,255,255,0.72)
  /// Used on: P1
  static const Color whiteA72 = Color(0xB8FFFFFF);

  /// rgba(255,255,255,0.75)
  /// Used on: P14, D8
  static const Color whiteA75 = Color(0xBFFFFFFF);

  /// rgba(255,255,255,0.8)
  /// Used on: P9, D6
  static const Color whiteA80 = Color(0xCCFFFFFF);

  /// rgba(255,255,255,0.85)
  /// Used on: Splash, P1, P6, D1
  static const Color whiteA85 = Color(0xD9FFFFFF);

  /// rgba(255,255,255,0.9)
  /// Used on: P5
  static const Color whiteA90 = Color(0xE6FFFFFF);

  /// rgba(255,255,255,0.95)
  /// Used on: P1
  static const Color whiteA95 = Color(0xF2FFFFFF);

  // Accent + hex alpha 18 (`${color}18` in the TSX, 0x18 = 9.4 %)
  /// Icon tiles and selected options tinted with the accent colour + hex alpha 18 (admin KPIs and stat cards, incident type)
  static const Color greenTint18 = Color(0x180E9E6D);

  /// Same pattern, blue accent
  static const Color blueTint18 = Color(0x181F6FB2);

  /// Same pattern, amber accent
  static const Color amberTint18 = Color(0x18F4B333);

  /// Same pattern, red accent
  static const Color redTint18 = Color(0x18E23D3D);

  /// Every token by name, for the design gallery and tests.
  static const Map<String, Color> all = <String, Color>{
    'green': green,
    'greenDark': greenDark,
    'blue': blue,
    'navy': navy,
    'ink': ink,
    'amber': amber,
    'red': red,
    'success': success,
    'textPrimary': textPrimary,
    'textSecondary': textSecondary,
    'border': border,
    'surface': surface,
    'background': background,
    'white': white,
    'seatTaken': seatTaken,
    'splashGreenDeep': splashGreenDeep,
    'splashGreenBright': splashGreenBright,
    'onboardingGreenEnd': onboardingGreenEnd,
    'busWheel': busWheel,
    'riderMint': riderMint,
    'riderSky': riderSky,
    'riderLavender': riderLavender,
    'navyHeaderEnd': navyHeaderEnd,
    'seatHeaderNavyEnd': seatHeaderNavyEnd,
    'navySlate': navySlate,
    'historyNavyEnd': historyNavyEnd,
    'rateDriverNavyEnd': rateDriverNavyEnd,
    'navyDeep': navyDeep,
    'onboarding3NavyEnd': onboarding3NavyEnd,
    'adminLoginNavyStart': adminLoginNavyStart,
    'adminLoginNavyEnd': adminLoginNavyEnd,
    'mapNight': mapNight,
    'sosBackground': sosBackground,
    'scannerBackground': scannerBackground,
    'mintSurface': mintSurface,
    'redDark': redDark,
    'blueDark': blueDark,
    'goldText': goldText,
    'amberTextDeep': amberTextDeep,
    'amberTextMid': amberTextMid,
    'amberDeep': amberDeep,
    'ratingOrange': ratingOrange,
    'textBody': textBody,
    'textMuted': textMuted,
    'chevron': chevron,
    'seatTakenHeadrest': seatTakenHeadrest,
    'seatTakenCushion': seatTakenCushion,
    'seatLegendTaken': seatLegendTaken,
    'qrFrame': qrFrame,
    'dividerSubtle': dividerSubtle,
    'skyLink': skyLink,
    'black': black,
    'mtnYellow': mtnYellow,
    'telecelRed': telecelRed,
    'visaNavy': visaNavy,
    'greenLight': greenLight,
    'transparent': transparent,
    'amberA04': amberA04,
    'amberA06': amberA06,
    'amberA10': amberA10,
    'amberA12': amberA12,
    'amberA15': amberA15,
    'amberA20': amberA20,
    'amberA25': amberA25,
    'amberA30': amberA30,
    'amberA35': amberA35,
    'amberA50': amberA50,
    'blackA04': blackA04,
    'blackA05': blackA05,
    'blackA06': blackA06,
    'blackA08': blackA08,
    'blackA10': blackA10,
    'blackA12': blackA12,
    'blackA15': blackA15,
    'blackA20': blackA20,
    'blackA25': blackA25,
    'blackA30': blackA30,
    'blackA40': blackA40,
    'blackA55': blackA55,
    'blueA06': blueA06,
    'blueA08': blueA08,
    'blueA10': blueA10,
    'blueA12': blueA12,
    'blueA20': blueA20,
    'blueA25': blueA25,
    'blueA30': blueA30,
    'greenA00': greenA00,
    'greenA04': greenA04,
    'greenA06': greenA06,
    'greenA07': greenA07,
    'greenA08': greenA08,
    'greenA10': greenA10,
    'greenA12': greenA12,
    'greenA15': greenA15,
    'greenA18': greenA18,
    'greenA20': greenA20,
    'greenA25': greenA25,
    'greenA30': greenA30,
    'greenA35': greenA35,
    'greenA40': greenA40,
    'greenA50': greenA50,
    'greenA60': greenA60,
    'greenA85': greenA85,
    'greenDarkA40': greenDarkA40,
    'midnightA82': midnightA82,
    'midnightA90': midnightA90,
    'midnightA97': midnightA97,
    'navyA08': navyA08,
    'navyA30': navyA30,
    'navyA35': navyA35,
    'navyA60': navyA60,
    'navyA70': navyA70,
    'navyA92': navyA92,
    'navyA95': navyA95,
    'redA06': redA06,
    'redA07': redA07,
    'redA08': redA08,
    'redA10': redA10,
    'redA12': redA12,
    'redA15': redA15,
    'redA20': redA20,
    'redA25': redA25,
    'redA35': redA35,
    'redA40': redA40,
    'redA45': redA45,
    'redA50': redA50,
    'redA90': redA90,
    'slateA85': slateA85,
    'whiteA04': whiteA04,
    'whiteA05': whiteA05,
    'whiteA06': whiteA06,
    'whiteA07': whiteA07,
    'whiteA08': whiteA08,
    'whiteA10': whiteA10,
    'whiteA12': whiteA12,
    'whiteA15': whiteA15,
    'whiteA20': whiteA20,
    'whiteA25': whiteA25,
    'whiteA30': whiteA30,
    'whiteA35': whiteA35,
    'whiteA40': whiteA40,
    'whiteA45': whiteA45,
    'whiteA50': whiteA50,
    'whiteA55': whiteA55,
    'whiteA60': whiteA60,
    'whiteA65': whiteA65,
    'whiteA70': whiteA70,
    'whiteA72': whiteA72,
    'whiteA75': whiteA75,
    'whiteA80': whiteA80,
    'whiteA85': whiteA85,
    'whiteA90': whiteA90,
    'whiteA95': whiteA95,
    'greenTint18': greenTint18,
    'blueTint18': blueTint18,
    'amberTint18': amberTint18,
    'redTint18': redTint18,
  };
}
