import 'package:flutter/widgets.dart';

import '../tokens/trosky_colors.dart';
import '../tokens/trosky_typography.dart';

/// "Skip" in the top-right corner of onboarding: Inter 13/500.
///
/// The design draws plain text; the tap area is widened to 48 × 48 dp around
/// it, so allow for that when placing it. [alignment] places the text inside
/// that area, e.g. [Alignment.centerRight] to keep the text's right edge
/// where the design has it.
class SkipText extends StatelessWidget {
  const SkipText({
    super.key,
    required this.onPressed,
    this.label = 'Skip',
    this.color = TroskyColors.whiteA65,
    this.alignment = Alignment.center,
  });

  final VoidCallback? onPressed;
  final String label;

  /// [TroskyColors.whiteA65] on Onboarding 1, [TroskyColors.whiteA55] on
  /// Onboarding 2 and 3.
  final Color color;

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: TroskyTypography.body13Medium.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
