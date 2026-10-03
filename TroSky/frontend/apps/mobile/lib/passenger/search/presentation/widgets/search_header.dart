import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// The navy header of Search Results (P6), shared by Search (P-02,
/// decision 19): the round back button, a small [label] over the [title],
/// an optional [trailing] button, then [child] (the from/to block).
///
/// It starts 48 px from the top, where the design's status bar ends, or
/// below a taller real one (decision 5).
class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.label,
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.child,
    this.trailing,
  });

  final String label;
  final String title;
  final String backLabel;
  final VoidCallback onBack;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = math.max(48.0, MediaQuery.viewPaddingOf(context).top);
    return ColoredBox(
      color: TroskyColors.navy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s20,
          top,
          TroskySpacing.s20,
          TroskySpacing.s14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // The 36 px disc sits on the padding; its 48 px touch area
                // reaches 6 px past it, and 12 px separate it from the text.
                Transform.translate(
                  offset: const Offset(-6, 0),
                  child: TroskyHeaderIconButton(
                    semanticsLabel: backLabel,
                    onPressed: onBack,
                    child: TroskyIcons.back(color: TroskyColors.white),
                  ),
                ),
                const SizedBox(width: TroskySpacing.s6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TroskyTypography.body11Regular.copyWith(
                          color: TroskyColors.whiteA50,
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s1),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TroskyTypography.heading16Bold.copyWith(
                            color: TroskyColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing case final trailing?)
                  Transform.translate(
                    offset: const Offset(6, 0),
                    child: trailing,
                  ),
              ],
            ),
            const SizedBox(height: TroskySpacing.s14),
            child,
          ],
        ),
      ),
    );
  }
}

/// The from/to block of P6: a 4 px inset panel at 8 % white, radius 12.
class JourneyPanel extends StatelessWidget {
  const JourneyPanel({
    super.key,
    required this.children,
    this.vertical = false,
  });

  final List<Widget> children;

  /// Stacked rows (Search) instead of side by side (Search Results).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TroskySpacing.s4),
      decoration: BoxDecoration(
        color: TroskyColors.whiteA08,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(height: TroskySpacing.s4),
                  child,
                ],
              ],
            )
          : Row(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: TroskySpacing.s8),
                  Expanded(child: child),
                ],
              ],
            ),
    );
  }
}

/// One cell of the [JourneyPanel]: a coloured dot and its content, 40 px
/// tall, radius 8; the [active] one at 12 % white.
class JourneyCell extends StatelessWidget {
  const JourneyCell({
    super.key,
    required this.dotColor,
    required this.active,
    required this.child,
  });

  final Color dotColor;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.only(
        left: TroskySpacing.s12,
        right: TroskySpacing.s8,
      ),
      decoration: BoxDecoration(
        color: active ? TroskyColors.whiteA12 : TroskyColors.transparent,
        borderRadius: BorderRadius.circular(TroskyRadii.r8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: TroskySpacing.s8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Text in a [JourneyCell]: Inter 12/500 at 85 % white when active, 12/400
/// at 60 % otherwise.
TextStyle journeyText({required bool active}) => active
    ? TroskyTypography.body12Medium.copyWith(color: TroskyColors.whiteA85)
    : TroskyTypography.body12Regular.copyWith(color: TroskyColors.whiteA60);
