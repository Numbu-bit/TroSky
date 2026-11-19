// P-25 Delete account. Soft-delete per backend/app/api/v1/users.py:95.
// Type-to-confirm (DELETE) + current password, then wipe local stores
// and sign out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';

const String _confirmWord = 'DELETE';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryProvider).emit(TelemetryEvent('account_delete_opened'));
    });
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready =>
      _confirm.text.trim() == _confirmWord && _password.text.isNotEmpty;

  Future<void> _delete() async {
    if (!_ready) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await ref
        .read(userRepositoryProvider)
        .deleteAccount(AccountDeletionRequest(password: _password.text));
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('account_delete_confirmed'));
        // Session sign-out + local store wipe is handled by the session
        // controller's signOut, which clears secure storage and the
        // token store. Routing to Welcome falls out naturally from the
        // router's auth-aware redirect.
        await ref.read(sessionControllerProvider.notifier).signOut();
      case Err(:final failure):
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('account_delete_failed', {'reason': failure.code}),
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
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.deleteAccountTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            children: [
              Text(
                l10n.deleteAccountWarning,
                style: TroskyTypography.heading22ExtraBold.copyWith(
                  color: TroskyColors.red,
                ),
              ),
              const SizedBox(height: TroskySpacing.s12),
              Text(
                l10n.deleteAccountBody,
                style: TroskyTypography.body14Regular.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              // What's deleted — the backend's actual scope is not
              // surfaced on the API today; this list mirrors the client
              // state that gets wiped on sign-out plus the common data a
              // passenger has. Any discrepancy should be flagged in a
              // follow-up once the backend adds a description field.
              Text(
                l10n.deleteAccountScopeTitle,
                style: TroskyTypography.body14SemiBold,
              ),
              const SizedBox(height: TroskySpacing.s4),
              Text(
                l10n.deleteAccountScopeBullets,
                style: TroskyTypography.body14Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              Text(l10n.deleteAccountConfirmInstruction),
              const SizedBox(height: TroskySpacing.s8),
              TextField(
                controller: _confirm,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.deleteAccountConfirmLabel,
                  border: const OutlineInputBorder(),
                ),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: TroskySpacing.s12),
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.deleteAccountPasswordLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_failure != null) ...[
                const SizedBox(height: TroskySpacing.s8),
                Text(
                  l10n.deleteAccountFailure,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ],
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.deleteAccountCta,
                variant: TroskyButtonVariant.danger,
                onPressed: (_ready && !_submitting) ? _delete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
