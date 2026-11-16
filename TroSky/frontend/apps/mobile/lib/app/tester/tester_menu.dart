// The hidden tester menu. Enabled on staging and demo builds only, with
// `--dart-define=TESTER_MENU=true`; absent on release builds (the const
// below is `false`, and Dart's tree-shaker drops the whole code path).
//
// Trigger: 7 taps in 3 s on the Home greeting ("Good morning, …"). The
// trigger location is spelled out in the sheet's header so a tester can
// find it again.
//
// The menu NEVER reveals driver or admin credentials, API secrets or
// tokens. Build info is Commit SHA, Build date (UTC), API base URL, and
// Mode.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../entry/onboarding/data/onboarding_store.dart';
import '../../l10n/app_localizations.dart';
import '../routes.dart';

/// Whole feature's on/off switch. `const bool.fromEnvironment` means
/// Dart constant-folds every `if (testerMenuEnabled) { ... }` branch and
/// the tree-shaker removes the unreferenced symbols from release builds.
const bool testerMenuEnabled = bool.fromEnvironment('TESTER_MENU');

/// The tap window: 7 taps within this window opens the sheet.
const Duration _tapWindow = Duration(seconds: 3);
const int _tapCount = 7;

/// Wrap any widget to turn 7 taps within 3 s into an open tester menu.
/// Does nothing — passes `child` through unchanged — when the feature
/// is off, so the hit test returns the underlying widget.
class TesterMenuTapCounter extends StatefulWidget {
  const TesterMenuTapCounter({super.key, required this.child});

  final Widget child;

  @override
  State<TesterMenuTapCounter> createState() => _TesterMenuTapCounterState();
}

class _TesterMenuTapCounterState extends State<TesterMenuTapCounter> {
  final List<DateTime> _taps = [];
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!testerMenuEnabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: widget.child,
    );
  }

  void _tap() {
    if (_open) return;
    final now = DateTime.now();
    _taps.removeWhere((t) => now.difference(t) > _tapWindow);
    _taps.add(now);
    if (_taps.length >= _tapCount) {
      _taps.clear();
      _open = true;
      unawaited(showTesterMenu(context).whenComplete(() => _open = false));
    }
  }

  @override
  void deactivate() {
    _taps.clear();
    super.deactivate();
  }
}

/// Opens the tester menu as a modal bottom sheet, returning when the
/// passenger dismisses it. Does nothing when the feature is off.
Future<void> showTesterMenu(BuildContext context) async {
  if (!testerMenuEnabled) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (context) => const TesterMenuSheet(key: Key('tester-menu-sheet')),
  );
}

/// The menu itself. Named and exported so the build-size check can grep
/// for the symbol in the release APK (it must be absent).
class TesterMenuSheet extends ConsumerStatefulWidget {
  const TesterMenuSheet({super.key});

  @override
  ConsumerState<TesterMenuSheet> createState() => _TesterMenuSheetState();
}

class _TesterMenuSheetState extends ConsumerState<TesterMenuSheet> {
  PackageInfo? _package;
  bool _topUpSupported = true;
  String? _toast;

  @override
  void initState() {
    super.initState();
    unawaited(
      PackageInfo.fromPlatform().then((p) {
        if (mounted) setState(() => _package = p);
      }),
    );
  }

