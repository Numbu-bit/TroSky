// P-22 Personal information. Name is editable here; email/phone are
// read-only in this PR (backend change-email/change-phone endpoints
// don't exist yet). Avatar upload is a follow-up PR (would need the
// image_picker dep + Android 13+ permission handling).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/secure_window.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late TextEditingController _name;
  String _initialName = '';
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('pii_edit_opened', const {'field': 'name'}));
      final session = ref.read(sessionControllerProvider).value;
      if (session is SessionAuthenticated) {
        _initialName = session.user.profile?.fullName ?? '';
        _name.text = _initialName;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => _name.text.trim() != _initialName.trim();
  bool get _valid {
    final n = _name.text.trim();
    return n.length >= 2 && n.length <= 100;
  }

  Future<void> _save() async {
    if (!_dirty || !_valid) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await ref
        .read(userRepositoryProvider)
        .updateMe(UserProfileUpdateRequest(fullName: _name.text.trim()));
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('pii_edit_submitted', const {'field': 'name'}),
            );
        // The session user is refreshed through the auth refresh cycle;
        // for immediate P-21 freshness we'd invalidate a user provider.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).piiEditSaved)),
        );
        setState(() {
          _initialName = _name.text.trim();
          _submitting = false;
        });
      case Err(:final failure):
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('pii_edit_failed', {
                'field': 'name',
                'reason': failure.code,
              }),
            );
        setState(() {
          _submitting = false;
          _failure = failure.code;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    final user = session is SessionAuthenticated ? session.user : null;
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.piiTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 100,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.piiNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                _ReadOnlyRow(
                  label: l10n.piiEmailLabel,
                  value: user?.email ?? l10n.piiNotSet,
                  verifiedPill: user?.email != null
                      ? _PillLabel(
                          verified: user!.emailVerified,
                          yes: l10n.profileVerified,
                          no: l10n.profileUnverified,
                        )
                      : null,
                  trailingNote: l10n.piiChangeViaSupport,
                ),
                const SizedBox(height: TroskySpacing.s8),
                _ReadOnlyRow(
                  label: l10n.piiPhoneLabel,
                  value: user?.phoneNumber ?? l10n.piiNotSet,
                  verifiedPill: user != null
                      ? _PillLabel(
                          verified: user.phoneVerified,
                          yes: l10n.profileVerified,
                          no: l10n.profileUnverified,
                        )
                      : null,
                  trailingNote: l10n.piiChangeViaSupport,
                ),
                const SizedBox(height: TroskySpacing.s8),
                _ReadOnlyRow(
                  label: l10n.piiAvatarLabel,
                  value: l10n.profileComingSoon,
                ),
                if (_failure != null) ...[
                  const SizedBox(height: TroskySpacing.s8),
                  Text(
                    l10n.piiEditFailure,
                    style: TroskyTypography.body14Regular.copyWith(
                      color: TroskyColors.red,
                    ),
                  ),
                ],
                const SizedBox(height: TroskySpacing.s16),
                TroskyButton(
                  label: l10n.piiSave,
                  variant: TroskyButtonVariant.primary,
                  onPressed: (_dirty && _valid && !_submitting) ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLabel {
  const _PillLabel({
    required this.verified,
    required this.yes,
    required this.no,
  });
  final bool verified;
  final String yes;
  final String no;
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.verifiedPill,
    this.trailingNote,
  });
  final String label;
  final String value;
  final _PillLabel? verifiedPill;
  final String? trailingNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TroskySpacing.s12),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TroskyTypography.body14SemiBold.copyWith(
                    color: TroskyColors.ink,
                  ),
                ),
              ),
              if (verifiedPill case final pill?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: pill.verified
                        ? TroskyColors.success
                        : TroskyColors.background,
                    borderRadius: BorderRadius.circular(TroskyRadii.r12),
                  ),
                  child: Text(
                    pill.verified ? pill.yes : pill.no,
                    style: TroskyTypography.body12SemiBoldH133.copyWith(
                      color: pill.verified
                          ? TroskyColors.surface
                          : TroskyColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          if (trailingNote != null) ...[
            const SizedBox(height: 4),
            Text(
              trailingNote!,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
