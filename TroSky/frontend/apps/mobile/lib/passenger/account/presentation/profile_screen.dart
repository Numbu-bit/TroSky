// P-21 Profile (Account home). Replaces the sign-out-only placeholder.
// Navy header + four section cards + danger zone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/account_args.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _openedTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedTracked) return;
    _openedTracked = true;
    ref.read(telemetryProvider).emit(TelemetryEvent('profile_opened'));
  }

  void _trackSection(ProfileSection section) {
    ref
        .read(telemetryProvider)
        .emit(
          TelemetryEvent('profile_section_tapped', {
            'section': profileSectionName(section),
          }),
        );
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context);
    ref.read(telemetryProvider).emit(TelemetryEvent('profile_signout_tapped'));
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TroskyColors.surface,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s20,
            TroskySpacing.s8,
            TroskySpacing.s20,
            TroskySpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.profileSignOutConfirmTitle,
                style: TroskyTypography.heading22ExtraBold,
              ),
              const SizedBox(height: TroskySpacing.s8),
              Text(
                l10n.profileSignOutConfirmBody,
                style: TroskyTypography.body14Regular,
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.profileSignOut,
                variant: TroskyButtonVariant.danger,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
              ),
              const SizedBox(height: TroskySpacing.s8),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(false),
                child: Text(l10n.profileSignOutCancel),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(sessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionAsync = ref.watch(sessionControllerProvider);
    final user = switch (sessionAsync.value) {
      SessionAuthenticated(:final user) => user,
      _ => null,
    };
    return AnnotatedRegion(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: SafeArea(
          bottom: false,
          child: user == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(user: user),
                    const SizedBox(height: TroskySpacing.s16),
                    _Section(
                      title: l10n.profileSectionAccount,
                      rows: [
                        _Row(
                          icon: Icons.person_outline,
                          title: l10n.profileRowPersonalInfo,
                          onTap: () {
                            _trackSection(ProfileSection.personalInfo);
                            context.pushNamed(AppRoute.personalInfo.name);
                          },
                        ),
                        _Row(
                          icon: Icons.lock_outline,
                          title: l10n.profileRowChangePassword,
                          onTap: () {
                            _trackSection(ProfileSection.changePassword);
                            context.pushNamed(AppRoute.changePassword.name);
                          },
                        ),
                        _Row(
                          icon: Icons.email_outlined,
                          title: l10n.profileRowChangeEmail,
                          onTap: () {
                            _trackSection(ProfileSection.changeEmail);
                            context.pushNamed(AppRoute.changeEmail.name);
                          },
                        ),
                        // A Change-phone row belongs here when the
                        // backend ships G-change-phone. Hidden until
                        // then to keep the section honest.
                      ],
                    ),
                    _Section(
                      title: l10n.profileSectionPreferences,
                      rows: [
                        _Row(
                          icon: Icons.notifications_outlined,
                          title: l10n.profileRowNotifications,
                          subtitle: notificationsEnabled
                              ? null
                              : l10n.profileComingSoon,
                          onTap: notificationsEnabled
                              ? () {
                                  _trackSection(ProfileSection.notifications);
                                  context.pushNamed(
                                    AppRoute.notifications.name,
                                  );
                                }
                              : null,
                        ),
                        _Row(
                          icon: Icons.favorite_outline,
                          title: l10n.profileRowFavourites,
                          subtitle: favouritesEnabled
                              ? null
                              : l10n.profileComingSoon,
                          onTap: favouritesEnabled
                              ? () {
                                  _trackSection(ProfileSection.favourites);
                                  context.pushNamed(
                                    AppRoute.favouriteRoutes.name,
                                  );
                                }
                              : null,
                        ),
                        _Row(
                          icon: Icons.language_outlined,
                          title: l10n.profileRowLanguage,
                          onTap: () {
                            _trackSection(ProfileSection.language);
                            context.pushNamed(AppRoute.language.name);
                          },
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.profileSectionPayments,
                      rows: [
                        _Row(
                          icon: Icons.account_balance_wallet_outlined,
                          title: l10n.profileRowPaymentMethods,
                          onTap: () {
                            _trackSection(ProfileSection.paymentMethods);
                            context.goNamed(AppRoute.wallet.name);
                          },
                        ),
                        _Row(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.profileRowTransactions,
                          onTap: () {
                            _trackSection(ProfileSection.transactions);
                            context.goNamed(AppRoute.wallet.name);
                          },
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.profileSectionSupport,
                      rows: [
                        _Row(
                          icon: Icons.help_outline,
                          title: l10n.profileRowHelpCentre,
                          onTap: () async {
                            _trackSection(ProfileSection.helpCentre);
                            await launchUrl(
                              Uri.parse(ref.read(envProvider).helpCentreUrl),
                            );
                          },
                        ),
                        _Row(
                          icon: Icons.flag_outlined,
                          title: l10n.profileRowReportProblem,
                          onTap: () {
                            _trackSection(ProfileSection.reportProblem);
                            ref
                                .read(telemetryProvider)
                                .emit(
                                  TelemetryEvent(
                                    'profile_report_problem_opened',
                                  ),
                                );
                            context.pushNamed(AppRoute.reportGeneral.name);
                          },
                        ),
                        _Row(
                          icon: Icons.info_outline,
                          title: l10n.profileRowAbout,
                          onTap: () {
                            _trackSection(ProfileSection.about);
                            context.pushNamed(AppRoute.about.name);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: TroskySpacing.s16),
                    _DangerZone(
                      onSignOut: _confirmSignOut,
                      onDeleteAccount: () {
                        context.pushNamed(AppRoute.deleteAccount.name);
                      },
                    ),
                    const SizedBox(height: TroskySpacing.s24),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final UserResponse user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user.profile?.fullName ?? l10n.profileAnonymousName;
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s20,
        TroskySpacing.s16,
        TroskySpacing.s20,
        TroskySpacing.s24,
      ),
      color: TroskyColors.navyDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: TroskyColors.whiteA20,
            child: Text(
              initial,
              style: TroskyTypography.heading32ExtraBold.copyWith(
                color: TroskyColors.surface,
              ),
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          Text(
            name,
            style: TroskyTypography.heading22ExtraBold.copyWith(
              color: TroskyColors.surface,
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          _VerifiedRow(label: user.phoneNumber, verified: user.phoneVerified),
          if (user.email case final email?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _VerifiedRow(label: email, verified: user.emailVerified),
            ),
        ],
      ),
    );
  }
}

class _VerifiedRow extends StatelessWidget {
  const _VerifiedRow({required this.label, required this.verified});
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.whiteA75,
          ),
        ),
        const SizedBox(width: TroskySpacing.s8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: verified ? TroskyColors.success : TroskyColors.whiteA20,
            borderRadius: BorderRadius.circular(TroskyRadii.r12),
          ),
          child: Text(
            verified ? l10n.profileVerified : l10n.profileUnverified,
            style: TroskyTypography.body12SemiBoldH133.copyWith(
              color: TroskyColors.surface,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TroskyTypography.body12SemiBoldH133.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: TroskyColors.surface,
              borderRadius: BorderRadius.circular(TroskyRadii.r16),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TroskySpacing.s16,
          vertical: TroskySpacing.s14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled ? TroskyColors.ink : TroskyColors.textSecondary,
            ),
            const SizedBox(width: TroskySpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TroskyTypography.body14SemiBold.copyWith(
                      color: enabled
                          ? TroskyColors.ink
                          : TroskyColors.textSecondary,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TroskyTypography.body12Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (enabled)
              const Icon(
                Icons.chevron_right,
                color: TroskyColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onSignOut, required this.onDeleteAccount});
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: TroskyColors.ink,
                side: const BorderSide(color: TroskyColors.dividerSubtle),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.profileSignOut),
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDeleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: TroskyColors.red,
                side: const BorderSide(color: TroskyColors.red),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.profileDeleteAccount),
            ),
          ),
        ],
      ),
    );
  }
}
