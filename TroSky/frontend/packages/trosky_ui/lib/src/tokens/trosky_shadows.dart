// Values extracted from the Figma Make code in design/figma-make/src/designs.
// docs/design-tokens.md lists every token with its role and the screens using it.

import 'package:flutter/painting.dart';

import '../css/css_conversions.dart';
import 'trosky_colors.dart';

/// Every box shadow in the Figma Make designs, converted with [cssBoxShadow].
abstract final class TroskyShadows {
  /// Standard white card (admin drivers/reports, D2, D4, D5, P9, P10, P11)
  /// `0 2px 12px rgba(0,0,0,0.05)`
  static final List<BoxShadow> card = [
    cssBoxShadow(0, 2, 12, TroskyColors.blackA05),
  ];

  /// Card (D3, P6, P7 booked counter)
  /// `0 2px 12px rgba(0,0,0,0.06)`
  static final List<BoxShadow> cardSubtle = [
    cssBoxShadow(0, 2, 12, TroskyColors.blackA06),
  ];

  /// Admin dashboard cards; favourite routes card (P14)
  /// `0 2px 16px rgba(0,0,0,0.06)`
  static final List<BoxShadow> adminCard = [
    cssBoxShadow(0, 2, 16, TroskyColors.blackA06),
  ];

  /// Driver home stat tiles (D1)
  /// `0 2px 10px rgba(0,0,0,0.05)`
  static final List<BoxShadow> driverStatTile = [
    cssBoxShadow(0, 2, 10, TroskyColors.blackA05),
  ];

  /// Phone number input (P4)
  /// `0 2px 8px rgba(0,0,0,0.04)`
  static final List<BoxShadow> input = [
    cssBoxShadow(0, 2, 8, TroskyColors.blackA04),
  ];

  /// Green form CTA: Send OTP (P4), Sign In (admin), Accept Trip (D2), Book (P7), Subscribe (P10)
  /// `0 6px 20px rgba(14,158,109,0.35)`
  static final List<BoxShadow> primaryButton = [
    cssBoxShadow(0, 6, 20, TroskyColors.greenA35),
  ];

  /// White "Next" button (P1)
  /// `0 8px 24px rgba(0,0,0,0.2)`
  static final List<BoxShadow> onboardingLightButton = [
    cssBoxShadow(0, 8, 24, TroskyColors.blackA20),
  ];

  /// Green "Next" button (P2)
  /// `0 8px 24px rgba(14,158,109,0.4)`
  static final List<BoxShadow> onboardingGreenButton = [
    cssBoxShadow(0, 8, 24, TroskyColors.greenA40),
  ];

  /// "Get Started" (P3); withdrawal amber card (D9)
  /// `0 8px 24px rgba(244,179,51,0.35)`
  static final List<BoxShadow> amberButton = [
    cssBoxShadow(0, 8, 24, TroskyColors.amberA35),
  ];

  /// "Go Online" button (D1)
  /// `0 6px 20px rgba(14,158,109,0.4)`
  static final List<BoxShadow> goOnlineButton = [
    cssBoxShadow(0, 6, 20, TroskyColors.greenA40),
  ];

  /// "Go Offline" button (D1)
  /// `0 6px 20px rgba(226,61,61,0.4)`
  static final List<BoxShadow> goOfflineButton = [
    cssBoxShadow(0, 6, 20, TroskyColors.redA40),
  ];

  /// "Complete Trip" button (D3)
  /// `0 4px 16px rgba(14,158,109,0.3)`
  static final List<BoxShadow> completeTripButton = [
    cssBoxShadow(0, 4, 16, TroskyColors.greenA30),
  ];

  /// Selected seat (P7)
  /// `0 4px 16px rgba(11,126,87,0.4)`
  static final List<BoxShadow> seatSelected = [
    cssBoxShadow(0, 4, 16, TroskyColors.greenDarkA40),
  ];

  /// White logo card on the splash
  /// `0 24px 64px rgba(0,0,0,0.25)`
  static final List<BoxShadow> splashLogoCard = [
    cssBoxShadow(0, 24, 64, TroskyColors.blackA25),
  ];