  void _say(String text) {
    setState(() => _toast = text);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _wakeServer() async {
    final l10n = AppLocalizations.of(context);
    final wake = ref.read(serverWakeProvider);
    if (wake == null) {
      _say(l10n.testerMenuWakeMockMode);
      return;
    }
    await wake.retry();
    if (!mounted) return;
    _say(
      wake.state == ServerState.awake
          ? l10n.testerMenuWakeOk
          : l10n.testerMenuWakeFail,
    );
  }

  Future<void> _topUp() async {
    final l10n = AppLocalizations.of(context);
    final phone = switch (ref.read(sessionControllerProvider).value) {
      SessionAuthenticated(:final user) => user.phoneNumber,
      _ => null,
    };
    if (phone == null) {
      _say(l10n.testerMenuTopUpSignIn);
      return;
    }
    final result = await ref
        .read(paymentRepositoryProvider)
        .topUpWallet(
          WalletTopupRequest(
            amount: '100.00',
            channel: PaymentChannel.mtnMomo,
            payerPhoneNumber: phone,
          ),
          idempotencyKey:
              'tester-topup-${DateTime.now().microsecondsSinceEpoch}',
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        // No watchable wallet provider yet; fetch once so the toast
        // reports the new balance. When a wallet screen lands and keeps
        // a provider, swap this for `ref.invalidate(walletProvider)`.
        final balance = await ref.read(paymentRepositoryProvider).wallet();
        if (!mounted) return;
        _say(
          l10n.testerMenuTopUpOk(switch (balance) {
            Ok(:final value) => value.balance,
            _ => '?',
          }),
        );
      case Err(:final failure) when failure.code == 'NOT_FOUND':
        // Backend predates PR #53: hide the row on next sheet open.
        setState(() => _topUpSupported = false);
        debugPrint(
          'tester-menu: wallet top-up endpoint missing (G: PR #53 not deployed)',
        );
        _say(l10n.testerMenuTopUpMissing);
      case Err(:final failure):
        _say(l10n.testerMenuTopUpError(failure.message));
    }
  }

  Future<void> _showOnboarding() async {
    final router = GoRouter.of(context);
    await ref.read(onboardingStoreProvider).reset();
    if (!mounted) return;
    Navigator.of(context).pop();
    router.goNamed(AppRoute.onboarding.name);
  }

  Future<void> _signOutAndWipe() async {
    final router = GoRouter.of(context);
    await ref.read(sessionControllerProvider.notifier).signOut();
    // The app's own SharedPreferences keys. No system keys, no other
    // apps' data. Secure storage (refresh tokens) is cleared by
    // signOut above.
    final prefs = SharedPreferencesAsync();
    for (final key in const [
      SharedPreferencesOnboardingStore.key,
      // Add the app's other prefs keys here as they appear. Keeping an
      // allow-list (not `prefs.clear()`) means we never wipe keys a
      // plugin stores without us knowing.
    ]) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    router.goNamed(AppRoute.welcome.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(envProvider);
    final mode = env.apiMode == ApiMode.mock
        ? l10n.testerMenuModeMock
        : l10n.testerMenuModeLive;
    final sha = const String.fromEnvironment('GIT_COMMIT', defaultValue: '');
    final buildDate = const String.fromEnvironment(
      'BUILD_DATE',
      defaultValue: '',
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final info = _package;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s20,
          TroskySpacing.s12,
          TroskySpacing.s20,
          TroskySpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: TroskySheetHandle()),
            const SizedBox(height: TroskySpacing.s16),
            Semantics(
              header: true,
              child: Text(
                l10n.testerMenuTitle,
                style: TroskyTypography.heading22ExtraBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s4),
            Text(
              l10n.testerMenuTriggerNote,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s16),
            _BuildInfoBlock(
              shortSha: sha.isEmpty ? l10n.testerMenuNotSet : sha,
              buildDate: buildDate.isEmpty ? l10n.testerMenuNotSet : buildDate,
              apiBaseUrl: env.apiBaseUrl,
              mode: mode,
              appVersion: info == null
                  ? ''
                  : '${info.version}+${info.buildNumber}',
            ),
            const SizedBox(height: TroskySpacing.s12),
            _ActionRow(
              label: l10n.testerMenuWakeServer,
              onPressed: _wakeServer,
            ),
            if (_topUpSupported)
              _ActionRow(label: l10n.testerMenuTopUp, onPressed: _topUp),
            _ActionRow(
              label: l10n.testerMenuShowOnboarding,
              onPressed: _showOnboarding,
            ),
            _ActionRow(
              label: l10n.testerMenuSignOut,
              onPressed: _signOutAndWipe,
              destructive: true,
            ),
            if (_toast case final toast?) ...[
              const SizedBox(height: TroskySpacing.s8),
              Text(
                toast,
                style: TroskyTypography.body12Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuildInfoBlock extends StatelessWidget {
  const _BuildInfoBlock({
    required this.shortSha,
    required this.buildDate,
    required this.apiBaseUrl,
    required this.mode,
    required this.appVersion,
  });

  final String shortSha;
  final String buildDate;
  final String apiBaseUrl;
  final String mode;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TroskyTypography.body12SemiBoldH133.copyWith(
                color: TroskyColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(TroskySpacing.s12),
      decoration: BoxDecoration(
        color: TroskyColors.background,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.testerMenuBuildInfo,
            style: TroskyTypography.body13Medium.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: TroskySpacing.s6),
          row(l10n.testerMenuCommit, shortSha),
          row(l10n.testerMenuBuilt, buildDate),
          row(l10n.testerMenuMode, mode),
          row(l10n.testerMenuApiBase, apiBaseUrl),
          if (appVersion.isNotEmpty) row(l10n.testerMenuAppVersion, appVersion),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TroskyButton(
        label: label,
        variant: destructive
            ? TroskyButtonVariant.danger
            : TroskyButtonVariant.outline,
        onPressed: () => unawaited(onPressed()),
      ),
    );
  }
}
