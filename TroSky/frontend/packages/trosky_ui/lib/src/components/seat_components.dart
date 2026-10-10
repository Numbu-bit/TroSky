import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_motion.dart';
import '../tokens/trosky_opacity.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';

/// What a seat on the seat map shows.
enum TroskySeatState { available, taken, selected }

/// A seat on Seat Selection (P7): 56 × 60, radius 12, a headrest over a
/// cushion. Green when free, with its number; dark green with an amber
/// border, a glow and a tick when selected; grey at 60 % with 👤 when taken.
class TroskySeat extends StatelessWidget {
  const TroskySeat({
    super.key,
    required this.number,
    required this.state,
    required this.semanticsLabel,
    this.onPressed,
  });

  final String number;
  final TroskySeatState state;
  final String semanticsLabel;

  /// Null for a taken seat: it can't be tapped.
  final VoidCallback? onPressed;

  static const Size size = Size(56, 60);

  @override
  Widget build(BuildContext context) {
    final taken = state == TroskySeatState.taken;
    final selected = state == TroskySeatState.selected;
    final seat = AnimatedContainer(
      // `transition: all 0.2s`
      duration: TroskyMotion.transition200,
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: taken
            ? TroskyColors.seatTaken
            : selected
            ? TroskyColors.greenDark
            : TroskyColors.green,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
        border: Border.all(
          color: selected ? TroskyColors.amber : TroskyColors.transparent,
          width: selected ? TroskyBorders.w2p5 : TroskyBorders.w2,
        ),
        boxShadow: selected ? TroskyShadows.seatSelected : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // `border-radius: 50% 50% 0 0` on 28 × 8: a half-ellipse top.
          Container(
            width: 28,
            height: 8,
            decoration: BoxDecoration(
              color: taken
                  ? TroskyColors.seatTakenHeadrest
                  : TroskyColors.whiteA35,
              borderRadius: const BorderRadius.vertical(
                top: Radius.elliptical(14, 8),
              ),
            ),
          ),
          const SizedBox(height: TroskySpacing.s2),
          Container(
            width: 36,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: taken
                  ? TroskyColors.seatTakenCushion
                  : TroskyColors.whiteA25,
              borderRadius: BorderRadius.circular(TroskyRadii.r6),
            ),
            child: switch (state) {
              TroskySeatState.taken => const Text(
                '👤',
                textScaler: TextScaler.noScaling,
                style: TroskyTypography.body14Regular,
              ),
              TroskySeatState.selected => TroskyIcons.check(
                color: TroskyColors.white,
              ),
              TroskySeatState.available => Text(
                number,
                maxLines: 1,
                // Part of the drawing: it must fit the cushion.
                textScaler: TextScaler.noScaling,
                style: TroskyTypography.heading11Bold.copyWith(
                  color: TroskyColors.white,
                ),
              ),
            },
          ),
        ],
      ),
    );
    return Semantics(
      button: !taken,
      enabled: !taken,
      selected: selected,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: taken
            ? Opacity(opacity: TroskyOpacity.seatTaken, child: seat)
            : seat,
      ),
    );
  }
}

/// The aisle between seats (P7): 20 px wide with a 1 × 50 line.
class TroskySeatAisle extends StatelessWidget {
  const TroskySeatAisle({super.key});

  static const double width = 20;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Center(
      child: Container(width: 1, height: 50, color: TroskyColors.border),
    ),
  );
}

/// Available / Taken / Selected, under the cab (P7).
class TroskySeatLegend extends StatelessWidget {
  const TroskySeatLegend({
    super.key,
    required this.available,
    required this.taken,
    required this.selected,
  });

  final String available;
  final String taken;
  final String selected;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label, {bool amberBorder = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(TroskyRadii.r4),
            border: amberBorder
                ? Border.all(color: TroskyColors.amber, width: TroskyBorders.w2)
                : null,
          ),
        ),
        const SizedBox(width: TroskySpacing.s6),
        Text(
          label,
          style: TroskyTypography.body11Medium.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: TroskySpacing.s16,
      runSpacing: TroskySpacing.s6,
      children: [
        item(TroskyColors.green, available),
        item(TroskyColors.seatLegendTaken, taken),
        item(TroskyColors.greenDark, selected, amberBorder: true),
      ],
    );
  }
}

/// The front of the vehicle on the seat map (P7): a 72 × 36 navy cab,
/// rounded on top, with 🚌 and the [plate].
class TroskyVehicleCab extends StatelessWidget {
  const TroskyVehicleCab({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s8),
      decoration: const BoxDecoration(
        color: TroskyColors.navy,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TroskyRadii.r20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🚌',
            textScaler: TextScaler.noScaling,
            style: TroskyTypography.body14Regular,
          ),
          const SizedBox(width: TroskySpacing.s6),
          Text(
            plate,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TroskyTypography.body10SemiBold.copyWith(
              color: TroskyColors.whiteA70,
            ),
          ),
        ],
      ),
    );
  }
}

/// "5/14 booked" with one bar per seat, the booked ones green (P7).
class TroskyBookedCounter extends StatelessWidget {
  const TroskyBookedCounter({
    super.key,
    required this.booked,
    required this.total,
    required this.suffix,
    required this.semanticsLabel,
  });

  final int booked;
  final int total;

  /// "/14 booked"
  final String suffix;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TroskySpacing.s16,
          vertical: TroskySpacing.s12,
        ),
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: BorderRadius.circular(TroskyRadii.r16),
          boxShadow: TroskyShadows.cardSubtle,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: TroskySpacing.s3),
                    Expanded(
                      child: AnimatedContainer(
                        duration: TroskyMotion.transition400,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i < booked
                              ? TroskyColors.green
                              : TroskyColors.border,
                          borderRadius: BorderRadius.circular(TroskyRadii.r4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: TroskySpacing.s12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$booked',
                    style: TroskyTypography.heading16ExtraBold.copyWith(
                      color: TroskyColors.green,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: TroskySpacing.s2)),
                  TextSpan(
                    text: suffix,
                    style: TroskyTypography.body12Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.anim-price` (P7): when [value] changes, the text turns green and grows
/// 5 % at 40 % of half a second, then settles back to [style]'s colour. It
/// stays still when the phone asks for fewer animations.
class TroskyPriceFlash extends StatefulWidget {
  const TroskyPriceFlash({super.key, required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  State<TroskyPriceFlash> createState() => _TroskyPriceFlashState();
}

class _TroskyPriceFlashState extends State<TroskyPriceFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: TroskyMotion.priceFlashDuration,
  );

  @override
  void didUpdateWidget(TroskyPriceFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        !MediaQuery.disableAnimationsOf(context)) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  /// 0 → 1 by the peak, then back to 0, each half eased.
  double _amount(double t) {
    const peak = TroskyMotion.priceFlashPeak;
    final half = t <= peak ? t / peak : (1 - t) / (1 - peak);
    return TroskyMotion.ease.transform(half.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, _) {
        final amount = _flash.isAnimating ? _amount(_flash.value) : 0.0;
        return Transform.scale(
          scale: 1 + (TroskyMotion.priceFlashScale - 1) * amount,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.value,
            style: widget.style.copyWith(
              color: Color.lerp(widget.style.color, TroskyColors.green, amount),
            ),
          ),
        );
      },
    );
  }
}
