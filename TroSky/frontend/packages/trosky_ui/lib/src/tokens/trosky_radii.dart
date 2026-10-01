// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

/// Every corner radius in the Figma Make designs, in logical pixels.
abstract final class TroskyRadii {
  /// 2px · P5, P8, D1
  static const double r2 = 2;

  /// 3px · D5, A:Demand, A:Drivers, A:Fleet, A:Overview, A:Reports
  static const double r3 = 3;

  /// 4px · P1, P2, P3, P6, P7, P10, P15, A:Reports
  static const double r4 = 4;

  /// 6px · P7, P13, A:Drivers, A:Reports
  static const double r6 = 6;

  /// 8px · P6, P10, P11, P14, D1, D4, D6, D9, A:Drivers, A:Reports
  static const double r8 = 8;

  /// 10px · P9, P10, P12, P13, P14, P15, P16, D1, D2, D3, D4, D9, A:Drivers, A:Shell
  static const double r10 = 10;

  /// 12px · P4, P6, P7, P9, P10, P13, P15, D1, D6, A:Analytics, A:Fleet, A:Login, A:Overview, A:Reports, A:Shell
  static const double r12 = 12;

  /// 13px · D9
  static const double r13 = 13;

  /// 14px · P4, P5, P8, P13, P14, P15, D1, D2, D6, D7, D8, D9, A:Demand, A:Fleet, A:Login, A:Overview
  static const double r14 = 14;

  /// 16px · P5, P6, P7, P8, P10, P11, P12, P13, P16, D1, D2, D7, D8, D9, A:Drivers, A:Reports
  static const double r16 = 16;

  /// 18px · P11, D1, D2
  static const double r18 = 18;

  /// 20px · P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports
  static const double r20 = 20;

  /// 22px · D2, D6
  static const double r22 = 22;

  /// 24px · P7, P9, P12, D4, A:Login
  static const double r24 = 24;

  /// 25px · P8, D1, D3
  static const double r25 = 25;

  /// 26px · P7, D2
  static const double r26 = 26;

  /// 27px · P1, P2, P3, P4, P10
  static const double r27 = 27;

  /// 32px · Splash
  static const double r32 = 32;

  // SVG rx values that only occur in illustrations
  /// 1 · SVG rx · P12
  static const double r1 = 1;

  /// 1.25 · SVG rx · P9
  static const double r1p25 = 1.25;

  /// 7 · SVG rx · BusPin
  static const double r7 = 7;

  /// Pills and circles: CSS `border-radius: 50%` on a square and Tailwind
  /// `rounded-full` (9999px).
  static const double full = 9999;

  /// Every radius by name, for the design gallery and tests.
  static const Map<String, double> all = <String, double>{
    'r2': r2,
    'r3': r3,
    'r4': r4,
    'r6': r6,
    'r8': r8,
    'r10': r10,
    'r12': r12,
    'r13': r13,
    'r14': r14,
    'r16': r16,
    'r18': r18,
    'r20': r20,
    'r22': r22,
    'r24': r24,
    'r25': r25,
    'r26': r26,
    'r27': r27,
    'r32': r32,
    'r1': r1,
    'r1p25': r1p25,
    'r7': r7,
    'full': full,
  };
}
