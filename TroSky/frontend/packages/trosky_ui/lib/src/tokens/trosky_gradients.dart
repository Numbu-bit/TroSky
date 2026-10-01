// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

import 'package:flutter/painting.dart';

import '../css/css_conversions.dart';
import 'trosky_colors.dart';

/// Every gradient in the Figma Make designs, converted with [cssLinearGradient]
/// so the CSS angle holds for any box size.
abstract final class TroskyGradients {
  /// Splash background
  /// `linear-gradient(160deg, #0A6E4C 0%, #0E9E6D 50%, #12B87E 100%)`
  static final LinearGradient splash = cssLinearGradient(160, [
    CssColorStop(TroskyColors.splashGreenDeep, 0),
    CssColorStop(TroskyColors.green, 50),
    CssColorStop(TroskyColors.splashGreenBright, 100),
  ]);

  /// Onboarding 1 background
  /// `linear-gradient(160deg, #0B7E57 0%, #0E9E6D 45%, #0d8a61 100%)`
  static final LinearGradient onboarding1 = cssLinearGradient(160, [
    CssColorStop(TroskyColors.greenDark, 0),
    CssColorStop(TroskyColors.green, 45),
    CssColorStop(TroskyColors.onboardingGreenEnd, 100),
  ]);

  /// Onboarding 2 background
  /// `linear-gradient(160deg, #12263B 0%, #1a3a5c 50%, #0d1f35 100%)`
  static final LinearGradient onboarding2 = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.navyHeaderEnd, 50),
    CssColorStop(TroskyColors.navyDeep, 100),
  ]);

  /// Onboarding 3 background
  /// `linear-gradient(160deg, #0d1f35 0%, #12263B 40%, #1a2840 100%)`
  static final LinearGradient onboarding3 = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navyDeep, 0),
    CssColorStop(TroskyColors.navy, 40),
    CssColorStop(TroskyColors.onboarding3NavyEnd, 100),
  ]);

  /// Sign up header (P4); receipt (D7) and favourite routes (P14) headers
  /// `linear-gradient(160deg, #0B7E57 0%, #0E9E6D 100%) · same as linear-gradient(160deg,#0B7E57,#0E9E6D)`
  static final LinearGradient greenHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.greenDark, 0),
    CssColorStop(TroskyColors.green, 100),
  ]);

  /// Home header (P5), driver home header (D1)
  /// `linear-gradient(180deg, var(--navy) 0%, #1a3a5c 100%)`
  static final LinearGradient navyHeader = cssLinearGradient(180, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.navyHeaderEnd, 100),
  ]);

  /// Seat selection header (P7)
  /// `linear-gradient(180deg, var(--navy) 0%, #1a3358 100%)`
  static final LinearGradient seatSelectionHeader = cssLinearGradient(180, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.seatHeaderNavyEnd, 100),
  ]);

  /// Profile headers (P11, D5)
  /// `linear-gradient(160deg, var(--navy) 0%, #1F3A5A 100%)`
  static final LinearGradient profileHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.navySlate, 100),
  ]);

  /// Trip history (P13) and withdrawal (D9) headers
  /// `linear-gradient(160deg,#12263B,#1D3A5B)`
  static final LinearGradient historyHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navy),
    CssColorStop(TroskyColors.historyNavyEnd),
  ]);

  /// Rate driver header (P16)
  /// `linear-gradient(160deg,#12263B,#1F3A5B)`
  static final LinearGradient rateDriverHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navy),
    CssColorStop(TroskyColors.rateDriverNavyEnd),
  ]);

  /// QR boarding header (P12)
  /// `linear-gradient(160deg,#12263B 0%,#1F6FB2 100%)`
  static final LinearGradient qrBoardingHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.blue, 100),
  ]);

  /// Wallet balance card (P9), earnings card (D4)
  /// `linear-gradient(135deg, #12263B 0%, #1F3A5A 60%, #1F6FB2 100%)`
  static final LinearGradient walletCard = cssLinearGradient(135, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.navySlate, 60),
    CssColorStop(TroskyColors.blue, 100),
  ]);

  /// Home promo card "Subscribe your commute" (P5)
  /// `linear-gradient(120deg, var(--navy) 0%, #1F6FB2 100%)`
  static final LinearGradient promoCard = cssLinearGradient(120, [
    CssColorStop(TroskyColors.navy, 0),
    CssColorStop(TroskyColors.blue, 100),
  ]);

  /// Initial avatars (admin drivers, D2, D6, D7, P12)
  /// `linear-gradient(135deg,#0E9E6D,#1F6FB2)`
  static final LinearGradient avatar = cssLinearGradient(135, [
    CssColorStop(TroskyColors.green),
    CssColorStop(TroskyColors.blue),
  ]);

  /// Amber initial avatars (D9, P16)
  /// `linear-gradient(135deg,#F4B333,#E8920A)`
  static final LinearGradient amberAvatar = cssLinearGradient(135, [
    CssColorStop(TroskyColors.amber),
    CssColorStop(TroskyColors.amberDeep),
  ]);

  /// Trip history spending summary card (P13)
  /// `linear-gradient(135deg,#0E9E6D,#0B7E57)`
  static final LinearGradient spendingSummary = cssLinearGradient(135, [
    CssColorStop(TroskyColors.green),
    CssColorStop(TroskyColors.greenDark),
  ]);

  /// SOS hold button (P15)
  /// `linear-gradient(135deg,#E23D3D,#C12B2B)`
  static final LinearGradient sos = cssLinearGradient(135, [
    CssColorStop(TroskyColors.red),
    CssColorStop(TroskyColors.redDark),
  ]);

  /// Incident report header (D8)
  /// `linear-gradient(160deg,#C12B2B,#E23D3D)`
  static final LinearGradient incidentHeader = cssLinearGradient(160, [
    CssColorStop(TroskyColors.redDark),
    CssColorStop(TroskyColors.red),
  ]);

  /// Ride accepted header (D2)
  /// `linear-gradient(180deg, #0B7E57 0%, var(--green) 100%)`
  static final LinearGradient rideAcceptedHeader = cssLinearGradient(180, [
    CssColorStop(TroskyColors.greenDark, 0),
    CssColorStop(TroskyColors.green, 100),
  ]);

  /// Demand map legend bar (admin)
  /// `linear-gradient(to right, rgba(14,158,109,0.6), #F4B333, #E23D3D)`
  static final LinearGradient demandLegend = cssLinearGradient(90, [
    CssColorStop(TroskyColors.greenA60),
    CssColorStop(TroskyColors.amber),
    CssColorStop(TroskyColors.red),
  ]);

  /// Admin login background
  /// `linear-gradient(160deg, #0d1a28 0%, #12263B 50%, #0a1820 100%)`
  static final LinearGradient adminLogin = cssLinearGradient(160, [
    CssColorStop(TroskyColors.adminLoginNavyStart, 0),
    CssColorStop(TroskyColors.navy, 50),
    CssColorStop(TroskyColors.adminLoginNavyEnd, 100),
  ]);

  /// Admin revenue chart area fill (SVG `<linearGradient>`, x1=0 y1=0 x2=0 y2=1)
  /// `<linearGradient x2="0" y2="1">: #0E9E6D @ 0.2 opacity at 5% → 0 at 95%`
  static final LinearGradient revenueArea = cssLinearGradient(180, [
    CssColorStop(TroskyColors.greenA20, 5),
    CssColorStop(TroskyColors.greenA00, 95),
  ]);

  /// Every token by name, for the design gallery and tests.
  static final Map<String, LinearGradient> all = <String, LinearGradient>{
    'splash': splash,
    'onboarding1': onboarding1,
    'onboarding2': onboarding2,
    'onboarding3': onboarding3,
    'greenHeader': greenHeader,
    'navyHeader': navyHeader,
    'seatSelectionHeader': seatSelectionHeader,
    'profileHeader': profileHeader,
    'historyHeader': historyHeader,
    'rateDriverHeader': rateDriverHeader,
    'qrBoardingHeader': qrBoardingHeader,
    'walletCard': walletCard,
    'promoCard': promoCard,
    'avatar': avatar,
    'amberAvatar': amberAvatar,
    'spendingSummary': spendingSummary,
    'sos': sos,
    'incidentHeader': incidentHeader,
    'rideAcceptedHeader': rideAcceptedHeader,
    'demandLegend': demandLegend,
    'adminLogin': adminLogin,
    'revenueArea': revenueArea,
  };
}
