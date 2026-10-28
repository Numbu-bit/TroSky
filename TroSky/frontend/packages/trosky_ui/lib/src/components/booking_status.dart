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

// The parts of Payment's booking states (P-07: waiting for the driver,
// accepted, moved to another vehicle, not accepted), measured from the
// Figma screenshots in design/P-07/.

/// One of the three facts under a [TroskyTripSummaryCard]'s line:
/// "Vehicle GR 1234-24".
@immutable
class TroskyTripFact {
  const TroskyTripFact(this.label, this.value, {this.valueColor});

  final String label;
  final String value;

  /// Ink unless given (the total is dark green).
  final Color? valueColor;
}

/// The booked trip on Payment (P-07): the two stops on a route line, the
/// day and time on the right, then three facts (vehicle, seats, total)
/// between thin dividers.
///
/// [highlighted] is the "moved to another vehicle" look: a blue border, the
/// time in blue after the [previousTime] struck through, and [tag] above.
class TroskyTripSummaryCard extends StatelessWidget {
  const TroskyTripSummaryCard({
    super.key,
    required this.from,
    required this.to,
    required this.day,
    required this.time,
    required this.facts,
    this.previousTime,
    this.tag,
    this.highlighted = false,
  });

  final String from;
  final String to;

  /// "Today".
  final String day;

  /// "07:15".
  final String time;

  final List<TroskyTripFact> facts;

  /// The time before the move, struck through.
  final String? previousTime;

  /// "New vehicle assigned", shown in capitals.
  final String? tag;

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final timeColor = highlighted ? TroskyColors.blue : TroskyColors.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s20,
        TroskySpacing.s20,
        TroskySpacing.s20,
        TroskySpacing.s18,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.receiptCard,
        border: highlighted
            ? Border.all(color: TroskyColors.blueA25, width: TroskyBorders.w1p5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag case final tag?) ...[
            TroskyTag(label: tag),
            const SizedBox(height: TroskySpacing.s12),
          ],
          LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Route(from: from, to: to),
                ),
                const SizedBox(width: TroskySpacing.s12),
                _Times(
                  day: day,
                  time: time,
                  previousTime: previousTime,
                  timeColor: timeColor,
                  stacked:
                      previousTime != null &&
                      !_sideBySideFits(context, constraints.maxWidth),
                ),
              ],
            ),
          ),
          const SizedBox(height: TroskySpacing.s16),
          Container(height: TroskyBorders.w1, color: TroskyColors.border),
          const SizedBox(height: TroskySpacing.s14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, fact) in facts.indexed) ...[
                  if (i > 0)
                    Container(
                      width: TroskyBorders.w1,
                      color: TroskyColors.border,
                    ),
                  Expanded(
                    // The first fact is a little wider, as drawn.
                    flex: i == 0 ? 6 : 5,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : TroskySpacing.s14,
                        right: TroskySpacing.s8,
                      ),
                      child: _Fact(fact),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on TroskyTripSummaryCard {
  /// Whether the stop names and both times fit on their lines, as drawn.
  /// Real stop names ("Accra Madina") are longer than the design's, so on a
  /// narrow phone with large text the struck-through time goes above the
  /// new one instead, rather than cutting the names short.
  bool _sideBySideFits(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final names = [
      measure(from, _Route.nameStyle),
      measure(to, _Route.nameStyle),
    ].reduce((a, b) => a > b ? a : b);
    final times =
        measure(previousTime!, _Times.previousStyle) +
        TroskySpacing.s6 +
        measure(time, _Times.timeStyle);
    final right = [
      measure(day, _Times.dayStyle),
      times,
    ].reduce((a, b) => a > b ? a : b);
    return _Route.leading + names + TroskySpacing.s12 + right <= width;
  }
}

/// The day, and the time: after a move, the old one struck through beside
/// it, or above it when [stacked].
class _Times extends StatelessWidget {
  const _Times({
    required this.day,
    required this.time,
    required this.previousTime,
    required this.timeColor,
    required this.stacked,
  });

  final String day;
  final String time;
  final String? previousTime;
  final Color timeColor;
  final bool stacked;

  static final TextStyle dayStyle = TroskyTypography.body13Regular.copyWith(
    color: TroskyColors.textSecondary,
  );
  static final TextStyle previousStyle = TroskyTypography.body13Regular
      .copyWith(
        color: TroskyColors.textSecondary,
        decoration: TextDecoration.lineThrough,
        decorationColor: TroskyColors.textSecondary,
      );
  static const TextStyle timeStyle = TroskyTypography.heading18ExtraBold;

  @override
  Widget build(BuildContext context) {
    final current = Text(time, style: timeStyle.copyWith(color: timeColor));
    final previous = switch (previousTime) {
      final previous? => Text(previous, style: previousStyle),
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: TroskySpacing.s7),
        Text(day, style: dayStyle),
        const SizedBox(height: TroskySpacing.s3),
        if (stacked) ...[
          ?previous,
          current,
        ] else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (previous != null) ...[
                previous,
                const SizedBox(width: TroskySpacing.s6),
              ],
              current,
            ],
          ),
      ],
    );
  }
}

