import 'package:flutter/widgets.dart';

import '../tokens/trosky_colors.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_typography.dart';

/// Colour variants of the `Chip` in Shared.tsx.
enum TroskyChipColor {
  green(TroskyColors.greenA12, TroskyColors.greenDark),
  amber(TroskyColors.amberA15, TroskyColors.goldText),
  gray(TroskyColors.border, TroskyColors.textSecondary),
  red(TroskyColors.redA12, TroskyColors.redDark),
  blue(TroskyColors.blueA12, TroskyColors.blueDark);

  const TroskyChipColor(this.background, this.text);

  final Color background;
  final Color text;
}

/// Small status pill: `px-2.5 py-0.5 rounded-full text-xs font-semibold`,
/// i.e. 10 × 2 px padding and Inter 12/600 on a 16 px line.
class TroskyChip extends StatelessWidget {
  const TroskyChip({super.key, required this.label, required this.color});

  final String label;
  final TroskyChipColor color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.background,
        borderRadius: BorderRadius.circular(TroskyRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          label,
          style: TroskyTypography.body12SemiBoldH133.copyWith(
            color: color.text,
          ),
        ),
      ),
    );
  }
}
