import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';

/// One tab of a [TroskyTabBar].
class TroskyTabItem {
  const TroskyTabItem({required this.emoji, required this.label});

  /// Drawn with the phone's emoji font, as designed (decision 17).
  final String emoji;
  final String label;
}

/// The bottom tab bar of Driver Home (D1), which the passenger app uses too
/// (decision 12): white, a 1 px top border, 60 px tall. Each tab is an emoji
/// over a 10 px label, 2 px apart; the selected one is green with a
/// 16 × 3 bar under it.
///
/// The phone's bottom inset (gesture bar or buttons) is added below the
/// 60 px, in the bar's own white.
class TroskyTabBar extends StatelessWidget {
  const TroskyTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<TroskyTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// The bar's height without the bottom inset.
  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TroskyColors.surface,
        border: Border(
          top: BorderSide(color: TroskyColors.border, width: TroskyBorders.w1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: math.max(0, MediaQuery.viewPaddingOf(context).bottom),
        ),
        child: ConstrainedBox(
          // Grows with large text instead of clipping the labels.
          constraints: const BoxConstraints(minHeight: height),
          // Every tab as tall as the tallest, so all of it is tappable.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in items.indexed)
                  Expanded(
                    child: _Tab(
                      item: item,
                      selected: i == currentIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final TroskyTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: TroskyTypography.body18Regular),
              const SizedBox(height: TroskySpacing.s2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TroskyTypography.body10Medium.copyWith(
                  color: selected
                      ? TroskyColors.green
                      : TroskyColors.textSecondary,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: TroskySpacing.s2),
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: TroskyColors.green,
                    borderRadius: BorderRadius.circular(TroskyRadii.r2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
