import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// The layout of every sign-in and sign-up screen, after Sign Up (P4): the
/// green header, then the form on the page background with `px-6 pt-2` and
/// 16 px between items (`space-y-4`).
///
/// The keyboard never covers the field being typed in or [actionKey] (the
/// main button): when the keyboard opens, the focus moves or the form
/// changes under an open keyboard, it scrolls to show both, the field first
/// if both don't fit.
class AuthLayout extends StatefulWidget {
  const AuthLayout({
    super.key,
    required this.header,
    required this.children,
    required this.actionKey,
  });

  final Widget header;
  final List<Widget> children;

  /// The key of the main button.
  final GlobalKey actionKey;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> with WidgetsBindingObserver {
  double _keyboard = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_reveal);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_reveal);
    super.dispose();
  }

  @override
  void didUpdateWidget(AuthLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The screen changed (e.g. error messages appeared) while the keyboard
    // is up: the button may have been pushed under it.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) _reveal();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    if (keyboard > _keyboard) _reveal();
    _keyboard = keyboard;
  }

  /// After the layout settles: the button into view from below, then the
  /// focused field from above, so the field wins on a tiny screen.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final action = widget.actionKey.currentContext;
      if (action != null && action.mounted) {
        await Scrollable.ensureVisible(
          action,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null && focused.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            focused,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(
      TroskySpacing.s24,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.header,
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TroskySpacing.s24,
                  TroskySpacing.s8,
                  TroskySpacing.s24,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.children.length; i++) ...[
                      if (i > 0) const SizedBox(height: TroskySpacing.s16),
                      widget.children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A form error that belongs to no single field, shown above the button,
/// and read out when it appears.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key, this.action});

  final String message;

  /// E.g. a "Sign in" link after PHONE_ALREADY_REGISTERED.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TroskyTypography.body13Regular.copyWith(
              color: TroskyColors.red,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
