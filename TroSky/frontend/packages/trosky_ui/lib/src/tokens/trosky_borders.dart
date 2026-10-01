// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

/// Border widths used by CSS borders in the designs.
abstract final class TroskyBorders {
  /// 1px · Splash, P1, P2, P4, P5, P6, P8, P9, P10, P11, P12, P14, P15, P16, D1, D2, D3, D4, D5, D6, D8, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell
  static const double w1 = 1;

  /// 1.5px · P4, P6, P10, P11, D1, D2, D3, D8, D9, A:Login
  static const double w1p5 = 1.5;

  /// 2px · P5, P7, P10, P11, P15, D5, D6
  static const double w2 = 2;

  /// 2.5px · P7
  static const double w2p5 = 2.5;

  /// 3px · D1, D6
  static const double w3 = 3;

  /// 4px · D2
  static const double w4 = 4;
}
