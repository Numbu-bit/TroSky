// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

/// Opacity values applied to whole elements (CSS `opacity`, SVG
/// `opacity`/`fill-opacity`/`stroke-opacity`/`stop-opacity`).
abstract final class TroskyOpacity {
  /// Disabled button: "Go Offline" while passengers are on board (D1).
  static const double disabled = 0.7;

  /// Taken seat (P7).
  static const double seatTaken = 0.6;

  /// 0 · A:Analytics
  static const double o0 = 0;

  /// 0.14 · A:Demand, A:Fleet, A:Overview
  static const double o14 = 0.14;

  /// 0.15 · P8, P9, A:Demand, A:Fleet, A:Overview, AcraMap
  static const double o15 = 0.15;

  /// 0.18 · A:Demand, A:Fleet, A:Overview
  static const double o18 = 0.18;

  /// 0.2 · P8, D1, D2, D3, A:Analytics
  static const double o20 = 0.2;

  /// 0.25 · AcraMap
  static const double o25 = 0.25;

  /// 0.3 · P1
  static const double o30 = 0.3;

  /// 0.4 · P1
  static const double o40 = 0.4;

  /// 0.45 · P6
  static const double o45 = 0.45;

  /// 0.5 · P1
  static const double o50 = 0.5;

  /// 0.6 · P7, P9
  static const double o60 = 0.6;

  /// 0.7 · P13, D1
  static const double o70 = 0.7;

  /// 0.8 · P1, P13
  static const double o80 = 0.8;

  /// 0.9 · P2, D6, BusPin
  static const double o90 = 0.9;

  /// 0.92 · A:Demand, A:Fleet, A:Overview
  static const double o92 = 0.92;

  /// 0.95 · P8, D1, D2, D3
  static const double o95 = 0.95;
}
