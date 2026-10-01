import 'package:flutter/widgets.dart';

import '../tokens/trosky_colors.dart';
import '../tokens/trosky_motion.dart';

/// Row of page indicator dots: 8 px dots 8 px apart, the active one drawn as
/// a wider pill.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
    this.activeWidth = 24,
    this.semanticsLabel,
  }) : assert(index >= 0 && index < count, 'index must be within count');

  /// Onboarding (P1–P3): 24 px amber pill. Onboarding 1 uses
  /// [TroskyColors.whiteA30] for inactive dots, Onboarding 2 and 3 use
  /// [TroskyColors.whiteA25].
  const PageDots.onboarding({
    super.key,
    this.count = 3,
    required this.index,
    this.inactiveColor = TroskyColors.whiteA30,
    this.semanticsLabel,
  }) : activeColor = TroskyColors.amber,
       activeWidth = 24,
       assert(index >= 0 && index < count, 'index must be within count');

  /// Splash loading dots: 8 px circles, white active and 35 % white inactive.
  const PageDots.splash({
    super.key,
    this.count = 3,
    this.index = 0,
    this.semanticsLabel,
  }) : activeColor = TroskyColors.white,
       inactiveColor = TroskyColors.whiteA35,
       activeWidth = 8,
       assert(index >= 0 && index < count, 'index must be within count');

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;
  final double activeWidth;

  /// What a screen reader hears. Pass a localized "Page 1 of 3"; the
  /// English default is for previews and tests.
  final String? semanticsLabel;

  static const double _size = 8;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            // `transition: all 0.3s` from Onboarding 1.
            AnimatedContainer(
              duration: TroskyMotion.transition300,
              curve: TroskyMotion.ease,
              width: i == index ? activeWidth : _size,
              height: _size,
              decoration: BoxDecoration(
                color: i == index ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(_size / 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