/// The two stops on a short route line: green where the ride starts, navy
/// where it ends, each in a pale halo.
class _Route extends StatelessWidget {
  const _Route({required this.from, required this.to});

  final String from;
  final String to;

  static const double _halo = 22;
  static const double _gap = 18;

  /// The indent, the halo and the gap before the names.
  static const double leading = TroskySpacing.s12 + _halo + TroskySpacing.s28;

  static final TextStyle nameStyle = TroskyTypography.heading17Bold.copyWith(
    color: TroskyColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final style = nameStyle;
    Widget name(String text) => SizedBox(
      height: _halo,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: TroskySpacing.s12),
        const ExcludeSemantics(
          child: Column(
            children: [
              _Dot(color: TroskyColors.green, halo: TroskyColors.greenA15),
              SizedBox(
                width: TroskyBorders.w2,
                height: _gap,
                child: ColoredBox(color: TroskyColors.border),
              ),
              _Dot(color: TroskyColors.navy, halo: TroskyColors.border),
            ],
          ),
        ),
        const SizedBox(width: TroskySpacing.s28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name(from),
              const SizedBox(height: _gap),
              name(to),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.halo});

  final Color color;
  final Color halo;

  @override
  Widget build(BuildContext context) => Container(
    width: _Route._halo,
    height: _Route._halo,
    decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.fact);

  final TroskyTripFact fact;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.label,
          style: TroskyTypography.body12Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
        const SizedBox(height: TroskySpacing.s5),
        Text(
          fact.value,
          style: TroskyTypography.heading14Bold.copyWith(
            color: fact.valueColor ?? TroskyColors.ink,
          ),
        ),
      ],
    ),
  );
}

