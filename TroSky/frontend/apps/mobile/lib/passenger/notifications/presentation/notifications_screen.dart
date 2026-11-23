// P-20 Notifications: Inbox tab + Preferences tab.
//
// Preferences are channel-level (push/sms/email/promo opt-out) because
// that's what the backend models today. Category-level toggles
// (booking/safety/payment) are filed as a Maher gap.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.from = 'profile'});
  final String from;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _openedTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedTracked) return;
    _openedTracked = true;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('notifications_opened', {'from': widget.from}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.notifTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
            bottom: TabBar(
              onTap: (i) {
                ref
                    .read(telemetryProvider)
                    .emit(
                      TelemetryEvent('notifications_tab_changed', {
                        'tab': i == 0 ? 'inbox' : 'preferences',
                      }),
                    );
              },
              tabs: [
                Tab(text: l10n.notifTabInbox),
                Tab(text: l10n.notifTabPrefs),
              ],
            ),
            actions: [_MarkAllReadAction()],
          ),
          body: const TabBarView(children: [_InboxTab(), _PreferencesTab()]),
        ),
      ),
    );
  }
}

class _MarkAllReadAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = switch (ref.watch(unreadCountProvider)) {
      AsyncData(value: Ok(:final value)) => value.unreadCount,
      _ => null,
    };
    return TextButton(
      onPressed: (unread ?? 0) == 0
          ? null
          : () async {
              final result = await ref
                  .read(notificationRepositoryProvider)
                  .markAllRead();
              if (result is Ok) {
                ref
                    .read(telemetryProvider)
                    .emit(TelemetryEvent('notification_mark_all_read'));
                ref
                  ..invalidate(notificationsInboxProvider)
                  ..invalidate(unreadCountProvider);
              }
            },
      child: Text(l10n.notifMarkAllRead),
    );
  }
}

// Convenience on Result<T> for the common "reach into the Ok value" path.
extension OkOrNullExt<T> on Result<T> {
  T? get okOrNull => switch (this) {
    Ok(:final value) => value,
    _ => null,
  };
}

