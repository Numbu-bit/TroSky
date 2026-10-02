import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_gradients.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';

/// The search bar on the Home header (P5): white, 48 px tall, radius 14,
/// the magnifier, a grey prompt, a 1 × 20 divider and a green [trailing]
/// word. The whole bar is one button.
class TroskySearchBar extends StatelessWidget {
  const TroskySearchBar({
    super.key,
    required this.hint,
    required this.trailing,
    required this.onPressed,
  });

  /// "Where are you going?"
  final String hint;

  /// "Now"
  final String trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$hint, $trailing',
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s14),
          decoration: BoxDecoration(
            color: TroskyColors.surface,
            borderRadius: BorderRadius.circular(TroskyRadii.r14),
            boxShadow: TroskyShadows.searchBar,
          ),
          child: Row(
            children: [
              TroskyIcons.search(color: TroskyColors.textSecondary),
              const SizedBox(width: TroskySpacing.s10),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: TroskySpacing.s10),
              Container(width: 1, height: 20, color: TroskyColors.border),
              const SizedBox(width: TroskySpacing.s10),
              Text(
                trailing,
                style: TroskyTypography.body12SemiBold.copyWith(
                  color: TroskyColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A favourite route on the Home sheet (P5): `padding: 8px 14px`, the page
/// background, a 1 px border, radius 20, Inter 12/500.
class TroskyRouteChip extends StatelessWidget {
  const TroskyRouteChip({super.key, required this.label, this.onPressed});

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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s14,
            vertical: TroskySpacing.s8,
          ),
          decoration: BoxDecoration(
            color: TroskyColors.background,
            borderRadius: BorderRadius.circular(TroskyRadii.r20),
            border: Border.all(
              color: TroskyColors.border,
              width: TroskyBorders.w1,
            ),
          ),
          child: Text(
            label,
            style: TroskyTypography.body12Medium.copyWith(
              color: TroskyColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The promo card at the bottom of the Home sheet (P5): navy-to-blue at
/// 120°, radius 16, an amber eyebrow, a white title, a 60 % white line and
/// an amber pill. The whole card is one button.
class TroskyPromoBanner extends StatelessWidget {
  const TroskyPromoBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });

  /// "NEW FEATURE"
  final String eyebrow;
  final String title;
  final String body;

  /// "Try it"
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $body. $action',
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s16,
            vertical: TroskySpacing.s14,
          ),
          decoration: BoxDecoration(
            gradient: TroskyGradients.promoCard,
            borderRadius: BorderRadius.circular(TroskyRadii.r16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TroskyTypography.body10BoldLs6.copyWith(
                        color: TroskyColors.amber,
                      ),
                    ),
                    const SizedBox(height: TroskySpacing.s2),
                    Text(
                      title,
                      style: TroskyTypography.heading13Bold.copyWith(
                        color: TroskyColors.white,
                      ),
                    ),
                    const SizedBox(height: TroskySpacing.s2),
                    Text(
                      body,
                      style: TroskyTypography.body11Regular.copyWith(
                        color: TroskyColors.whiteA60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TroskySpacing.s14,
                  vertical: TroskySpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: TroskyColors.amber,
                  borderRadius: BorderRadius.circular(TroskyRadii.r20),
                ),
                child: Text(
                  action,
                  maxLines: 1,
                  style: TroskyTypography.body12Bold.copyWith(
                    color: TroskyColors.ink,
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

/// The grab handle at the top of a bottom sheet (P5): 40 × 4, radius 2, in
/// the border grey.
class TroskySheetHandle extends StatelessWidget {
  const TroskySheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: TroskyColors.border,
          borderRadius: BorderRadius.circular(TroskyRadii.r2),
        ),
      ),
    );
  }
}

/// A grey block standing in for content that is loading. It stays still:
/// no shimmer, so it costs nothing on slow phones.
class TroskySkeleton extends StatelessWidget {
  const TroskySkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = TroskyRadii.r8,
    this.color = TroskyColors.border,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
