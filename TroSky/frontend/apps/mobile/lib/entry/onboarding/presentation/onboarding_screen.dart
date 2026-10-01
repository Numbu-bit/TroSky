import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../data/onboarding_store.dart';
import 'widgets/onboarding_illustrations.dart';

/// S-02 Onboarding, from `P1_Onboarding1`, `P2_Onboarding2` and
/// `P3_Onboarding3` in PassengerDesigns.tsx.
///
/// The illustration and text swipe in a [PageView]. Skip, the dots and the
/// button stay put, and the backgrounds cross-fade as the pages move.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _leaving = false;

  static const int _count = 3;

  /// Height of the design's drawn status bar (`StatusBar`, 48 px). A taller
  /// real status bar wins.
  static const double _statusBarHeight = 48;

  /// `pb-2` under Skip and `pb-6` under the button. A taller system inset at
  /// the bottom (e.g. three-button navigation) wins over the 24.
  static const double _skipBottom = TroskySpacing.s8;
  static const double _bottom = TroskySpacing.s24;

  double get _page {
    final page = _pages.hasClients ? _pages.page : null;
    return (page ?? _index.toDouble()).clamp(0, _count - 1).toDouble();
  }

  void _goTo(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      // The design has no page transition; this borrows the dots'
      // `transition: all 0.3s` (ease).
      _pages.animateToPage(
        index,
        duration: TroskyMotion.transition300,
        curve: TroskyMotion.ease,
      );
    }
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await ref.read(onboardingStoreProvider).markSeen();
    } on Object {
      // A failed save only means onboarding shows again next launch; it
      // must not keep the user here.
    }
    if (mounted) context.goNamed(AppRoute.signUp.name);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final top = math.max(_statusBarHeight, media.viewPadding.top);
    final bottom = math.max(_bottom, media.viewPadding.bottom);
    final skipStyle = TroskyTypography.body13Medium;
    final skipLine =
        media.textScaler.scale(skipStyle.fontSize!) * skipStyle.height!;
    final last = _index == _count - 1;

    final pages = [
      _OnboardingPage(
        illustration: const OnboardingIllustration.page1(),
        floatDelay: Duration.zero,
        title: l10n.onboarding1Title,
        body: l10n.onboarding1Body,
        bodyColor: TroskyColors.whiteA72,
      ),
      _OnboardingPage(
        illustration: const OnboardingIllustration.page2(),
        floatDelay: TroskyMotion.floatDelayOnboarding2,
        title: l10n.onboarding2Title,
        body: l10n.onboarding2Body,
        bodyColor: TroskyColors.whiteA65,
      ),
      _OnboardingPage(
        illustration: const OnboardingIllustration.page3(),
        floatDelay: TroskyMotion.floatDelayOnboarding3,
        title: l10n.onboarding3Title,
        body: l10n.onboarding3Body,
        bodyColor: TroskyColors.whiteA65,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: PopScope(
        // Back steps through the pages; on the first page it leaves the app.
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goTo(_index - 1);
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _pages,
                builder: (context, _) => _CrossFade(
                  key: const ValueKey('onboarding-backgrounds'),
                  page: _page,
                  layers: [
                    for (final gradient in [
                      TroskyGradients.onboarding1,
                      TroskyGradients.onboarding2,
                      TroskyGradients.onboarding3,
                    ])
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: gradient),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  SizedBox(height: top + skipLine + _skipBottom),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (index) => setState(() => _index = index),
                      children: pages,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TroskySpacing.s28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageDots.onboarding(
                          index: _index,
                          inactiveColor: _index == 0
                              ? TroskyColors.whiteA30
                              : TroskyColors.whiteA25,
                          semanticsLabel: l10n.onboardingPageOf(
                            _index + 1,
                            _count,
                          ),
                        ),
                        const SizedBox(height: TroskySpacing.s24),
                        TroskyButton(
                          label: last
                              ? l10n.onboardingGetStarted
                              : l10n.onboardingNext,
                          variant: [
                            TroskyButtonVariant.onboardingLight,
                            TroskyButtonVariant.onboardingGreen,
                            TroskyButtonVariant.amber,
                          ][_index],
                          onPressed: last ? _finish : () => _goTo(_index + 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: bottom),
                ],
              ),
              // Skip keeps the design's text position; its 48 dp tap area
              // spreads left of and around the text.
              Positioned(
                top: top + skipLine / 2 - 24,
                right: TroskySpacing.s24,
                child: AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) => SkipText(
                    label: l10n.onboardingSkip,
                    alignment: Alignment.centerRight,
                    color: Color.lerp(
                      TroskyColors.whiteA65,
                      TroskyColors.whiteA55,
                      _page.clamp(0, 1),
                    )!,
                    onPressed: _finish,
                  ),
                ),
              ),
              // The design's circles are `position: absolute`, so the browser
              // paints them over the text, dots and button.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) => _CrossFade(
                    page: _page,
                    fadeOutBelow: true,
                    layers: const [
                      DecorativeBackdrop.onboarding1(),
                      DecorativeBackdrop.onboarding2(),
                      SizedBox.expand(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page: the floating illustration in the space left over, then the
/// heading and text.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.illustration,
    required this.floatDelay,
    required this.title,
    required this.body,
    required this.bodyColor,
  });

  final Widget illustration;
  final Duration floatDelay;
  final String title;
  final String body;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s24),
            child: Center(
              child: TroskyFloat(delay: floatDelay, child: illustration),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TroskyTypography.heading26ExtraBoldH120.copyWith(
                    color: TroskyColors.white,
                  ),
                ),
              ),
              const SizedBox(height: TroskySpacing.s10),
              Text(
                body,
                style: TroskyTypography.body14RegularH160.copyWith(
                  color: bodyColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TroskySpacing.s28),
      ],
    );
  }
}

/// Fades from `layers[floor(page)]` to the next layer as [page] moves
/// between them. Opaque layers only need the upper one faded in; see-through
/// layers ([fadeOutBelow]) also fade the lower one out.
class _CrossFade extends StatelessWidget {
  const _CrossFade({
    super.key,
    required this.page,
    required this.layers,
    this.fadeOutBelow = false,
  });

  final double page;
  final List<Widget> layers;
  final bool fadeOutBelow;

  @override
  Widget build(BuildContext context) {
    final below = page.floor().clamp(0, layers.length - 1);
    final t = page - below;
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: fadeOutBelow ? 1 - t : 1, child: layers[below]),
        if (t > 0 && below + 1 < layers.length)
          Opacity(
            key: const ValueKey('onboarding-fade-in'),
            opacity: t,
            child: layers[below + 1],
          ),
      ],
    );
  }
}