  /// Bottom sheet / fare panel (P5, P7)
  /// `0 -4px 20px rgba(0,0,0,0.08)`
  static final List<BoxShadow> bottomSheet = [
    cssBoxShadow(0, -4, 20, TroskyColors.blackA08),
  ];

  /// Home search bar on the navy header (P5)
  /// `0 4px 16px rgba(0,0,0,0.2)`
  static final List<BoxShadow> searchBar = [
    cssBoxShadow(0, 4, 16, TroskyColors.blackA20),
  ];

  /// My-location map button (P5)
  /// `0 2px 10px rgba(0,0,0,0.15)`
  static final List<BoxShadow> mapFab = [
    cssBoxShadow(0, 2, 10, TroskyColors.blackA15),
  ];

  /// Map SOS button (P5)
  /// `0 4px 16px rgba(226,61,61,0.5)`
  static final List<BoxShadow> sosButton = [
    cssBoxShadow(0, 4, 16, TroskyColors.redA50),
  ];

  /// SOS button on live tracking (P8)
  /// `0 4px 16px rgba(226,61,61,0.45)`
  static final List<BoxShadow> liveTrackingSos = [
    cssBoxShadow(0, 4, 16, TroskyColors.redA45),
  ];

  /// SOS hold button glow (P15)
  /// `0 0 40px rgba(226,61,61,0.5)`
  static final List<BoxShadow> sosHoldGlow = [
    cssBoxShadow(0, 0, 40, TroskyColors.redA50),
  ];

  /// Seat map card (P7)
  /// `0 4px 24px rgba(0,0,0,0.08)`
  static final List<BoxShadow> seatMapCard = [
    cssBoxShadow(0, 4, 24, TroskyColors.blackA08),
  ];

  /// Receipt card (D7), rate driver card (P16)
  /// `0 8px 24px rgba(0,0,0,0.08)`
  static final List<BoxShadow> receiptCard = [
    cssBoxShadow(0, 8, 24, TroskyColors.blackA08),
  ];

  /// QR ticket card (P12)
  /// `0 8px 32px rgba(0,0,0,0.1)`
  static final List<BoxShadow> qrCard = [
    cssBoxShadow(0, 8, 32, TroskyColors.blackA10),
  ];

  /// Wallet balance card (P9)
  /// `0 12px 40px rgba(18,38,59,0.35)`
  static final List<BoxShadow> walletCard = [
    cssBoxShadow(0, 12, 40, TroskyColors.navyA35),
  ];

  /// Earnings card (D4)
  /// `0 12px 40px rgba(18,38,59,0.3)`
  static final List<BoxShadow> earningsCard = [
    cssBoxShadow(0, 12, 40, TroskyColors.navyA30),
  ];

  /// Spending summary card (P13)
  /// `0 8px 24px rgba(14,158,109,0.3)`
  static final List<BoxShadow> spendingSummary = [
    cssBoxShadow(0, 8, 24, TroskyColors.greenA30),
  ];

  /// Verify Ghana Card card (P11)
  /// `0 2px 12px rgba(244,179,51,0.12)`
  static final List<BoxShadow> verifyCard = [
    cssBoxShadow(0, 2, 12, TroskyColors.amberA12),
  ];

  /// Active trip card (D1)
  /// `0 4px 20px rgba(14,158,109,0.1)`
  static final List<BoxShadow> tripActiveCard = [
    cssBoxShadow(0, 4, 20, TroskyColors.greenA10),
  ];

  /// QR boarding active card (D1)
  /// `0 4px 20px rgba(31,111,178,0.08)`
  static final List<BoxShadow> qrBoardingCard = [
    cssBoxShadow(0, 4, 20, TroskyColors.blueA08),
  ];

  /// Driver boarding QR card (D2)
  /// `0 6px 24px rgba(0,0,0,0.08)`
  static final List<BoxShadow> driverQrCard = [
    cssBoxShadow(0, 6, 24, TroskyColors.blackA08),
  ];

