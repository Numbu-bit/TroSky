import 'package:flutter/material.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_gradients.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';
import 'home_components.dart';

// The parts of the Trips tab: Trip History (P-15, `P13_TripHistory` in
// PassengerDesigns.tsx) and Booking details with its cancel sheet (P-16,
// measured from the screenshots in design/P-16/; every value is a token).

/// "Total Spent This Month" on Trip History (P13): the green card with the
/// [amount] and three small figures under it.
class TroskySpendingSummaryCard extends StatelessWidget {
  const TroskySpendingSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.stats,
  });

  final String title;

  /// "₵128.50".
  final String amount;

  /// ("24", "Trips"), ("₵5.35", "Avg Fare"), ("₵18.20", "Saved").
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s20,
        vertical: TroskySpacing.s18,
      ),
      decoration: BoxDecoration(
        gradient: TroskyGradients.spendingSummary,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.spendingSummary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.whiteA80,
            ),
          ),
          const SizedBox(height: TroskySpacing.s4),
          Text(
            amount,
            style: TroskyTypography.heading32ExtraBold.copyWith(
              color: TroskyColors.white,
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          Wrap(
            spacing: TroskySpacing.s20,
            runSpacing: TroskySpacing.s8,
            children: [
              for (final (value, label) in stats)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TroskyTypography.heading16Bold.copyWith(
                        color: TroskyColors.white,
                      ),
                    ),
                    Text(
                      label,
                      style: TroskyTypography.body10Regular.copyWith(
                        color: TroskyColors.whiteA70,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The filter tabs under the summary card (P13): a white strip, 40 px as
/// drawn, with one green tab selected. 4 px above and below it also take
/// taps, so each tab is a 48 px touch target.
class TroskySegmentedTabs extends StatelessWidget {
  const TroskySegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => onSelected(
          (details.localPosition.dx / constraints.maxWidth * labels.length)
              .floor()
              .clamp(0, labels.length - 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s4),
          child: Container(
            padding: const EdgeInsets.all(TroskySpacing.s4),
            decoration: BoxDecoration(
              color: TroskyColors.surface,
              borderRadius: BorderRadius.circular(TroskyRadii.r14),
            ),
            child: Row(
              children: [
                for (final (i, label) in labels.indexed) ...[
                  if (i > 0) const SizedBox(width: TroskySpacing.s8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      onTap: () => onSelected(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          vertical: TroskySpacing.s8,
                        ),
                        decoration: BoxDecoration(
                          color: i == selected ? TroskyColors.green : null,
                          borderRadius: BorderRadius.circular(TroskyRadii.r10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TroskyTypography.body12SemiBold.copyWith(
                            color: i == selected
                                ? TroskyColors.white
                                : TroskyColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tag under a [TroskyBookingRow]'s price. P13 draws "Completed" in
/// green and "Cancelled" in red; the others take the matching chip colours.
enum TroskyTagTone {
  green(TroskyColors.greenA08, TroskyColors.greenDark),
  red(TroskyColors.redA08, TroskyColors.red),
  amber(TroskyColors.amberA10, TroskyColors.goldText),
  gray(TroskyColors.border, TroskyColors.textSecondary);

  const TroskyTagTone(this.background, this.text);

  final Color background;
  final Color text;
}

/// One booking on Trip History (P13): a ticket in a tinted square, the
/// route and when, the price and a status tag. [struck] crosses the price
/// out and turns the ticket red, as a cancelled trip.
class TroskyBookingRow extends StatelessWidget {
  const TroskyBookingRow({
    super.key,
    required this.route,
    required this.when,
    required this.price,
    required this.status,
    required this.tone,
    this.struck = false,
    this.onPressed,
  });

  /// "Madina → Circle".
  final String route;

  /// "Today, 08:30".
  final String when;

  /// "₵6.00".
  final String price;
  final String status;
  final TroskyTagTone tone;
  final bool struck;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = struck ? TroskyColors.red : TroskyColors.green;
    return Semantics(
      button: onPressed != null,
      label: '$route, $when, $price, $status',
      excludeSemantics: true,
      child: Material(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TroskySpacing.s16,
              vertical: TroskySpacing.s14,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: struck ? TroskyColors.redA08 : TroskyColors.greenA08,
                    borderRadius: BorderRadius.circular(TroskyRadii.r12),
                  ),
                  alignment: Alignment.center,
                  child: TroskyIcons.ticket(color: iconColor),
                ),
                const SizedBox(width: TroskySpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: TroskyTypography.body13SemiBold.copyWith(
                          color: TroskyColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s2),
                      Text(
                        when,
                        style: TroskyTypography.body11Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TroskySpacing.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TroskyTypography.heading14Bold.copyWith(
                        color: struck
                            ? TroskyColors.textSecondary
                            : TroskyColors.textPrimary,
                        decoration: struck ? TextDecoration.lineThrough : null,
                        decorationColor: TroskyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: TroskySpacing.s2),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tone.background,
                        borderRadius: BorderRadius.circular(TroskyRadii.r6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TroskySpacing.s6,
                          vertical: TroskySpacing.s1,
                        ),
                        child: Text(
                          status,
                          style: TroskyTypography.body10Bold.copyWith(
                            color: tone.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A grey stand-in for a [TroskyBookingRow] while Trip History loads.
class TroskyBookingRowSkeleton extends StatelessWidget {
  const TroskyBookingRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s14,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r16),
      ),
      child: const Row(
        children: [
          TroskySkeleton(width: 40, height: 40, radius: TroskyRadii.r12),
          SizedBox(width: TroskySpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TroskySkeleton(width: 130, height: 13),
                SizedBox(height: TroskySpacing.s6),
                TroskySkeleton(width: 80, height: 11),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TroskySkeleton(width: 44, height: 14),
              SizedBox(height: TroskySpacing.s6),
              TroskySkeleton(width: 58, height: 12, radius: TroskyRadii.r6),
            ],
          ),
        ],
      ),
    );
  }
}

/// A white card of Booking details (P-16), with an optional capitalised
/// [label] ("VEHICLE & DRIVER") over its [child].
class TroskyDetailsCard extends StatelessWidget {
  const TroskyDetailsCard({super.key, this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TroskySpacing.s20),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.cardSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label case final label?) ...[
            TroskyDetailsLabel(label),
            const SizedBox(height: TroskySpacing.s14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A small capitalised label on Booking details: "THU 22 OCT", "SEATS",
/// "TOTAL".
class TroskyDetailsLabel extends StatelessWidget {
  const TroskyDetailsLabel(this.text, {super.key, this.bold = true});

  final String text;

  /// "SEATS" and "PAID WITH" are lighter than the card titles.
  final bool bold;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style:
        (bold ? TroskyTypography.body11BoldLs5 : TroskyTypography.body11Regular)
            .copyWith(color: TroskyColors.textSecondary),
  );
}

/// The trip on Booking details (P-16): the day and the ride's length, then
/// the boarding and alighting stops on a route line with their times.
class TroskyJourneyCard extends StatelessWidget {
  const TroskyJourneyCard({
    super.key,
    required this.day,
    this.duration,
    required this.from,
    required this.fromTime,
    required this.to,
    this.toTime,
  });

  /// "Thu 22 Oct", shown in capitals.
  final String day;

  /// "About 40 min".
  final String? duration;
  final String from;

  /// "07:15".
  final String fromTime;
  final String to;

  /// "~07:55".
  final String? toTime;

  @override
  Widget build(BuildContext context) {
    return TroskyDetailsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TroskyDetailsLabel(day)),
              if (duration case final duration?)
                Text(
                  duration,
                  style: TroskyTypography.body12Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TroskySpacing.s14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      SizedBox(height: TroskySpacing.s2),
                      _Stop(
                        color: TroskyColors.green,
                        halo: TroskyColors.greenA15,
                      ),
                      Expanded(
                        child: VerticalDivider(
                          width: TroskyBorders.w2,
                          thickness: TroskyBorders.w2,
                          color: TroskyColors.border,
                        ),
                      ),
                      _Stop(
                        color: TroskyColors.navy,
                        halo: TroskyColors.border,
                      ),
                      SizedBox(height: TroskySpacing.s2),
                    ],
                  ),
                ),
                const SizedBox(width: TroskySpacing.s14),
                Expanded(
                  child: Column(
                    children: [
                      _StopLine(name: from, time: fromTime, strong: true),
                      const SizedBox(height: TroskySpacing.s24),
                      _StopLine(name: to, time: toTime, strong: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.color, required this.halo});

  final Color color;
  final Color halo;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _StopLine extends StatelessWidget {
  const _StopLine({required this.name, this.time, required this.strong});

  final String name;
  final String? time;

  /// The departure is bold ink; the estimated arrival lighter.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TroskyTypography.heading15Bold.copyWith(
              color: TroskyColors.ink,
            ),
          ),
        ),
        if (time case final time?) ...[
          const SizedBox(width: TroskySpacing.s12),
          Text(
            time,
            style: strong
                ? TroskyTypography.heading16ExtraBold.copyWith(
                    color: TroskyColors.ink,
                  )
                : TroskyTypography.body14Medium.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
          ),
        ],
      ],
    );
  }
}

/// A refund on Booking details and "Booking cancelled" (P-16): a wallet
/// and one line. [prominent] is the cancelled screen's white pill with a
/// shadow and green text; otherwise a grey box in a card.
class TroskyRefundNote extends StatelessWidget {
  const TroskyRefundNote({
    super.key,
    required this.text,
    this.prominent = false,
  });

  final String text;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final color = prominent ? TroskyColors.greenDark : TroskyColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s12,
      ),
      decoration: BoxDecoration(
        color: prominent ? TroskyColors.surface : TroskyColors.background,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
        boxShadow: prominent ? TroskyShadows.cardSubtle : null,
      ),
      child: Row(
        mainAxisSize: prominent ? MainAxisSize.min : MainAxisSize.max,
        children: [
          TroskyIcons.wallet(
            color: prominent ? TroskyColors.green : TroskyColors.textSecondary,
          ),
          const SizedBox(width: TroskySpacing.s10),
          Flexible(
            child: Text(
              text,
              style:
                  (prominent
                          ? TroskyTypography.body13Bold
                          : TroskyTypography.body13SemiBold)
                      .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// One reason on the cancel sheet (P-16): a round radio, red when chosen,
/// and its label. The whole row is the 48 px touch target.
class TroskyRadioOption extends StatelessWidget {
  const TroskyRadioOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TroskyColors.surface,
                  border: Border.all(
                    color: selected ? TroskyColors.red : TroskyColors.border,
                    width: selected ? TroskyBorders.w2 : TroskyBorders.w1p5,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: TroskyColors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: TroskySpacing.s14),
              Expanded(
                child: Text(
                  label,
                  style: TroskyTypography.body14Medium.copyWith(
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

/// The green box on the cancel sheet (P-16): what comes back, and when.
class TroskyRefundBox extends StatelessWidget {
  const TroskyRefundBox({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s14,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.greenA06,
        borderRadius: BorderRadius.circular(TroskyRadii.r14),
        border: Border.all(color: TroskyColors.greenA20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TroskyTypography.body14Bold.copyWith(
              color: TroskyColors.greenDark,
            ),
          ),
          const SizedBox(height: TroskySpacing.s4),
          Text(
            body,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
