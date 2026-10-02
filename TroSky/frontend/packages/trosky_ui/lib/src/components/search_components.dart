import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../painting/svg_painting.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_opacity.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';
import 'trosky_chip.dart';

/// A filter pill on Search Results (P6): `padding: 6px 14px`, radius 20,
/// Inter 12/600; navy when [selected], else grey on the page background.
class TroskyFilterPill extends StatelessWidget {
  const TroskyFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s14,
            vertical: TroskySpacing.s6,
          ),
          decoration: BoxDecoration(
            color: selected ? TroskyColors.navy : TroskyColors.background,
            borderRadius: BorderRadius.circular(TroskyRadii.r20),
            border: Border.all(
              color: selected ? TroskyColors.navy : TroskyColors.border,
              width: TroskyBorders.w1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TroskyTypography.body12SemiBold.copyWith(
              color: selected ? TroskyColors.white : TroskyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the badge on a [TroskyTripCard] says.
enum TroskyTripBadgeKind {
  /// "~3 min away · approaching your stop", with the clock (P6).
  approaching,

  /// "Board at Accra Madina · 350 m away", with a pin (decision 21).
  boardAt,
}

/// The fare row of a [TroskyTripCard]: [price] large; [soloPrice] crossed
/// out before it and [saving] in an amber pill after it, when known
/// (decision 20).
@immutable
class TroskyTripFare {
  const TroskyTripFare({required this.price, this.soloPrice, this.saving});

  /// "₵14"
  final String price;

  /// "₵38"
  final String? soloPrice;

  /// "Save 63%"
  final String? saving;
}

/// A vehicle on Search Results (P6).
///
/// White, radius 20, a soft shadow and a 1.5 px border: green at 30 % for
/// the [highlighted] best match, clear otherwise. Top: [title] (the vehicle
/// type), the [plate], an optional [tag] ("BEST MATCH"), then [times]; the
/// [seats] chip on the right. Then the optional badge and the [fare] row.
///
/// A [passed] card is faded to 45 % under a red "[passedNote]" strip, and
/// has no badge or fare. Without [onPressed] the card can't be tapped.
class TroskyTripCard extends StatelessWidget {
  const TroskyTripCard({
    super.key,
    required this.title,
    required this.plate,
    required this.times,
    required this.seatsLabel,
    required this.seatsColor,
    this.tag,
    this.highlighted = false,
    this.badge,
    this.badgeKind = TroskyTripBadgeKind.approaching,
    this.fare,
    this.passed = false,
    this.passedNote,
    this.semanticsLabel,
    this.onPressed,
  });

  final String title;
  final String? plate;

  /// "Departs 07:15 · ETA 08:05"
  final String times;
  final String seatsLabel;
  final TroskyChipColor seatsColor;
  final String? tag;
  final bool highlighted;
  final String? badge;
  final TroskyTripBadgeKind badgeKind;
  final TroskyTripFare? fare;
  final bool passed;
  final String? passedNote;
  final String? semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = passed
        ? TroskyColors.border
        : highlighted
        ? TroskyColors.greenA30
        : TroskyColors.transparent;
    final card = Container(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.cardSubtle,
        border: Border.all(color: borderColor, width: TroskyBorders.w1p5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (passed && passedNote != null) _PassedStrip(passedNote!),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TroskySpacing.s16,
              TroskySpacing.s12,
              TroskySpacing.s16,
              TroskySpacing.s14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: TroskySpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: TroskySpacing.s6,
                              runSpacing: TroskySpacing.s2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: TroskyTypography.heading14Bold
                                      .copyWith(
                                        color: TroskyColors.textPrimary,
                                      ),
                                ),
                                if (plate != null)
                                  Text(
                                    plate!,
                                    style: TroskyTypography.body10Regular
                                        .copyWith(
                                          color: TroskyColors.textMuted,
                                        ),
                                  ),
                                if (tag != null) _Tag(tag!),
                              ],
                            ),
                            const SizedBox(height: TroskySpacing.s3),
                            Text(
                              times,
                              style: TroskyTypography.body12Regular.copyWith(
                                color: TroskyColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TroskyChip(label: seatsLabel, color: seatsColor),
                  ],
                ),
                const SizedBox(height: TroskySpacing.s4),
                if (!passed && badge != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: TroskySpacing.s6,
                      bottom: TroskySpacing.s8,
                    ),
                    child: _Badge(badge!, badgeKind),
                  ),
                if (!passed && fare != null) _FareRow(fare!),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onPressed != null,
      enabled: onPressed != null,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: passed ? Opacity(opacity: TroskyOpacity.o45, child: card) : card,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: TroskySpacing.s6,
      vertical: TroskySpacing.s2,
    ),
    decoration: BoxDecoration(
      color: TroskyColors.greenA10,
      borderRadius: BorderRadius.circular(TroskyRadii.r4),
    ),
    child: Text(
      text,
      style: TroskyTypography.body10Bold.copyWith(color: TroskyColors.green),
    ),
  );
}

