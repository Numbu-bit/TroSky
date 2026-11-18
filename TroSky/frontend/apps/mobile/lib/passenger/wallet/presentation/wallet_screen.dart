// P-17 Wallet home. Dark navy header + two white cards on a light surface:
// Payment Methods and Recent Transactions. No balance card (the design
// doesn't show one). "See all" expands the transactions list in-page —
// no new route — into a filter-chip + larger-page view.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/wallet_providers.dart';
import '../domain/wallet_args.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _expanded = false;
  bool _openedTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedTracked) return;
    _openedTracked = true;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('wallet_opened', {'from': 'tab'}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: l10n.walletTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    TroskySpacing.s16,
                    TroskySpacing.s16,
                    TroskySpacing.s16,
                    TroskySpacing.s24,
                  ),
                  children: [
                    _PaymentMethodsCard(),
                    const SizedBox(height: TroskySpacing.s16),
                    _TransactionsCard(
                      expanded: _expanded,
                      onToggleExpanded: () {
                        final nowExpanded = !_expanded;
                        setState(() => _expanded = nowExpanded);
                        ref
                            .read(telemetryProvider)
                            .emit(
                              TelemetryEvent(
                                nowExpanded
                                    ? 'wallet_transactions_expanded'
                                    : 'wallet_transactions_collapsed',
                              ),
                            );
                      },
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s16,
        TroskySpacing.s16,
        TroskySpacing.s16,
        TroskySpacing.s20,
      ),
      color: TroskyColors.navyDeep,
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TroskyTypography.heading22ExtraBold.copyWith(
            color: TroskyColors.surface,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── Methods

class _PaymentMethodsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncMethods = ref.watch(paymentMethodsProvider);
    return _Card(
      title: l10n.walletPaymentMethodsTitle,
      child: asyncMethods.when(
        loading: () => const _CardSkeleton(),
        error: (_, _) => _CardError(
          onRetry: () {
            ref.invalidate(paymentMethodsProvider);
          },
        ),
        data: (result) => switch (result) {
          Err() => _CardError(
            onRetry: () => ref.invalidate(paymentMethodsProvider),
          ),
          Ok(:final value) => _MethodsList(methods: value),
        },
      ),
    );
  }
}

class _MethodsList extends ConsumerWidget {
  const _MethodsList({required this.methods});
  final List<PaymentMethodResponse> methods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (methods.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.walletNoPaymentMethods,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          _AddMethodButton(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in methods) _MethodRow(method: m),
        const Divider(
          height: TroskySpacing.s16,
          color: TroskyColors.dividerSubtle,
        ),
        _AddMethodButton(),
      ],
    );
  }
}

class _MethodRow extends ConsumerWidget {
  const _MethodRow({required this.method});
  final PaymentMethodResponse method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (brandColor, brandName) = _brand(l10n, method.channel);
    final semantics =
        '$brandName, ${l10n.walletEndingIn(_last4(method.maskedNumber))}'
        '${method.isDefault ? ', ${l10n.walletDefault}' : ''}';
    return Semantics(
      label: semantics,
      button: true,
      child: InkWell(
        onTap: method.isDefault
            ? null
            : () => _openMethodSheet(context, ref, method),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s10),
          child: Row(
            children: [
              _BrandTile(
                color: brandColor,
                text: _brandInitial(method.channel),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: TroskyTypography.body14SemiBold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.maskedNumber,
                      style: TroskyTypography.body12Regular.copyWith(
                        color: TroskyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (method.isDefault) _DefaultPill(label: l10n.walletDefault),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.6
        ? TroskyColors.ink
        : TroskyColors.surface;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TroskyRadii.r8),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TroskyTypography.body13SemiBold.copyWith(color: onColor),
      ),
    );
  }
}

class _DefaultPill extends StatelessWidget {
  const _DefaultPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.background,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Text(
        label,
        style: TroskyTypography.body12SemiBoldH133.copyWith(
          color: TroskyColors.ink,
        ),
      ),
    );
  }
}

class _AddMethodButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      onPressed: () {
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('wallet_add_method_opened'));
        _openAddMethodPicker(context, ref);
      },
      child: Text(l10n.walletAddMethod),
    );
  }
}

// ──────────────────────────────────────────────────────────── Transactions

