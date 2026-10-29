import 'package:flutter/material.dart';

import '../icons/trosky_icons.dart';
import '../painting/svg_painting.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_opacity.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';
import 'trips_components.dart';

/// How a passenger pays: what the method's square shows.
enum TroskyPayMethodKind {
  /// The TroSky Wallet: a navy square with a white wallet (P-07).
  wallet,

  /// MTN Mobile Money: the MTN MoMo logo (P9).
  momo,
}

/// The MTN MoMo logo of the Wallet's payment methods (P9), drawn from its
/// SVG: MTN yellow, "MTN", "MoMo", a bar and "Mobile Money" in black. The
/// SVG's Arial isn't bundled, so the words use the body font. 40 px in P9;
/// [size] scales it.
class TroskyMomoLogo extends StatelessWidget {
  const TroskyMomoLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _MomoLogoPainter()),
    ),
  );
}

class _MomoLogoPainter extends CustomPainter {
  const _MomoLogoPainter();

  static TextStyle _text(double size, FontWeight weight, [double alpha = 1]) =>
      TroskyTypography.svgBody9Bold.copyWith(
        fontSize: size,
        fontWeight: weight,
        color: TroskyColors.black.withValues(alpha: alpha),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 40, 40),
        const Radius.circular(TroskyRadii.r10),
      ),
      Paint()..color = TroskyColors.mtnYellow,
    );
    paintSvgText(
      canvas,
      'MTN',
      _text(9, FontWeight.w900),
      const Offset(20, 15),
      anchor: SvgTextAnchor.middle,
    );
    paintSvgText(
      canvas,
      'MoMo',
      _text(7, FontWeight.w700),
      const Offset(20, 25),
      anchor: SvgTextAnchor.middle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 27, 28, 2.5),
        const Radius.circular(1.25),
      ),
      Paint()..color = TroskyColors.black.withValues(alpha: TroskyOpacity.o15),
    );
    paintSvgText(
      canvas,
      'Mobile Money',
      _text(5.5, FontWeight.w600, TroskyOpacity.o60),
      const Offset(20, 35),
      anchor: SvgTextAnchor.middle,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MomoLogoPainter oldDelegate) => false;
}

/// The square for a payment method: the wallet's navy tile (P-07, 44 px,
/// radius 12) or the MoMo logo at the same size.
class TroskyPayMethodIcon extends StatelessWidget {
  const TroskyPayMethodIcon({super.key, required this.kind, this.size = 44});

  final TroskyPayMethodKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => switch (kind) {
    TroskyPayMethodKind.wallet => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TroskyColors.navy,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      alignment: Alignment.center,
      child: TroskyIcons.wallet(color: TroskyColors.white, size: 20),
    ),
    TroskyPayMethodKind.momo => TroskyMomoLogo(size: size),
  };
}

/// "PAY WITH" on Payment (P-07): the chosen method, its balance or number,
/// and "Change". White, radius 16, a 1 px border. The whole card changes
/// the method. [detailColor] tints the second line (a balance too low).
class TroskyPayWithCard extends StatelessWidget {
  const TroskyPayWithCard({
    super.key,
    required this.label,
    required this.kind,
    required this.title,
    required this.detail,
    required this.action,
    required this.onPressed,
    this.detailColor = TroskyColors.textSecondary,
  });

  /// "Pay with"; shown in capitals.
  final String label;
  final TroskyPayMethodKind kind;

  /// "TroSky Wallet", "MTN MoMo".
  final String title;

  /// "Balance ₵128.50", "024 *** 4567".
  final String detail;
  final Color detailColor;

  /// "Change".
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TroskyRadii.r16);
    return Semantics(
      button: true,
      label: '$label: $title, $detail. $action',
      excludeSemantics: true,
      child: Material(
        color: TroskyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(
            color: TroskyColors.border,
            width: TroskyBorders.w1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TroskySpacing.s16,
              TroskySpacing.s14,
              TroskySpacing.s16,
              TroskySpacing.s14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TroskyDetailsLabel(label, bold: false),
                const SizedBox(height: TroskySpacing.s12),
                Row(
                  children: [
                    TroskyPayMethodIcon(kind: kind),
                    const SizedBox(width: TroskySpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TroskyTypography.body14Bold.copyWith(
                              color: TroskyColors.ink,
                            ),
                          ),
                          Text(
                            detail,
                            style: TroskyTypography.body12Regular.copyWith(
                              color: detailColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TroskySpacing.s12),
                    Text(
                      action,
                      style: TroskyTypography.body14Bold.copyWith(
                        color: TroskyColors.blue,
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

/// A payment method on the "Pay with" sheet, as the Wallet lists them (P9):
/// its square, name and number, and a green radio when it is the one
/// chosen. With [note] ("Not enough for ₵16.00", in red) it can't be
/// chosen: the rest of the row is dimmed and [onPressed] isn't called.
class TroskyPayMethodOption extends StatelessWidget {
  const TroskyPayMethodOption({
    super.key,
    required this.kind,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onPressed,
    this.note,
  });

  final TroskyPayMethodKind kind;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onPressed;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final enabled = note == null;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: enabled,
      label: [title, detail, ?note].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s10),
            child: Row(
              children: [
                Opacity(
                  opacity: enabled ? 1 : TroskyOpacity.disabled,
                  child: TroskyPayMethodIcon(kind: kind, size: 40),
                ),
                const SizedBox(width: TroskySpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: enabled ? 1 : TroskyOpacity.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TroskyTypography.body13SemiBold.copyWith(
                                color: TroskyColors.textPrimary,
                              ),
                            ),
                            Text(
                              detail,
                              style: TroskyTypography.body11Regular.copyWith(
                                color: TroskyColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (note case final note?)
                        Text(
                          note,
                          style: TroskyTypography.body11Medium.copyWith(
                            color: TroskyColors.redDark,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: TroskySpacing.s12),
                Opacity(
                  opacity: enabled ? 1 : TroskyOpacity.disabled,
                  child: _Radio(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cancel sheet's radio (P-16), green: choosing how to pay is not a
/// warning.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: TroskyColors.surface,
      border: Border.all(
        color: selected ? TroskyColors.green : TroskyColors.border,
        width: selected ? TroskyBorders.w2 : TroskyBorders.w1p5,
      ),
    ),
    alignment: Alignment.center,
    child: selected
        ? Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: TroskyColors.green,
              shape: BoxShape.circle,
            ),
          )
        : null,
  );
}