/// "Already passed your stop — unavailable": red at 7 % with a 12 % line
/// under it, across the top of the card.
class _PassedStrip extends StatelessWidget {
  const _PassedStrip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: TroskySpacing.s16,
      vertical: TroskySpacing.s5,
    ),
    decoration: const BoxDecoration(
      color: TroskyColors.redA07,
      border: Border(
        bottom: BorderSide(color: TroskyColors.redA12, width: TroskyBorders.w1),
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r18),
      ),
    ),
    child: Row(
      children: [
        TroskyIcons.arrowRight(color: TroskyColors.red),
        const SizedBox(width: TroskySpacing.s6),
        Expanded(
          child: Text(
            text,
            style: TroskyTypography.body10Bold.copyWith(
              color: TroskyColors.red,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.kind);

  final String text;
  final TroskyTripBadgeKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: TroskySpacing.s10,
      vertical: TroskySpacing.s5,
    ),
    decoration: BoxDecoration(
      color: TroskyColors.greenA08,
      borderRadius: BorderRadius.circular(TroskyRadii.r8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (kind) {
          TroskyTripBadgeKind.approaching => TroskyIcons.clockSmall(
            color: TroskyColors.green,
          ),
          TroskyTripBadgeKind.boardAt => TroskyIcons.pinSmall(
            color: TroskyColors.green,
          ),
        },
        const SizedBox(width: TroskySpacing.s6),
        Flexible(
          child: Text(
            text,
            style: TroskyTypography.body10SemiBold.copyWith(
              color: TroskyColors.greenDark,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FareRow extends StatelessWidget {
  const _FareRow(this.fare);

  final TroskyTripFare fare;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TroskySpacing.s10,
    runSpacing: TroskySpacing.s4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (fare.soloPrice case final solo?)
        Text(
          solo,
          style: TroskyTypography.body13Regular.copyWith(
            color: TroskyColors.textSecondary,
            decoration: TextDecoration.lineThrough,
            decorationColor: TroskyColors.textSecondary,
          ),
        ),
      Text(
        fare.price,
        style: TroskyTypography.heading22ExtraBoldH100.copyWith(
          color: TroskyColors.ink,
        ),
      ),
      if (fare.saving case final saving?)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s10,
            vertical: TroskySpacing.s4,
          ),
          decoration: BoxDecoration(
            color: TroskyColors.amberA15,
            borderRadius: BorderRadius.circular(TroskyRadii.r20),
          ),
          child: Text(
            saving,
            maxLines: 1,
            style: TroskyTypography.body11Bold.copyWith(
              color: TroskyColors.goldText,
            ),
          ),
        ),
    ],
  );
}

/// A notice across the page under a header, as Search Results' "Showing
/// vehicles still approaching your stop" (P6): green at 8 % with a 15 %
/// line under it, the clock, the text, and an optional [action] word.
class TroskyInfoBanner extends StatelessWidget {
  const TroskyInfoBanner({
    super.key,
    required this.text,
    this.action,
    this.actionColor = TroskyColors.textSecondary,
    this.onAction,
  });

  final String text;
  final String? action;
  final Color actionColor;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: TroskySpacing.s16),
      decoration: const BoxDecoration(
        color: TroskyColors.greenA08,
        border: Border(
          bottom: BorderSide(
            color: TroskyColors.greenA15,
            width: TroskyBorders.w1,
          ),
        ),
      ),
      child: Row(
        children: [
          TroskyIcons.clock(color: TroskyColors.green),
          const SizedBox(width: TroskySpacing.s8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s8),
              child: Text(
                text,
                style: TroskyTypography.body11SemiBold.copyWith(
                  color: TroskyColors.greenDark,
                ),
              ),
            ),
          ),
          if (action != null)
            Semantics(
              button: true,
              label: action,
              onTap: onAction,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TroskySpacing.s8,
                    TroskySpacing.s8,
                    TroskySpacing.s16,
                    TroskySpacing.s8,
                  ),
                  child: Text(
                    action!,
                    style: TroskyTypography.body10Bold.copyWith(
                      color: actionColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The white button with a dashed border at the end of Search Results
/// ("Show 2 vehicles that already passed your stop", P6): 44 px tall,
/// radius 16, a 1.5 px dashed border in the border grey.
class TroskyDashedButton extends StatelessWidget {
  const TroskyDashedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: CustomPaint(
          foregroundPainter: const _DashedBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: TroskySpacing.s16,
              vertical: TroskySpacing.s8,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TroskyColors.surface,
              borderRadius: BorderRadius.circular(TroskyRadii.r16),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TroskyTypography.body12SemiBold.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `1.5px dashed`: Chrome draws dashes and gaps three times the width.
class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    const width = TroskyBorders.w1p5;
    final rect = (Offset.zero & size).deflate(width / 2);
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(TroskyRadii.r16 - width / 2),
        ),
      );
    canvas.drawPath(
      dashedPath(outline, const [width * 3, width * 3]),
      Paint()
        ..color = TroskyColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