  /// "Passengers scan this to board" card (D2)
  /// `0 2px 12px rgba(14,158,109,0.12)`
  static final List<BoxShadow> boardingHintCard = [
    cssBoxShadow(0, 2, 12, TroskyColors.greenA12),
  ];

  /// Incoming request card header (D2)
  /// `0 4px 16px rgba(0,0,0,0.3)`
  static final List<BoxShadow> incomingRequestHeader = [
    cssBoxShadow(0, 4, 16, TroskyColors.blackA30),
  ];

  /// Incoming request card (D2)
  /// `0 4px 20px rgba(0,0,0,0.08)`
  static final List<BoxShadow> incomingRequestCard = [
    cssBoxShadow(0, 4, 20, TroskyColors.blackA08),
  ];

  /// Admin chart tooltips
  /// `0 8px 24px rgba(0,0,0,0.12)`
  static final List<BoxShadow> chartTooltip = [
    cssBoxShadow(0, 8, 24, TroskyColors.blackA12),
  ];

  /// Admin login card
  /// `0 40px 80px rgba(0,0,0,0.4)`
  static final List<BoxShadow> adminLoginCard = [
    cssBoxShadow(0, 40, 80, TroskyColors.blackA40),
  ];

  /// Map bus pin (CSS filter drop-shadow)
  /// `0 3px 6px rgba(14,158,109,0.5)`
  static final List<BoxShadow> busPinGreen = [
    cssBoxShadow(0, 3, 6, TroskyColors.greenA50),
  ];

  /// Map bus pin, amber (CSS filter drop-shadow)
  /// `0 3px 6px rgba(244,179,51,0.5)`
  static final List<BoxShadow> busPinAmber = [
    cssBoxShadow(0, 3, 6, TroskyColors.amberA50),
  ];

  // Blurs. CSS blur(Npx) and backdrop-filter: blur(Npx) take a standard
  // deviation, so N is the sigma directly.

  /// Splash glow blob: `filter: blur(40px)`.
  static const double splashGlowBlurSigma = 40;

  /// Frosted panels over the driver map (D1, D3): `backdrop-filter: blur(8px)`.
  static const double backdropBlurSigma8 = 8;

  /// Live tracking overlay (P8): `backdrop-filter: blur(12px)`.
  static const double backdropBlurSigma12 = 12;

  /// Live tracking bottom panel (P8): `backdrop-filter: blur(20px)`.
  static const double backdropBlurSigma20 = 20;

  /// Every shadow token by name, for the design gallery and tests.
  static final Map<String, List<BoxShadow>> all = <String, List<BoxShadow>>{
    'card': card,
    'cardSubtle': cardSubtle,
    'adminCard': adminCard,
    'driverStatTile': driverStatTile,
    'input': input,
    'primaryButton': primaryButton,
    'onboardingLightButton': onboardingLightButton,
    'onboardingGreenButton': onboardingGreenButton,
    'amberButton': amberButton,
    'goOnlineButton': goOnlineButton,
    'goOfflineButton': goOfflineButton,
    'completeTripButton': completeTripButton,
    'seatSelected': seatSelected,
    'splashLogoCard': splashLogoCard,
    'bottomSheet': bottomSheet,
    'searchBar': searchBar,
    'mapFab': mapFab,
    'sosButton': sosButton,
    'liveTrackingSos': liveTrackingSos,
    'sosHoldGlow': sosHoldGlow,
    'seatMapCard': seatMapCard,
    'receiptCard': receiptCard,
    'qrCard': qrCard,
    'walletCard': walletCard,
    'earningsCard': earningsCard,
    'spendingSummary': spendingSummary,
    'verifyCard': verifyCard,
    'tripActiveCard': tripActiveCard,
    'qrBoardingCard': qrBoardingCard,
    'driverQrCard': driverQrCard,
    'boardingHintCard': boardingHintCard,
    'incomingRequestHeader': incomingRequestHeader,
    'incomingRequestCard': incomingRequestCard,
    'chartTooltip': chartTooltip,
    'adminLoginCard': adminLoginCard,
    'busPinGreen': busPinGreen,
    'busPinAmber': busPinAmber,
  };
}