/// The small blue capsule above a moved booking: "↑ NEW VEHICLE ASSIGNED".
class TroskyTag extends StatelessWidget {
  const TroskyTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s10,
        vertical: TroskySpacing.s5,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.blueA10,
        borderRadius: BorderRadius.circular(TroskyRadii.r14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TroskyIcons.arrowUp(color: TroskyColors.blue),
          const SizedBox(width: TroskySpacing.s6),
          Text(
            label.toUpperCase(),
            style: TroskyTypography.body11BoldLs5.copyWith(
              color: TroskyColors.blue,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The tone of a [TroskyStatusBanner].
enum TroskyStatusTone {
  /// Green with a check: "Driver accepted your booking".
  success,

  /// Blue with an "i": "We moved you to another vehicle".
  info,
}

/// A tinted notice at the top of Payment (P-07): a coloured disc with a
/// white check or "i", then bold text in the same colour.
class TroskyStatusBanner extends StatelessWidget {
  const TroskyStatusBanner({super.key, required this.text, required this.tone});

  final String text;
  final TroskyStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, line, disc, ink) = switch (tone) {
      TroskyStatusTone.success => (
        TroskyColors.greenA10,
        TroskyColors.greenA20,
        TroskyColors.green,
        TroskyColors.greenDark,
      ),
      TroskyStatusTone.info => (
        TroskyColors.blueA10,
        TroskyColors.blueA20,
        TroskyColors.blue,
        TroskyColors.blue,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TroskySpacing.s14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(TroskyRadii.r16),
          border: Border.all(color: line, width: TroskyBorders.w1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: switch (tone) {
                TroskyStatusTone.success => TroskyIcons.check(
                  color: TroskyColors.white,
                ),
                TroskyStatusTone.info => TroskyIcons.info(
                  color: TroskyColors.white,
                ),
              },
            ),
            const SizedBox(width: TroskySpacing.s12),
            Expanded(
              child: Text(
                text,
                style: TroskyTypography.body13Bold.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The green dot of "Waiting for the driver" (P-07): an 18 px dot in a
/// 36 px halo that pulses (`.anim-pulse`), inside a still 64 px ring. When
/// the phone asks for fewer animations it stands still, as drawn.
class TroskyPulseDot extends StatefulWidget {
  const TroskyPulseDot({super.key});

  static const double size = 64;

  @override
  State<TroskyPulseDot> createState() => _TroskyPulseDotState();
}

class _TroskyPulseDotState extends State<TroskyPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _half = AnimationController(
    vsync: this,
    duration: TroskyMotion.pulseDuration ~/ 2,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _half,
    curve: TroskyMotion.easeInOut,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _half
        ..stop()
        ..value = 0;
    } else if (!_half.isAnimating) {
      _half.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _half.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const halo = DecoratedBox(
      decoration: BoxDecoration(
        color: TroskyColors.greenA12,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 36),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: TroskyPulseDot.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TroskyColors.greenA15,
                  width: TroskyBorders.w1p5,
                ),
              ),
            ),
            if (_still)
              halo
            else
              AnimatedBuilder(
                animation: _t,
                builder: (context, child) {
                  // Grows from the drawn halo to the ring, fading as it goes.
                  final t = _t.value;
                  const grow = 64 / 36 - 1;
                  return Opacity(
                    opacity: 1 - (1 - TroskyOpacity.o40) * t,
                    child: Transform.scale(scale: 1 + grow * t, child: child),
                  );
                },
                child: halo,
              ),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: TroskyColors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big countdown (P-07): a green clock, the time left in dark green
/// ("1:42"), and a grey [caption] under it.
class TroskyCountdown extends StatelessWidget {
  const TroskyCountdown({
    super.key,
    required this.time,
    this.caption,
    this.semanticsLabel,
    this.announce = false,
  });

  final String time;
  final String? caption;

  /// What a screen reader says instead of the bare time.
  final String? semanticsLabel;

  /// Read the time out when it changes (once a minute is enough).
  final bool announce;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        liveRegion: announce,
        label: semanticsLabel,
        excludeSemantics: semanticsLabel != null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TroskyIcons.clock(color: TroskyColors.green, size: 20),
            const SizedBox(width: TroskySpacing.s10),
            Text(
              time,
              style: TroskyTypography.heading32ExtraBold.copyWith(
                color: TroskyColors.greenDark,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      if (caption case final caption?) ...[
        const SizedBox(height: TroskySpacing.s4),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TroskyTypography.body12Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}

/// The grey rounded square around an outcome icon, as "No driver accepted
/// your booking" (P-07): 84 px, radius 24. "Booking cancelled" (P-16) has
/// it in pale green ([color]).
class TroskyStatusTile extends StatelessWidget {
  const TroskyStatusTile({
    super.key,
    required this.icon,
    this.color = TroskyColors.qrFrame,
  });

  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TroskyRadii.r24),
      ),
      alignment: Alignment.center,
      child: icon,
    ),
  );
}