class _TransactionsCard extends ConsumerWidget {
  const _TransactionsCard({
    required this.expanded,
    required this.onToggleExpanded,
  });
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      title: l10n.walletRecentTransactions,
      trailing: TextButton(
        onPressed: onToggleExpanded,
        child: Text(expanded ? l10n.walletSeeLess : l10n.walletSeeAll),
      ),
      child: expanded ? _ExpandedTransactions() : _RecentTransactions(),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentTransactionsProvider);
    return async.when(
      loading: () => const _CardSkeleton(),
      error: (_, _) =>
          _CardError(onRetry: () => ref.invalidate(recentTransactionsProvider)),
      data: (result) => switch (result) {
        Err() => _CardError(
          onRetry: () => ref.invalidate(recentTransactionsProvider),
        ),
        Ok(:final value) when value.items.isEmpty => _EmptyTransactions(),
        Ok(:final value) => Column(
          children: [for (final t in value.items) _TransactionRow(txn: t)],
        ),
      },
    );
  }
}

class _ExpandedTransactions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(transactionFilterProvider);
    final async = ref.watch(expandedTransactionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterChips(selected: filter),
        const SizedBox(height: TroskySpacing.s8),
        async.when(
          loading: () => const _CardSkeleton(),
          error: (_, _) => _CardError(
            onRetry: () => ref.invalidate(expandedTransactionsProvider),
          ),
          data: (result) => switch (result) {
            Err() => _CardError(
              onRetry: () => ref.invalidate(expandedTransactionsProvider),
            ),
            Ok(:final value) => _buildGrouped(
              context,
              value.items,
              filter,
              l10n,
            ),
          },
        ),
      ],
    );
  }

  Widget _buildGrouped(
    BuildContext context,
    List<WalletTransactionResponse> items,
    TransactionFilter filter,
    AppLocalizations l10n,
  ) {
    final filtered = items
        .where((t) => filterIncludes(filter, kindFor(t)))
        .toList();
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s16),
        child: Text(
          l10n.walletNoMatches,
          style: TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    // Simple day grouping; the design uses "Today / Yesterday / EEE d MMM".
    final grouped = <String, List<WalletTransactionResponse>>{};
    for (final t in filtered) {
      final key = _dayHeader(t.createdAt);
      (grouped[key] ??= []).add(t);
    }
    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.key,
                style: TroskyTypography.body12SemiBoldH133.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
            ),
          ),
          for (final t in entry.value) _TransactionRow(txn: t),
        ],
      ],
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.selected});
  final TransactionFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget chip(TransactionFilter f, String label) {
      final active = selected == f;
      return Padding(
        padding: const EdgeInsets.only(right: TroskySpacing.s8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) {
            ref.read(transactionFilterProvider.notifier).set(f);
            ref
                .read(telemetryProvider)
                .emit(
                  TelemetryEvent('wallet_filter_changed', {'type': f.name}),
                );
          },
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          chip(TransactionFilter.all, l10n.walletFilterAll),
          chip(TransactionFilter.topUps, l10n.walletFilterTopUps),
          chip(TransactionFilter.trips, l10n.walletFilterTrips),
          chip(TransactionFilter.refunds, l10n.walletFilterRefunds),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.txn});
  final WalletTransactionResponse txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kind = kindFor(txn);
    final isCredit = txn.entryType == WalletEntryType.credit;
    final amountText = '${isCredit ? '+' : ''}${formatCurrencyGhs(txn.amount)}';
    final amountColor = isCredit ? TroskyColors.success : TroskyColors.ink;
    final (iconData, bg) = _kindIcon(kind);
    return Semantics(
      label:
          '${_kindLabel(l10n, kind)}, $amountText, ${_timeLabel(txn.createdAt)}',
      button: true,
      child: InkWell(
        onTap: () {
          ref
              .read(telemetryProvider)
              .emit(
                TelemetryEvent('wallet_transaction_opened', {
                  'type': kind.name,
                }),
              );
          _openTransactionDetail(context, txn);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(TroskyRadii.r8),
                ),
                alignment: Alignment.center,
                child: Icon(iconData, size: 20, color: TroskyColors.ink),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TroskyTypography.body14SemiBold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeLabel(txn.createdAt),
                      style: TroskyTypography.body12Regular.copyWith(
                        color: TroskyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amountText,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s16),
      child: Text(
        l10n.walletTransactionsEmpty,
        textAlign: TextAlign.center,
        style: TroskyTypography.body14Regular.copyWith(
          color: TroskyColors.textSecondary,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Primitives

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r16),
      ),
      padding: const EdgeInsets.all(TroskySpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TroskyTypography.heading18Bold.copyWith(
                    color: TroskyColors.ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: TroskySpacing.s8),
          child,
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: TroskySpacing.s16),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _CardError extends StatelessWidget {
  const _CardError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.walletErrorLoad,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.walletRetry)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Formatters

final NumberFormat _currencyGhs = NumberFormat.currency(
  locale: 'en_GH',
  symbol: '₵',
  decimalDigits: 2,
);

/// Public so unit tests can import and assert the output.
String formatCurrencyGhs(String amountDecimalString) {
  final v = double.tryParse(amountDecimalString) ?? 0;
  return _currencyGhs.format(v);
}

String _timeLabel(DateTime at) {
  final now = DateTime.now();
  final local = at.toLocal();
  final localDay = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(localDay).inDays;
  final hhmm = DateFormat('HH:mm').format(local);
  if (diff == 0) return 'Today $hhmm';
  if (diff == 1) return 'Yesterday $hhmm';
  return DateFormat('EEE d MMM').format(local);
}

String _dayHeader(DateTime at) {
  final now = DateTime.now();
  final local = at.toLocal();
  final localDay = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(localDay).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE d MMM').format(local);
}

String _last4(String maskedNumber) {
  final digits = maskedNumber.replaceAll(RegExp(r'\D'), '');
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
}

(Color, String) _brand(AppLocalizations l10n, PaymentChannel channel) {
  return switch (channel) {
    PaymentChannel.mtnMomo => (TroskyColors.mtnYellow, l10n.walletBrandMtnMomo),
    PaymentChannel.telecelCash => (
      TroskyColors.telecelRed,
      l10n.walletBrandTelecelCash,
    ),
    PaymentChannel.airteltigoMoney => (
      TroskyColors.telecelRed,
      l10n.walletBrandAirteltigo,
    ),
    PaymentChannel.card => (TroskyColors.visaNavy, l10n.walletBrandVisa),
    PaymentChannel.wallet => (TroskyColors.navyDeep, l10n.walletBrandWallet),
  };
}

String _brandInitial(PaymentChannel channel) => switch (channel) {
  PaymentChannel.mtnMomo => 'M',
  PaymentChannel.telecelCash => 'T',
  PaymentChannel.airteltigoMoney => 'A',
  PaymentChannel.card => 'V',
  PaymentChannel.wallet => 'W',
};

(IconData, Color) _kindIcon(TransactionKind kind) => switch (kind) {
  TransactionKind.topUp => (Icons.add_circle_outline, TroskyColors.background),
  TransactionKind.trip => (
    Icons.directions_bus_outlined,
    TroskyColors.background,
  ),
  TransactionKind.refund => (Icons.undo_rounded, TroskyColors.background),
  TransactionKind.earning => (Icons.payments_outlined, TroskyColors.background),
  TransactionKind.withdrawal => (
    Icons.account_balance_wallet_outlined,
    TroskyColors.background,
  ),
  TransactionKind.adjustment => (Icons.tune_rounded, TroskyColors.background),
};

String _kindLabel(AppLocalizations l10n, TransactionKind kind) =>
    switch (kind) {
      TransactionKind.topUp => l10n.walletKindTopUp,
      TransactionKind.trip => l10n.walletKindTrip,
      TransactionKind.refund => l10n.walletKindRefund,
      TransactionKind.earning => l10n.walletKindEarning,
      TransactionKind.withdrawal => l10n.walletKindWithdrawal,
      TransactionKind.adjustment => l10n.walletKindAdjustment,
    };

// ─────────────────────────────────────────────────────────────── Sheets

void _openMethodSheet(
  BuildContext context,
  WidgetRef ref,
  PaymentMethodResponse method,
) {
  final l10n = AppLocalizations.of(context);
  ref
      .read(telemetryProvider)
      .emit(
        TelemetryEvent('wallet_payment_method_tapped', {
          'type': method.channel.name,
        }),
      );
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: TroskySheetHandle()),
            const SizedBox(height: TroskySpacing.s12),
            Text(
              method.maskedNumber,
              style: TroskyTypography.heading18Bold.copyWith(
                color: TroskyColors.ink,
              ),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.walletSetAsDefault,
              variant: TroskyButtonVariant.outline,
              onPressed: () async {
                Navigator.of(sheetCtx).pop();
                final res = await ref
                    .read(paymentRepositoryProvider)
                    .updateMethod(
                      method.id,
                      const PaymentMethodUpdateRequest(isDefault: true),
                    );
                if (!sheetCtx.mounted) return;
                if (res is Ok) {
                  ref
                      .read(telemetryProvider)
                      .emit(
                        TelemetryEvent('wallet_payment_method_set_default', {
                          'type': method.channel.name,
                        }),
                      );
                  ref.invalidate(paymentMethodsProvider);
                }
              },
            ),
            const SizedBox(height: TroskySpacing.s8),
            TroskyButton(
              label: l10n.walletRemoveMethod,
              variant: TroskyButtonVariant.danger,
              onPressed: () async {
                Navigator.of(sheetCtx).pop();
                final res = await ref
                    .read(paymentRepositoryProvider)
                    .deleteMethod(method.id);
                if (!sheetCtx.mounted) return;
                if (res is Ok) {
                  ref
                      .read(telemetryProvider)
                      .emit(
                        TelemetryEvent('wallet_payment_method_removed', {
                          'type': method.channel.name,
                        }),
                      );
                  ref.invalidate(paymentMethodsProvider);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _openAddMethodPicker(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: TroskySheetHandle()),
            const SizedBox(height: TroskySpacing.s12),
            Text(
              l10n.walletAddMethodTitle,
              style: TroskyTypography.heading18Bold.copyWith(
                color: TroskyColors.ink,
              ),
            ),
            const SizedBox(height: TroskySpacing.s12),
            _PickerRow(
              label: l10n.walletBrandMtnMomo,
              enabled: true,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _showMomoForm(context, ref);
              },
            ),
            _PickerRow(
              label: l10n.walletBrandTelecelCash,
              enabled: false,
              comingSoon: l10n.walletComingSoon,
            ),
            _PickerRow(
              label: l10n.walletBrandVisa,
              enabled: false,
              comingSoon: l10n.walletComingSoon,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.enabled,
    this.onTap,
    this.comingSoon,
  });
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final String? comingSoon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s12),
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
              if (!enabled)
                if (comingSoon case final text?)
                  Text(
                    text,
                    style: TroskyTypography.body12Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMomoForm(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TroskySpacing.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: TroskySheetHandle()),
              const SizedBox(height: TroskySpacing.s12),
              Text(
                l10n.walletMomoFormTitle,
                style: TroskyTypography.heading18Bold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
              const SizedBox(height: TroskySpacing.s12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.walletMomoFormPhoneLabel,
                  hintText: '024 123 4567',
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.walletAddMethod,
                variant: TroskyButtonVariant.primary,
                onPressed: () async {
                  final raw = controller.text.trim();
                  final e164 = _toE164(raw);
                  if (e164 == null) return;
                  final res = await ref
                      .read(paymentRepositoryProvider)
                      .addMethod(
                        PaymentMethodCreateRequest(
                          channel: PaymentChannel.mtnMomo,
                          phoneNumber: e164,
                        ),
                      );
                  if (!sheetCtx.mounted) return;
                  if (res is Ok<PaymentMethodResponse>) {
                    ref
                        .read(telemetryProvider)
                        .emit(
                          TelemetryEvent('wallet_add_method_submitted', {
                            'type': 'mtn_momo',
                          }),
                        );
                    ref.invalidate(paymentMethodsProvider);
                    Navigator.of(sheetCtx).pop();
                    unawaitedGo(
                      context,
                      AppRoute.topUp.name,
                      extra: TopUpArgs(method: res.value),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Light E.164 normaliser: accepts "024…", "24…", or "+233…" for Ghana.
String? _toE164(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('233')) return '+$digits';
  if (digits.startsWith('0') && digits.length == 10) {
    return '+233${digits.substring(1)}';
  }
  if (digits.length == 9) return '+233$digits';
  return null;
}

void unawaitedGo(BuildContext context, String name, {Object? extra}) {
  context.pushNamed(name, extra: extra);
}

// ───────────────────────────────────────────────── Transaction detail sheet

void _openTransactionDetail(
  BuildContext context,
  WalletTransactionResponse txn,
) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: TroskySheetHandle()),
            const SizedBox(height: TroskySpacing.s12),
            Text(
              txn.description,
              style: TroskyTypography.heading18Bold.copyWith(
                color: TroskyColors.ink,
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              '${txn.entryType == WalletEntryType.credit ? '+' : '-'}${formatCurrencyGhs(txn.amount)}',
              style: TroskyTypography.heading22ExtraBold.copyWith(
                color: TroskyColors.ink,
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              '${l10n.walletTxnReference}: ${txn.id}',
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            if (txn.referenceType == WalletReferenceType.bookingPayment &&
                txn.referenceId != null) ...[
              const SizedBox(height: TroskySpacing.s12),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                },
                child: Text(l10n.walletViewTrip),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
