import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/trosky_icons.dart';
import '../tokens/trosky_borders.dart';
import '../tokens/trosky_colors.dart';
import '../tokens/trosky_radii.dart';
import '../tokens/trosky_shadows.dart';
import '../tokens/trosky_spacing.dart';
import '../tokens/trosky_typography.dart';

/// The P4 phone box as a text field: 54 px, white, 1.5 px border, radius
/// 14, the input shadow, 16 px side padding.
///
/// The design shows one state. Focused fields get a green border and
/// fields with an error a red one, with the message underneath; both
/// colours are from the palette.
class TroskyInputField extends StatefulWidget {
  const TroskyInputField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.hintText,
    this.prefix,
    this.suffix,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// What a screen reader announces for the field (the visible label sits
  /// above it, e.g. [SectionLabel]).
  final String label;

  final FocusNode? focusNode;
  final String? hintText;

  /// Shown before the text, e.g. [TroskyPhonePrefix].
  final Widget? prefix;

  /// Shown after the text, e.g. a show/hide toggle.
  final Widget? suffix;

  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<TroskyInputField> createState() => _TroskyInputFieldState();
}

class _TroskyInputFieldState extends State<TroskyInputField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(TroskyInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;
    final borderColor = error != null
        ? TroskyColors.red
        : _focus.hasFocus
        ? TroskyColors.green
        : TroskyColors.border;
    final note = error ?? widget.helperText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s16),
          decoration: BoxDecoration(
            color: TroskyColors.surface,
            borderRadius: BorderRadius.circular(TroskyRadii.r14),
            border: Border.all(color: borderColor, width: TroskyBorders.w1p5),
            boxShadow: TroskyShadows.input,
          ),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                widget.prefix!,
                const SizedBox(width: TroskySpacing.s12),
              ],
              Expanded(
                // The visible label sits above the box; this one is read
                // out with the field.
                child: MergeSemantics(
                  child: Semantics(
                    label: widget.label,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      textCapitalization: widget.textCapitalization,
                      obscureText: widget.obscureText,
                      autofillHints: widget.autofillHints,
                      inputFormatters: widget.inputFormatters,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: TroskyColors.green,
                      style: TroskyTypography.body14Regular.copyWith(
                        color: TroskyColors.textPrimary,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hintText,
                        hintStyle: TroskyTypography.body14Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: TroskySpacing.s6),
            child: Semantics(
              liveRegion: error != null,
              child: Text(
                note,
                style: TroskyTypography.body12Regular.copyWith(
                  color: error != null
                      ? TroskyColors.red
                      : TroskyColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The P4 country prefix: flag, "+233", down chevron, then a 1 px divider.
/// Tapping it calls [onTap] (Ghana is the only country, so a one-item list).
class TroskyPhonePrefix extends StatelessWidget {
  const TroskyPhonePrefix({
    super.key,
    this.flag = '🇬🇭',
    this.dialCode = '+233',
    this.onTap,
    this.semanticsLabel = 'Country: Ghana, +233',
  });

  final String flag;
  final String dialCode;
  final VoidCallback? onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.only(right: TroskySpacing.s12),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(
                color: TroskyColors.border,
                width: TroskyBorders.w1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: TroskyTypography.body18Regular),
              const SizedBox(width: TroskySpacing.s8),
              Text(
                dialCode,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
              const SizedBox(width: TroskySpacing.s8),
              TroskyIcons.chevronDown(color: TroskyColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "or continue with" (P4): a label between two 1 px lines, 12 px apart.
class TroskyTextDivider extends StatelessWidget {
  const TroskyTextDivider(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: TroskyColors.border)),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: TroskySpacing.s12),
        Text(
          text,
          style: TroskyTypography.body12Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
        const SizedBox(width: TroskySpacing.s12),
        line,
      ],
    );
  }
}

/// The Ghana Card note (P4): a pale green box with a leading emoji and a
/// sentence with one green bold phrase. Display only.
class TroskyInfoNote extends StatelessWidget {
  const TroskyInfoNote({
    super.key,
    required this.emoji,
    required this.before,
    required this.highlight,
    required this.after,
  });

  final String emoji;
  final String before;
  final String highlight;
  final String after;

  @override
  Widget build(BuildContext context) {
    final body = TroskyTypography.body12Regular.copyWith(
      color: TroskyColors.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: TroskySpacing.s12,
        horizontal: TroskySpacing.s14,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.greenA07,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
        border: Border.all(
          color: TroskyColors.greenA15,
          width: TroskyBorders.w1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(emoji, style: TroskyTypography.body16Regular),
          ),
          const SizedBox(width: TroskySpacing.s10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: highlight,
                    style: TroskyTypography.body12Bold.copyWith(
                      color: TroskyColors.green,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Already have an account? Sign in": a grey prompt and a green action.
/// The whole line is one button with a 48 px tap height.
class TroskyTextLink extends StatelessWidget {
  const TroskyTextLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
    this.actionColor = TroskyColors.green,
    this.actionStyle,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  /// Green by default; "Back to Home" on Payment (P-07) is blue.
  final Color actionColor;

  /// Inter 13/600 by default.
  final TextStyle? actionStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: prompt.isEmpty ? action : '$prompt $action',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  if (prompt.isNotEmpty) TextSpan(text: '$prompt '),
                  TextSpan(
                    text: action,
                    style: (actionStyle ?? TroskyTypography.body13SemiBold)
                        .copyWith(color: actionColor),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TroskyTypography.body13Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rules with a check mark each, green once met (e.g. password rules).
class TroskyChecklist extends StatelessWidget {
  const TroskyChecklist({super.key, required this.items});

  /// Each rule's text and whether it is met.
  final List<(String, bool)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, met) in items)
          Padding(
            padding: const EdgeInsets.only(top: TroskySpacing.s6),
            child: Semantics(
              checked: met,
              label: label,
              excludeSemantics: true,
              child: Row(
                children: [
                  TroskyIcons.check(
                    color: met ? TroskyColors.green : TroskyColors.border,
                    size: 14,
                  ),
                  const SizedBox(width: TroskySpacing.s8),
                  Expanded(
                    child: Text(
                      label,
                      style: TroskyTypography.body12Regular.copyWith(
                        color: met
                            ? TroskyColors.textPrimary
                            : TroskyColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A one-time code in [length] boxes styled like [TroskyInputField].
///
/// One hidden text field takes the input, so pasting a whole code and the
/// keyboard's one-time-code suggestion both work.
class TroskyOtpInput extends StatefulWidget {
  const TroskyOtpInput({
    super.key,
    required this.controller,
    required this.label,
    this.length = 6,
    this.focusNode,
    this.hasError = false,
    this.enabled = true,
    this.onCompleted,
  });

  final TextEditingController controller;

  /// What a screen reader announces, e.g. "6-digit code".
  final String label;

  final int length;
  final FocusNode? focusNode;
  final bool hasError;
  final bool enabled;

  /// Called when all [length] digits are in.
  final ValueChanged<String>? onCompleted;

  @override
  State<TroskyOtpInput> createState() => _TroskyOtpInputState();
}

class _TroskyOtpInputState extends State<TroskyOtpInput> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Stack(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: TroskySpacing.s8),
                Expanded(child: _box(i, code)),
              ],
            ],
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            // The boxes are hidden from screen readers; this field is not.
            alwaysIncludeSemantics: true,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              showCursor: false,
              decoration: InputDecoration.collapsed(hintText: widget.label),
              onChanged: (value) {
                if (value.length == widget.length) {
                  widget.onCompleted?.call(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _box(int index, String code) {
    final active =
        _focus.hasFocus &&
        (index == code.length ||
            (code.length == widget.length && index == widget.length - 1));
    final color = widget.hasError
        ? TroskyColors.red
        : active
        ? TroskyColors.green
        : TroskyColors.border;
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r14),
        border: Border.all(color: color, width: TroskyBorders.w1p5),
        boxShadow: TroskyShadows.input,
      ),
      child: Text(
        index < code.length ? code[index] : '',
        style: TroskyTypography.heading20Bold.copyWith(
          color: TroskyColors.textPrimary,
        ),
      ),
    );
  }
}
