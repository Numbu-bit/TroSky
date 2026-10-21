@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// Serves `packages/trosky_ui/...` asset keys from disk. A package's own
/// tests only bundle its assets without that prefix. Other keys, such as
/// the asset manifest images look up, come from the test bundle.
class _PackageAssetBundle extends CachingAssetBundle {
  static const _prefix = 'packages/trosky_ui/';

  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith(_prefix)) return rootBundle.load(key);
    final bytes = await File(key.substring(_prefix.length)).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

const _frame = ValueKey('golden-frame');

/// Pumps [child] in a [width] wide frame, shrink-wrapped to its height, and
/// compares it with `goldens/<name>.png`.
///
/// flutter_test draws shadows unblurred by default (`debugDisableShadows`);
/// the goldens switch that off so they show the CSS-matched blur. SVGs decode
/// asynchronously, hence runAsync.
Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget child, {
  double width = 312,
  Color background = TroskyColors.background,
  Gradient? gradient,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);
  debugDisableShadows = false;
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PackageAssetBundle(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: TroskyTheme.light(),
            home: Material(
              type: MaterialType.transparency,
              child: Align(
                alignment: Alignment.topLeft,
                // The golden captures this boundary, not the whole view.
                child: RepaintBoundary(
                  key: _frame,
                  child: Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: gradient == null ? background : null,
                      gradient: gradient,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [child],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // Advance far enough for the loading spinner to show an arc.
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byKey(_frame),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The four states of one button variant, stacked.
Widget _buttonStates(TroskyButtonVariant variant, {Widget? leading}) {
  void tap() {}
  final states = <Widget>[
    TroskyButton(
      label: 'Enabled',
      variant: variant,
      onPressed: tap,
      leading: leading,
    ),
    TroskyButton(
      label: 'Pressed',
      variant: variant,
      onPressed: tap,
      pressed: true,
      leading: leading,
    ),
    TroskyButton(
      label: 'Disabled',
      variant: variant,
      onPressed: null,
      leading: leading,
    ),
    TroskyButton(
      label: 'Loading',
      variant: variant,
      onPressed: tap,
      loading: true,
    ),
  ];
  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
    child: Column(
      children: [
        for (final state in states) ...[state, const SizedBox(height: 28)],
      ],
    ),
  );
}

void main() {
  group('TroskyButton', () {
    testWidgets('onboardingLight on Onboarding 1', (tester) async {
      await _golden(
        tester,
        'trosky_button_onboarding_light',
        _buttonStates(TroskyButtonVariant.onboardingLight),
        gradient: TroskyGradients.onboarding1,
      );
    });

    testWidgets('onboardingGreen on Onboarding 2', (tester) async {
      await _golden(
        tester,
        'trosky_button_onboarding_green',
        _buttonStates(TroskyButtonVariant.onboardingGreen),
        gradient: TroskyGradients.onboarding2,
      );
    });

    testWidgets('amber on Onboarding 3', (tester) async {
      await _golden(
        tester,
        'trosky_button_amber',
        _buttonStates(TroskyButtonVariant.amber),
        gradient: TroskyGradients.onboarding3,
      );
    });

    testWidgets('primary on Sign Up', (tester) async {
      await _golden(
        tester,
        'trosky_button_primary',
        _buttonStates(TroskyButtonVariant.primary),
      );
    });

    testWidgets('outline with the email icon on Sign Up', (tester) async {
      await _golden(
        tester,
        'trosky_button_outline',
        _buttonStates(
          TroskyButtonVariant.outline,
          leading: TroskyIcons.mail(color: TroskyColors.textPrimary),
        ),
      );
    });
  });

  testWidgets('PageDots: onboarding pages and splash', (tester) async {
    Widget row(Gradient gradient, Widget dots) => Container(
      height: 40,
      decoration: BoxDecoration(gradient: gradient),
      alignment: Alignment.center,
      child: dots,
    );
    await _golden(
      tester,
      'page_dots',
      Column(
        children: [
          row(TroskyGradients.onboarding1, const PageDots.onboarding(index: 0)),
          row(
            TroskyGradients.onboarding2,
            const PageDots.onboarding(
              index: 1,
              inactiveColor: TroskyColors.whiteA25,
            ),
          ),
          row(
            TroskyGradients.onboarding3,
            const PageDots.onboarding(
              index: 2,
              inactiveColor: TroskyColors.whiteA25,
            ),
          ),
          row(TroskyGradients.splash, const PageDots.splash()),
        ],
      ),
    );
  });

  testWidgets('SkipText on Onboarding 1 and 2', (tester) async {
    await _golden(
      tester,
      'skip_text',
      Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: TroskyGradients.onboarding1),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkipText(onPressed: () {}),
          ),
          Container(
            decoration: BoxDecoration(gradient: TroskyGradients.onboarding2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkipText(onPressed: () {}, color: TroskyColors.whiteA55),
          ),
        ],
      ),
    );
  });

  group('DecorativeBackdrop', () {
    Widget screen(Gradient gradient, Widget backdrop) => SizedBox(
      height: 686,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: backdrop,
      ),
    );

    testWidgets('splash', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_splash',
        screen(TroskyGradients.splash, const DecorativeBackdrop.splash()),
      );
    });

    testWidgets('onboarding 1', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_onboarding1',
        screen(
          TroskyGradients.onboarding1,
          const DecorativeBackdrop.onboarding1(),
        ),
      );
    });

    testWidgets('onboarding 2', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_onboarding2',
        screen(
          TroskyGradients.onboarding2,
          const DecorativeBackdrop.onboarding2(),
        ),
      );
    });
  });

  testWidgets('TroskyChip: every colour', (tester) async {
    await _golden(
      tester,
      'trosky_chip',
      const Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TroskyChip(label: 'Green', color: TroskyChipColor.green),
            TroskyChip(label: 'Amber', color: TroskyChipColor.amber),
            TroskyChip(label: 'Gray', color: TroskyChipColor.gray),
            TroskyChip(label: 'Red', color: TroskyChipColor.red),
            TroskyChip(label: 'Blue', color: TroskyChipColor.blue),
          ],
        ),
      ),
      background: TroskyColors.surface,
    );
  });

  testWidgets('SectionLabel', (tester) async {
    await _golden(
      tester,
      'section_label',
      const Padding(
        padding: EdgeInsets.all(24),
        child: SectionLabel('PHONE NUMBER'),
      ),
    );
  });

  testWidgets('TroskyLogo: bright on the splash card, and the mark', (
    tester,
  ) async {
    await _golden(
      tester,
      'trosky_logo',
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Splash logo card: white, radius 32, padding 24 x 32.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                color: TroskyColors.surface,
                borderRadius: BorderRadius.circular(TroskyRadii.r32),
                boxShadow: TroskyShadows.splashLogoCard,
              ),
              child: const TroskyLogo.bright(),
            ),
            const SizedBox(height: 40),
            // The heights the designs use: 20 (P15), 28 and 36 (admin).
            const TroskyLogo.mark(height: 20),
            const SizedBox(height: 16),
            const TroskyLogo.mark(height: 28),
            const SizedBox(height: 16),
            const TroskyLogo.mark(height: 36),
          ],
        ),
      ),
      gradient: TroskyGradients.splash,
    );
  });

  testWidgets('Auth header (P4) with and without the back button', (
    tester,
  ) async {
    await _golden(
      tester,
      'auth_header',
      Column(
        children: [
          const TroskyAuthHeader(
            title: 'Welcome to TroSky',
            subtitle: 'Your journey. On time. Every time.',
          ),
          TroskyAuthHeader(
            title: 'Your details',
            subtitle: 'A few more details to create your account.',
            onBack: () {},
          ),
        ],
      ),
    );
  });

  testWidgets('Form fields: phone, plain, error, helper, divider, note, '
      'links, checklist, code', (tester) async {
    await _golden(
      tester,
      'form_fields',
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('PHONE NUMBER'),
            const SizedBox(height: 8),
            TroskyInputField(
              controller: TextEditingController(),
              label: 'PHONE NUMBER',
              hintText: 'XX XXX XXXX',
              prefix: const TroskyPhonePrefix(),
            ),
            const SizedBox(height: 16),
            TroskyInputField(
              controller: TextEditingController(text: 'Efua Owusu'),
              label: 'FULL NAME',
            ),
            const SizedBox(height: 16),
            TroskyInputField(
              controller: TextEditingController(text: 'efua@yahoo.com'),
              label: 'EMAIL',
              errorText: 'Use your Gmail address (@gmail.com).',
            ),
            const SizedBox(height: 16),
            TroskyInputField(
              controller: TextEditingController(),
              label: 'EMAIL',
              hintText: 'you@gmail.com',
              helperText: 'Use your Gmail address',
            ),
            const SizedBox(height: 16),
            const TroskyTextDivider('or continue with'),
            const SizedBox(height: 16),
            const TroskyInfoNote(
              emoji: '🪪',
              before: 'Optionally verify your ',
              highlight: 'Ghana Card',
              after: ' for extra trust and higher wallet limits.',
            ),
            TroskyTextLink(
              prompt: 'Already have an account?',
              action: 'Sign in',
              onPressed: () {},
            ),
            const TroskyChecklist(
              items: [
                ('At least 8 characters', true),
                ('An upper-case letter', false),
              ],
            ),
            const SizedBox(height: 16),
            TroskyOtpInput(
              controller: TextEditingController(text: '123'),
              label: '6-digit code',
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('Tab bar (D1): Home selected, then Wallet', (tester) async {
    const items = [
      TroskyTabItem(emoji: '🏠', label: 'Home'),
      TroskyTabItem(emoji: '🗺️', label: 'Trips'),
      TroskyTabItem(emoji: '💰', label: 'Wallet'),
      TroskyTabItem(emoji: '👤', label: 'Profile'),
    ];
    await _golden(
      tester,
      'tab_bar',
      Column(
        children: [
          TroskyTabBar(items: items, currentIndex: 0, onSelected: (_) {}),
          const SizedBox(height: 16),
          TroskyTabBar(items: items, currentIndex: 2, onSelected: (_) {}),
        ],
      ),
      width: 360,
    );
  });

  testWidgets('Map markers (P5): bus pins, location dot, buttons', (
    tester,
  ) async {
    await _golden(
      tester,
      'map_markers',
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TroskyBusPin(seats: 5),
                TroskyBusPin(seats: 12),
                TroskyBusPin(seats: 2, amber: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const TroskyLocationDot(),
                TroskyMyLocationButton(
                  semanticsLabel: 'My location',
                  onPressed: () {},
                ),
                TroskySosButton(
                  label: 'SOS',
                  semanticsLabel: 'SOS',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
      width: 360,
    );
  });

  testWidgets('Home sheet parts (P5): search bar, chips, promo, skeleton', (
    tester,
  ) async {
    await _golden(
      tester,
      'home_components',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(gradient: TroskyGradients.navyHeader),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: TroskySearchBar(
              hint: 'Where are you going?',
              trailing: 'Now',
              onPressed: () {},
            ),
          ),
          Container(
            color: TroskyColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TroskySheetHandle(),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TroskyRouteChip(label: 'Madina → Circle'),
                    TroskyRouteChip(label: 'Legon → Osu'),
                    TroskyRouteChip(label: 'Achimota → Tema'),
                    TroskyRouteChip(label: 'Kaneshie → Lapaz'),
                  ],
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  children: [
                    TroskySkeleton(width: 110, height: 34, radius: 20),
                    TroskySkeleton(width: 90, height: 34, radius: 20),
                  ],
                ),
                const SizedBox(height: 14),
                TroskyPromoBanner(
                  eyebrow: 'NEW FEATURE',
                  title: 'Subscribe your commute',
                  body: 'Save up to 40% with a monthly plan',
                  action: 'Try it',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
      width: 360,
    );
  });

  testWidgets('Search results parts (P6): header buttons, banner, pills, '
      'cards, dashed button', (tester) async {
    await _golden(
      tester,
      'search_components',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: TroskyColors.navy,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                TroskyHeaderIconButton(
                  semanticsLabel: 'Back',
                  onPressed: () {},
                  child: TroskyIcons.back(color: TroskyColors.white),
                ),
                const Spacer(),
                TroskyHeaderIconButton(
                  semanticsLabel: 'Save route',
                  onPressed: () {},
                  child: TroskyIcons.star(color: TroskyColors.white),
                ),
                TroskyHeaderIconButton(
                  semanticsLabel: 'Saved',
                  selected: true,
                  onPressed: () {},
                  child: TroskyIcons.star(
                    color: TroskyColors.amber,
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          TroskyInfoBanner(
            text: 'Showing vehicles still approaching your stop',
            action: 'Show all',
            onAction: () {},
          ),
          Container(
            color: TroskyColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in const [
                  'Now',
                  'Schedule',
                  'Cheapest',
                  'Fastest',
                  'Minibus',
                ].indexed)
                  TroskyFilterPill(
                    label: label,
                    selected: i == 0 || i == 2,
                    onPressed: () {},
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TroskyTripCard(
                  title: 'Minibus',
                  plate: 'GR-4821',
                  tag: 'BEST MATCH',
                  highlighted: true,
                  times: 'Departs 07:15 · ETA 08:05',
                  seatsLabel: '5 seats',
                  seatsColor: TroskyChipColor.green,
                  badge: '~3 min away · approaching your stop',
                  fare: const TroskyTripFare(
                    price: '₵14',
                    soloPrice: '₵38',
                    saving: 'Save 63%',
                  ),
                  onPressed: () {},
                ),
                const SizedBox(height: 10),
                TroskyTripCard(
                  title: 'Saloon Car',
                  plate: 'GT 4402-26',
                  times: 'Departs 07:22 · ETA 08:10',
                  seatsLabel: '2 seats',
                  seatsColor: TroskyChipColor.amber,
                  badge: 'Board at Accra Madina · 350 m away',
                  badgeKind: TroskyTripBadgeKind.boardAt,
                  fare: const TroskyTripFare(price: '₵8'),
                  onPressed: () {},
                ),
                const SizedBox(height: 10),
                const TroskyTripCard(
                  title: 'Minibus',
                  plate: 'GR-3406',
                  times: 'Departs 08:00 · ETA 08:50',
                  seatsLabel: 'Full',
                  seatsColor: TroskyChipColor.gray,
                ),
                const SizedBox(height: 10),
                const TroskyTripCard(
                  title: 'Minibus',
                  plate: 'GR-1190',
                  times: 'Departs 06:58 · ETA 07:48',
                  seatsLabel: 'Passed',
                  seatsColor: TroskyChipColor.gray,
                  passed: true,
                  passedNote: 'Already passed your stop — unavailable',
                ),
                const SizedBox(height: 10),
                TroskyDashedButton(
                  label: 'Show 2 vehicles that already passed your stop',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
      width: 360,
    );
  });

  testWidgets('Seat selection parts (P7): counter, cab, legend, seats, '
      'button', (tester) async {
    await _golden(
      tester,
      'seat_components',
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TroskyBookedCounter(
              booked: 5,
              total: 14,
              suffix: '/14 booked',
              semanticsLabel: '5 of 14 seats booked',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: TroskyColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: TroskyShadows.seatMapCard,
              ),
              child: Column(
                children: [
                  const TroskyVehicleCab(plate: 'GR-4821'),
                  const SizedBox(height: 16),
                  const TroskySeatLegend(
                    available: 'Available',
                    taken: 'Taken',
                    selected: 'Selected',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TroskySeat(
                        number: '1',
                        state: TroskySeatState.available,
                        semanticsLabel: 'Seat 1',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      const TroskySeat(
                        number: '2',
                        state: TroskySeatState.taken,
                        semanticsLabel: 'Seat 2, taken',
                      ),
                      const SizedBox(width: 8),
                      const TroskySeatAisle(),
                      const SizedBox(width: 8),
                      TroskySeat(
                        number: '3',
                        state: TroskySeatState.selected,
                        semanticsLabel: 'Seat 3, selected',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      TroskySeat(
                        number: '14',
                        state: TroskySeatState.available,
                        semanticsLabel: 'Seat 14',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TroskyButton(
              label: 'Select Seats to Continue',
              variant: TroskyButtonVariant.seatCta,
              onPressed: null,
            ),
            const SizedBox(height: 16),
            TroskyButton(
              label: 'Reserve 2 Seats · ₵28.00',
              variant: TroskyButtonVariant.seatCta,
              onPressed: () {},
            ),
          ],
        ),
      ),
      width: 360,
    );
  });

  testWidgets('Payment parts (P-07): header, banners, trip cards, pulse, '
      'countdown, tile, outline pill', (tester) async {
    // The pulse stands still, as drawn.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    const facts = [
      TroskyTripFact('Vehicle', 'GR 1234-24'),
      TroskyTripFact('Seats', 'B3 & B4'),
      TroskyTripFact('Total', '₵16.00', valueColor: TroskyColors.greenDark),
    ];
    await _golden(
      tester,
      'booking_status',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TroskyPageHeader(
            title: 'Payment',
            subtitle: 'Review and confirm your booking',
            onBack: () {},
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TroskyStatusBanner(
                  text: 'Driver accepted your booking',
                  tone: TroskyStatusTone.success,
                ),
                const SizedBox(height: 12),
                const TroskyStatusBanner(
                  text:
                      "The driver didn't respond, so we moved you to another "
                      'vehicle.',
                  tone: TroskyStatusTone.info,
                ),
                const SizedBox(height: 18),
                const TroskyTripSummaryCard(
                  from: 'Madina',
                  to: 'Circle',
                  day: 'Today',
                  time: '07:15',
                  facts: facts,
                ),
                const SizedBox(height: 18),
                const TroskyTripSummaryCard(
                  from: 'Madina',
                  to: 'Circle',
                  day: 'Today',
                  time: '07:30',
                  previousTime: '07:15',
                  tag: 'New vehicle assigned',
                  highlighted: true,
                  facts: [
                    TroskyTripFact('Vehicle', 'GR 5678-23'),
                    TroskyTripFact('Seats', 'C1 & C2'),
                    TroskyTripFact(
                      'Total',
                      '₵16.00',
                      valueColor: TroskyColors.greenDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TroskyPulseDot(),
                    TroskyStatusTile(icon: _NotAccepted()),
                  ],
                ),
                const SizedBox(height: 24),
                const TroskyCountdown(
                  time: '1:42',
                  caption: '2-minute response window',
                ),
                const SizedBox(height: 24),
                TroskyButton(
                  label: 'Cancel request',
                  variant: TroskyButtonVariant.outlinePill,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
      width: 390,
    );
  });
}

class _NotAccepted extends StatelessWidget {
  const _NotAccepted();

  @override
  Widget build(BuildContext context) =>
      TroskyIcons.bookingNotAccepted(color: TroskyColors.textSecondary);
}
