// P-28 Language. Display-only: app_en.arb is the only locale today.
// Shipped to replace the "Coming soon" stub. More locales (tw, ha, fr)
// are a later step — this screen then grows a selector.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('profile_language_opened'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.languageTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: l10n.languageCurrentSemantics,
                  container: true,
                  child: Container(
                    padding: const EdgeInsets.all(TroskySpacing.s16),
                    decoration: BoxDecoration(
                      color: TroskyColors.surface,
                      borderRadius: BorderRadius.circular(TroskyRadii.r12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language_outlined,
                          color: TroskyColors.ink,
                        ),
                        const SizedBox(width: TroskySpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.languageEnglishName,
                                style: TroskyTypography.body14SemiBold.copyWith(
                                  color: TroskyColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.languageEnglishCode,
                                style: TroskyTypography.body12Regular.copyWith(
                                  color: TroskyColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TroskySpacing.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TroskyColors.green,
                            borderRadius: BorderRadius.circular(
                              TroskyRadii.r12,
                            ),
                          ),
                          child: Text(
                            l10n.languageCurrentPill,
                            style: TroskyTypography.body12SemiBold.copyWith(
                              color: TroskyColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s16),
                Text(
                  l10n.languageMoreComingSoon,
                  textAlign: TextAlign.center,
                  style: TroskyTypography.body12Regular.copyWith(
                    color: TroskyColors.textSecondary,
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
