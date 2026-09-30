import 'package:flutter/material.dart';

import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_opacity.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_typography.dart';

/// The exact look of one button in the Figma Make designs.
@immutable
class TroskyButtonVariant {
  const TroskyButtonVariant._({
    required this.height,
    required this.radius,
    required this.background,
    required this.foreground,
    required this.textStyle,
    required this.shadow,
    this.border,
    this.pressedBackground,
  });

  /// White "Next" on Onboarding 1: 54 px pill, 95 % white, dark green
  /// Plus Jakarta Sans 16/700, `0 8px 24px rgba(0,0,0,0.2)`.
  static final onboardingLight = TroskyButtonVariant._(
    height: 54,
    radius: TroskyRadii.r27,
    background: TroskyColors.whiteA95,
    foreground: TroskyColors.greenDark,
    textStyle: TroskyTypography.heading16Bold,
    shadow: TroskyShadows.onboardingLightButton,
  );

  /// Green "Next" on Onboarding 2: 54 px pill, Plus Jakarta Sans 16/700,
  /// `0 8px 24px rgba(14,158,109,0.4)`.
  static final onboardingGreen = TroskyButtonVariant._(
    height: 54,
    radius: TroskyRadii.r27,
    background: TroskyColors.green,
    foreground: TroskyColors.white,
    textStyle: TroskyTypography.heading16Bold,
    shadow: TroskyShadows.onboardingGreenButton,
    pressedBackground: TroskyColors.greenDark,
  );

  /// Green form CTA, "Send OTP" on Sign Up: 54 px pill, Plus Jakarta Sans
  /// 15/700, `0 6px 20px rgba(14,158,109,0.35)`.
  static final primary = TroskyButtonVariant._(
    height: 54,
    radius: TroskyRadii.r27,
    background: TroskyColors.green,
    foreground: TroskyColors.white,
    textStyle: TroskyTypography.heading15Bold,
    shadow: TroskyShadows.primaryButton,
    pressedBackground: TroskyColors.greenDark,
  );

  /// Amber "Get Started" on Onboarding 3: 54 px pill, ink Plus Jakarta Sans
  /// 16/700, `0 8px 24px rgba(244,179,51,0.35)`.
  static final amber = TroskyButtonVariant._(
    height: 54,
    radius: TroskyRadii.r27,
    background: TroskyColors.amber,
    foreground: TroskyColors.ink,
    textStyle: TroskyTypography.heading16Bold,
    shadow: TroskyShadows.amberButton,
  );

  /// White outlined "Continue with Email" on Sign Up: 50 px tall, radius 14,
  /// 1.5 px border, Inter 14/500, no shadow.
  static final outline = TroskyButtonVariant._(
    height: 50,
    radius: TroskyRadii.r14,
    background: TroskyColors.surface,
    foreground: TroskyColors.textPrimary,
    textStyle: TroskyTypography.body14Medium,
    shadow: const [],
    border: const BorderSide(
      color: TroskyColors.border,
      width: TroskyBorders.w1p5,
    ),
  );

  final double height;
  final double radius;
  final Color background;
  final Color foreground;
  final TextStyle textStyle;
  final List<BoxShadow> shadow;
  final BorderSide? border;

  /// Background while pressed. The design defines no pressed state; the green
  /// buttons use greenDark, which globals.css pairs with green, and every
  /// variant drops its shadow while pressed.
  final Color? pressedBackground;
}

/// Full-width button in one of the [TroskyButtonVariant] styles.
///
/// States:
/// * pressed: shadow removed; green variants switch to greenDark.
/// * disabled ([onPressed] null): 70 % opacity and no shadow, the pattern the
///   design uses for the "Go Offline" button (D1).
/// * loading: the label is replaced by a spinner in the label colour and taps
///   are ignored.
class TroskyButton extends StatefulWidget {
  const TroskyButton({
    super.key,
    required this.label,
    required this.variant,
    required this.onPressed,
    this.leading,
    this.loading = false,
    this.pressed = false,
  });

  final String label;
  final TroskyButtonVariant variant;
  final VoidCallback? onPressed;

  /// Icon before the label, 8 px away (the Sign Up email button).
  final Widget? leading;

  final bool loading;

  /// Shows the pressed look without a touch, for the design gallery and
  /// golden tests.
  final bool pressed;

  @override
  State<TroskyButton> createState() => _TroskyButtonState();
}

class _TroskyButtonState extends State<TroskyButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final pressed = _enabled && (_down || widget.pressed);
    final disabled = widget.onPressed == null && !widget.loading;
    final background = pressed
        ? variant.pressedBackground ?? variant.background
        : variant.background;
    final textStyle = variant.textStyle.copyWith(color: variant.foreground);

    final Widget content;
    if (widget.loading) {
      final size = textStyle.fontSize!;
      // The design has no loading state. The spinner is as tall as the label
      // and uses the 2 px stroke of the design's inline icons.
      content = SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant.foreground,
        ),
      );
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final button = Container(
      height: variant.height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(variant.radius),
        border: variant.border == null
            ? null
            : Border.fromBorderSide(variant.border!),
        boxShadow: pressed || disabled ? const [] : variant.shadow,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setDown(true) : null,
          onTapUp: _enabled ? (_) => _setDown(false) : null,
          onTapCancel: _enabled ? () => _setDown(false) : null,
          onTap: _enabled ? widget.onPressed : null,
          child: Opacity(
            opacity: disabled ? TroskyOpacity.disabled : 1,
            child: button,
          ),
        ),
      ),
    );
  }
}
