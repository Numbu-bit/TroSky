// P-29 About TroSky. Shipped to replace the "Coming soon" stub.
//
// Shows the tagline + build info (version + build number via
// package_info_plus), then three rows: Terms of service, Privacy
// policy (both open via url_launcher), Open-source licenses (Flutter's
// built-in showLicensePage).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';

/// Marketing URLs — placeholder until legal pages publish. See PR body
/// for the follow-up to wire real URLs when the pages ship.
const String _termsUrl = 'https://trosky.africa/terms';
const String _privacyUrl = 'https://trosky.africa/privacy';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryProvider).emit(TelemetryEvent('profile_about_opened'));
    });
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } on PlatformException {
      // Non-fatal: the About screen renders without the version block.
    }
  }

  Future<void> _openTerms() async {
    ref.read(telemetryProvider).emit(TelemetryEvent('about_terms_tapped'));
    await launchUrl(Uri.parse(_termsUrl));
  }

  Future<void> _openPrivacy() async {
    ref.read(telemetryProvider).emit(TelemetryEvent('about_privacy_tapped'));
    await launchUrl(Uri.parse(_privacyUrl));
  }

  void _openLicenses() {
    ref.read(telemetryProvider).emit(TelemetryEvent('about_licenses_tapped'));
    final info = _info;
    showLicensePage(
      context: context,
      applicationName: 'TroSky',
      applicationVersion: info == null
          ? null
          : '${info.version} (${info.buildNumber})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = _info;
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.aboutTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: TroskySpacing.s8),
                child: Text(
                  l10n.aboutTagline,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(TroskySpacing.s16),
                decoration: BoxDecoration(
                  color: TroskyColors.surface,
                  borderRadius: BorderRadius.circular(TroskyRadii.r12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.aboutVersionLabel,
                        style: TroskyTypography.body14SemiBold.copyWith(
                          color: TroskyColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      info == null
                          ? '—'
                          : '${info.version} (${info.buildNumber})',
                      style: TroskyTypography.body14Regular.copyWith(
                        color: TroskyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              _AboutRow(
                label: l10n.aboutTerms,
                onTap: _openTerms,
                semanticsLabel: l10n.aboutTerms,
              ),
              _AboutRow(
                label: l10n.aboutPrivacy,
                onTap: _openPrivacy,
                semanticsLabel: l10n.aboutPrivacy,
              ),
              _AboutRow(
                label: l10n.aboutLicenses,
                onTap: _openLicenses,
                semanticsLabel: l10n.aboutLicenses,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
  });
  final String label;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      container: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s8,
            vertical: TroskySpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TroskyTypography.body14SemiBold.copyWith(
                    color: TroskyColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: TroskyColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
