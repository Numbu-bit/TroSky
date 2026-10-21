import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_gradients.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';

/// The green header of Sign Up (P4): the design's 48 px status bar (or the
/// phone's, if taller), the title and subtitle on `greenHeader`, then the
/// wave.
///
/// [onBack] adds the round back button of the P6/P7 headers in place of the
/// 32 px gap above the title.
class TroskyAuthHeader extends StatelessWidget {
  const TroskyAuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.backLabel = 'Back',
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  /// What a screen reader says for the back button.
  final String backLabel;

  /// Height of the design's drawn status bar.
  static const double statusBarHeight = 48;

  @override
  Widget build(BuildContext context) {
    final top = math.max(
      statusBarHeight,
      MediaQuery.viewPaddingOf(context).top,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: TroskyGradients.greenHeader),
          child: Padding(
            // px-6 pb-7
            padding: const EdgeInsets.fromLTRB(
              TroskySpacing.s24,
              0,
              TroskySpacing.s24,
              TroskySpacing.s28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: top),
                if (onBack == null)
                  // The design's two spacers, 12 + 20 px.
                  const SizedBox(height: TroskySpacing.s32)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: TroskySpacing.s14),
                    child: _BackButton(onPressed: onBack!, label: backLabel),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TroskyTypography.heading24ExtraBoldH120.copyWith(
                      color: TroskyColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s4),
                Text(
                  subtitle,
                  style: TroskyTypography.body13Regular.copyWith(
                    color: TroskyColors.whiteA70,
                  ),
                ),
              ],
            ),
          ),
        ),
        const TroskyHeaderWave(),
      ],
    );
  }
}

/// The 24 px wave under the P4 header, stretched to the screen width.
///
/// Drawn as the design draws it: the area under a downward curve, in the
/// page background, on the page background. Nothing green reaches into it,
/// so it doesn't show, and the header ends flat as in the Figma screenshot.
class TroskyHeaderWave extends StatelessWidget {
  const TroskyHeaderWave({super.key});

  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    // `marginTop: -1`.
    return Transform.translate(
      offset: const Offset(0, -1),
      child: const ExcludeSemantics(
        child: CustomPaint(
          size: Size.fromHeight(height),
          painter: _WavePainter(),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 0 0 390 24: M0,0 Q195,24 390,0 L390,24 L0,24 Z, scaled across.
    final w = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w / 2, size.height, w, 0)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = TroskyColors.background);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

/// The 36 px round back button (P6, P7), with a 48 px tap area.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Transform.translate(
    // Keep the visible circle where the design puts it; the extra tap area
    // spreads around it.
    offset: const Offset(-6, 0),
    child: TroskyHeaderIconButton(
      semanticsLabel: label,
      onPressed: onPressed,
      child: TroskyIcons.back(color: TroskyColors.white),
    ),
  );
}

/// A round button on a dark header (P6, P7): a 36 px disc ([diameter]; 44
/// on P-07) at 10 % white around [child], in a 48 px touch area.
class TroskyHeaderIconButton extends StatelessWidget {
  const TroskyHeaderIconButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
    this.selected,
    this.diameter = 36,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;
  final Widget child;

  /// For on/off buttons such as "save this route".
  final bool? selected;

  final double diameter;

  static const double touchSize = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: semanticsLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: touchSize,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TroskyColors.whiteA10,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