class _InboxTab extends ConsumerWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncList = ref.watch(notificationsInboxProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(notificationsInboxProvider),
      child: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _CenteredRetry(
          onRetry: () => ref.invalidate(notificationsInboxProvider),
        ),
        data: (result) => switch (result) {
          Err() => _CenteredRetry(
            onRetry: () => ref.invalidate(notificationsInboxProvider),
          ),
          Ok(:final value) when value.items.isEmpty => _EmptyInbox(
            label: l10n.notifEmpty,
          ),
          Ok(:final value) => ListView.separated(
            padding: const EdgeInsets.all(TroskySpacing.s12),
            itemCount: value.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _NotificationRow(notif: value.items[i]),
          ),
        },
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notif});
  final NotificationResponse notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !notif.isRead;
    final (icon, color) = _iconFor(notif.category);
    return Semantics(
      label: unread ? '${notif.title}, unread' : notif.title,
      button: true,
      child: InkWell(
        onTap: () async {
          // Mark read optimistically; record analytics and route if we
          // can parse a destination out of `data`. Deep-link details
          // vary by backend contract — this is intentionally a stub.
          final hasDeepLink =
              notif.data.containsKey('route') ||
              notif.data.containsKey('deep_link');
          ref
              .read(telemetryProvider)
              .emit(
                TelemetryEvent('notification_tapped', {
                  'type': notif.category.name,
                  'has_deep_link': hasDeepLink,
                }),
              );
          if (unread) {
            unawaited(
              ref.read(notificationRepositoryProvider).markRead(notif.id).then((
                _,
              ) {
                ref
                  ..invalidate(notificationsInboxProvider)
                  ..invalidate(unreadCountProvider);
              }),
            );
          }
          if (!hasDeepLink) {
            ref
                .read(telemetryProvider)
                .emit(
                  TelemetryEvent('notification_unroutable', {
                    'type': notif.category.name,
                  }),
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).notifOpeningToast),
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(TroskySpacing.s12),
          decoration: BoxDecoration(
            color: unread ? TroskyColors.background : TroskyColors.surface,
            borderRadius: BorderRadius.circular(TroskyRadii.r12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(TroskyRadii.r8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style:
                                (unread
                                        ? TroskyTypography.body14Bold
                                        : TroskyTypography.body14SemiBold)
                                    .copyWith(color: TroskyColors.ink),
                          ),
                        ),
                        Text(
                          _relative(
                            AppLocalizations.of(context),
                            notif.createdAt,
                          ),
                          style: TroskyTypography.body12Regular.copyWith(
                            color: TroskyColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TroskyTypography.body12Regular.copyWith(
                        color: TroskyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 6, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: TroskyColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

(IconData, Color) _iconFor(NotificationCategory c) => switch (c) {
  NotificationCategory.transactional => (
    Icons.directions_bus_outlined,
    TroskyColors.navyDeep,
  ),
  NotificationCategory.safety => (Icons.shield_outlined, TroskyColors.red),
  NotificationCategory.promotional => (
    Icons.local_offer_outlined,
    TroskyColors.mtnYellow,
  ),
};

/// Relative time: "Just now", "{n}m ago", "{n}h ago", "Yesterday",
/// weekday, or `d MMM`.
String relativeTime(AppLocalizations l10n, DateTime at, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = at.toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 1) return l10n.notifTimeJustNow;
  if (diff.inMinutes < 60) return l10n.notifTimeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.notifTimeHours(diff.inHours);
  final today = DateTime(current.year, current.month, current.day);
  final that = DateTime(local.year, local.month, local.day);
  final days = today.difference(that).inDays;
  if (days == 1) return l10n.notifTimeYesterday;
  if (days < 7) return DateFormat('EEE').format(local);
  return DateFormat('d MMM').format(local);
}

String _relative(AppLocalizations l10n, DateTime at) => relativeTime(l10n, at);

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView so RefreshIndicator still works on empty state.
      children: [
        const SizedBox(height: 120),
        const Center(
          child: Icon(
            Icons.inbox_outlined,
            size: 48,
            color: TroskyColors.textSecondary,
          ),
        ),
        const SizedBox(height: TroskySpacing.s12),
        Center(
          child: Text(
            label,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredRetry extends StatelessWidget {
  const _CenteredRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

class _PreferencesTab extends ConsumerWidget {
  const _PreferencesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(notificationPreferencesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _CenteredRetry(
        onRetry: () => ref.invalidate(notificationPreferencesProvider),
      ),
      data: (result) => switch (result) {
        Err() => _CenteredRetry(
          onRetry: () => ref.invalidate(notificationPreferencesProvider),
        ),
        Ok(:final value) => ListView(
          padding: const EdgeInsets.all(TroskySpacing.s12),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: TroskySpacing.s12),
              child: Text(
                l10n.notifPrefsBannerChannelOnly,
                style: TroskyTypography.body12Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
            ),
            _PrefToggle(
              label: l10n.notifPrefsPushEnabled,
              value: value.pushEnabled,
              category: 'push',
              apply: (v) =>
                  NotificationPreferencesUpdateRequest(pushEnabled: v),
            ),
            _PrefToggle(
              label: l10n.notifPrefsSmsEnabled,
              value: value.smsEnabled,
              category: 'sms',
              apply: (v) => NotificationPreferencesUpdateRequest(smsEnabled: v),
            ),
            _PrefToggle(
              label: l10n.notifPrefsEmailEnabled,
              value: value.emailEnabled,
              category: 'email',
              apply: (v) =>
                  NotificationPreferencesUpdateRequest(emailEnabled: v),
            ),
            _PrefToggle(
              label: l10n.notifPrefsPromotionalOptIn,
              value: value.promotionalOptIn,
              category: 'promotional',
              apply: (v) =>
                  NotificationPreferencesUpdateRequest(promotionalOptIn: v),
            ),
          ],
        ),
      },
    );
  }
}

class _PrefToggle extends ConsumerStatefulWidget {
  const _PrefToggle({
    required this.label,
    required this.value,
    required this.category,
    required this.apply,
  });
  final String label;
  final bool value;
  final String category;
  final NotificationPreferencesUpdateRequest Function(bool) apply;

  @override
  ConsumerState<_PrefToggle> createState() => _PrefToggleState();
}

class _PrefToggleState extends ConsumerState<_PrefToggle> {
  late bool _on = widget.value;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: '${widget.label}, ${_on ? "enabled" : "disabled"}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
            ),
            Switch(
              value: _on,
              onChanged: _busy
                  ? null
                  : (v) async {
                      final previous = _on;
                      setState(() {
                        _on = v;
                        _busy = true;
                      });
                      final result = await ref
                          .read(userRepositoryProvider)
                          .updateNotificationPreferences(widget.apply(v));
                      if (!context.mounted) return;
                      if (result is Err) {
                        setState(() => _on = previous);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.notifPrefsSaveFailed)),
                        );
                      } else {
                        ref
                            .read(telemetryProvider)
                            .emit(
                              TelemetryEvent('notification_pref_toggled', {
                                'category': widget.category,
                                'enabled': v,
                              }),
                            );
                        ref.invalidate(notificationPreferencesProvider);
                      }
                      setState(() => _busy = false);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
