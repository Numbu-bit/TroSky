// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

/// Every padding, margin and gap value in the Figma Make designs, in logical
/// pixels (Tailwind classes converted at 4px per unit). Negative values are
/// margins that pull an element up.
abstract final class TroskySpacing {
  /// -16px · P12, D7, D9
  static const double sneg16 = -16;

  /// -14px · P16
  static const double sneg14 = -14;

  /// -12px · P13
  static const double sneg12 = -12;

  /// -8px · P5
  static const double sneg8 = -8;

  /// -1px · P4
  static const double sneg1 = -1;

  /// 0px · P4, P5, P7, P8, P12, P13, P14, P16, D1, D2, D6, D7, D8, D9, A:Demand, A:Fleet, A:Fraud, A:Login, A:Overview
  static const double s0 = 0;

  /// 1px · P6, P7, P10, P12, P13, P15, D1, D6, A:Overview
  static const double s1 = 1;

  /// 2px · P5, P6, P7, P8, P10, P11, P12, P13, P14, P15, D1, D2, D3, D5, D6, D7, D8, D9, A:Drivers, A:Overview, A:Reports, A:Shell, Chip
  static const double s2 = 2;

  /// 3px · P6, P7, P8, P15, D4, D6, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports
  static const double s3 = 3;

  /// 4px · P4, P6, P7, P9, P11, P12, P13, P15, P16, D1, D2, D4, D5, D6, D7, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell
  static const double s4 = 4;

  /// 5px · P6, P11, P15, D4, A:Drivers
  static const double s5 = 5;

  /// 6px · Splash, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, D1, D2, D3, D4, D6, D8, A:Demand, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell
  static const double s6 = 6;

  /// 7px · D2
  static const double s7 = 7;

  /// 8px · Splash, P1, P2, P3, P4, P5, P6, P7, P8, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell
  static const double s8 = 8;

  /// 9px · D3, A:Drivers, A:Reports
  static const double s9 = 9;

  /// 10px · P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell, Chip
  static const double s10 = 10;

  /// 11px · P11, D2, D9, A:Shell
  static const double s11 = 11;

  /// 12px · P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell
  static const double s12 = 12;

  /// 13px · P14, D9
  static const double s13 = 13;

  /// 14px · P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell
  static const double s14 = 14;

  /// 16px · P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell
  static const double s16 = 16;

  /// 18px · P7, P8, P13, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Overview, A:Reports
  static const double s18 = 18;

  /// 20px · P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D2, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell
  static const double s20 = 20;

  /// 22px · P9
  static const double s22 = 22;

  /// 24px · Splash, P1, P2, P3, P4, P11, P12, P13, P14, P15, P16, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Fleet, A:Fraud, A:Overview
  static const double s24 = 24;

  /// 28px · P1, P2, P3, P4, P12, P15, D1, A:Drivers, A:Login, A:Reports
  static const double s28 = 28;

  /// 32px · Splash, A:Drivers, A:Login, A:Reports, A:Shell
  static const double s32 = 32;

  /// 36px · A:Drivers, A:Reports, A:Shell
  static const double s36 = 36;

  /// Every spacing value by name, for the design gallery and tests.
  static const Map<String, double> all = <String, double>{
    'sneg16': sneg16,
    'sneg14': sneg14,
    'sneg12': sneg12,
    'sneg8': sneg8,
    'sneg1': sneg1,
    's0': s0,
    's1': s1,
    's2': s2,
    's3': s3,
    's4': s4,
    's5': s5,
    's6': s6,
    's7': s7,
    's8': s8,
    's9': s9,
    's10': s10,
    's11': s11,
    's12': s12,
    's13': s13,
    's14': s14,
    's16': s16,
    's18': s18,
    's20': s20,
    's22': s22,
    's24': s24,
    's28': s28,
    's32': s32,
    's36': s36,
  };
}
