import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_gradients.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';
import 'auth_header.dart';

/// The navy header of Payment (P-07): the seat selection gradient, a 44 px
/// round back button, the title (Plus Jakarta Sans 22/800) and a subtitle
/// at 55 % white, 134 px tall with the design's 48 px status bar.
class TroskyPageHeader extends StatelessWidget {
  const TroskyPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backLabel = 'Back',
    this.subtitleTrailing,
    this.trailing,
  });

  final String title;
  final String subtitle;

  /// Null hides the back button (nothing to go back to).
  final VoidCallback? onBack;

  /// What a screen reader says for the back button.
  final String backLabel;

  /// After the subtitle: the copy button by a booking reference (P-16).
  final Widget? subtitleTrailing;

  /// On the right: a status chip (P-16).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TroskyTypography.body13Regular.copyWith(
      color: TroskyColors.whiteA55,
    );
    final top = math.max(
      TroskyAuthHeader.statusBarHeight,
      MediaQuery.viewPaddingOf(context).top,
    );
    return DecoratedBox(
      decoration: BoxDecoration(gradient: TroskyGradients.seatSelectionHeader),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s18,
          top + TroskySpacing.s14,
          TroskySpacing.s18,
          TroskySpacing.s18,
        ),
        child: Row(
          children: [
            if (onBack case final onBack?) ...[
              // The 48 px touch area reaches 2 px past the 44 px disc, so it
              // stays on the margin as drawn.
              Transform.translate(
                offset: const Offset(-2, 0),
                child: TroskyHeaderIconButton(
                  semanticsLabel: backLabel,
                  onPressed: onBack,
                  diameter: 44,
                  child: TroskyIcons.back(color: TroskyColors.white),
                ),
              ),
              const SizedBox(width: TroskySpacing.s11),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A chip sits beside the title only, so the subtitle (a
                  // booking reference) keeps the whole width below.
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: TroskyTypography.heading22ExtraBold.copyWith(
                              color: TroskyColors.white,
                            ),
                          ),
                        ),
                      ),
                      if (trailing case final trailing?) ...[
                        const SizedBox(width: TroskySpacing.s10),
                        trailing,
                      ],
                    ],
                  ),
                  const SizedBox(height: TroskySpacing.s2),
                  Row(
                    children: [
                      Flexible(
                        child: subtitleTrailing == null
                            ? Text(subtitle, style: subtitleStyle)
                            // A reference: one line, a little smaller
                            // when it must, never broken in two.
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  style: subtitleStyle,
                                ),
                              ),
                      ),
                      ?subtitleTrailing,
                    ],
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
