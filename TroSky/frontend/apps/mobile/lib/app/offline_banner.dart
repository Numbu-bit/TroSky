import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';

/// "You're offline. Showing your last saved details." with Retry, after an
/// offline start (decision 9). Retry checks the session again; the banner
/// goes once the backend answers.
///
/// When the phone has internet but the server didn't answer, it says so
/// instead (decision 29).
///
/// [floating] draws it as a card over a map, on a white base so the map
/// doesn't show through.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unreachable =
        ref.watch(serverStatusProvider) == ServerState.unreachable;
    final radius = BorderRadius.circular(floating ? TroskyRadii.r12 : 0);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: radius,
          boxShadow: floating ? TroskyShadows.mapFab : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: TroskyColors.amberA15,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.only(
            left: TroskySpacing.s16,
            right: TroskySpacing.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TroskySpacing.s8,
                  ),
                  child: Text(
                    unreachable
                        ? l10n.serverUnreachableBanner
                        : l10n.offlineBanner,
                    style: TroskyTypography.body13Regular.copyWith(
                      color: TroskyColors.textPrimary,
                    ),
                  ),
                ),
              ),
              TroskyTextLink(
                prompt: '',
                action: l10n.offlineRetry,
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).restore(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
