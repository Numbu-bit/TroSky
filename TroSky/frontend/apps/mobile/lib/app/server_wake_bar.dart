import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';

/// "Waking up the server, this can take up to a minute…" across the top of
/// every screen while the server is waking (decision 29). The screen moves
/// down below it, so nothing is covered.
///
/// [child] keeps its place in the tree whether the bar shows or not, so the
/// navigator in it keeps its state.
class ServerWakeBar extends ConsumerWidget {
  const ServerWakeBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waking = ref.watch(serverStatusProvider) == ServerState.waking;
    return Column(
      children: [
        if (waking) const _Bar(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: waking,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The offline banner's look (amber on white, 13 px text), under the status
/// bar, with a spinner as tall as the text in place of Retry: the app
/// retries on its own.
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final style = TroskyTypography.body13Regular.copyWith(
      color: TroskyColors.textPrimary,
    );
    return Material(
      color: TroskyColors.surface,
      child: Container(
        color: TroskyColors.amberA15,
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s16,
          MediaQuery.paddingOf(context).top + TroskySpacing.s8,
          TroskySpacing.s16,
          TroskySpacing.s8,
        ),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              SizedBox.square(
                dimension: style.fontSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TroskyColors.textPrimary,
                ),
              ),
              const SizedBox(width: TroskySpacing.s8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).serverWaking,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
