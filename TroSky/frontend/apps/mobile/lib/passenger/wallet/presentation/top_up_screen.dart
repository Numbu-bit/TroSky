// P-18 Top-up (derived). Preset chips + custom amount, MoMo-first.
// Submits POST /wallet/topups with a UUID v4 Idempotency-Key; polls
// /payments/{id}/sync until successful/failed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/wallet_providers.dart';
import '../domain/wallet_args.dart';
import 'wallet_screen.dart' show formatCurrencyGhs;

const List<int> _presets = [20, 50, 100, 200, 500];

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key, required this.args});
  final TopUpArgs args;

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  late final TextEditingController _amount;
  String? _amountError;
  bool _submitting = false;
  String? _idempotencyKey; // Stable across retries of the same attempt.
  String? _failure;
  PaymentResponse? _pending;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.args.presetAmount ?? '100');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryProvider).emit(TelemetryEvent('wallet_topup_opened'));
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _amountValue {
    final v = double.tryParse(_amount.text.trim());
    if (v == null) return null;
    if (v < 1 || v > 1000) return null;
    return v;
  }

  String get _buttonLabel {
    final l10n = AppLocalizations.of(context);
    final v = _amountValue;
    return v == null
        ? l10n.walletTopUpCta(l10n.walletTopUpAmountFallback)
        : l10n.walletTopUpCta(formatCurrencyGhs(v.toStringAsFixed(2)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final v = _amountValue;
    if (v == null) {
      setState(() => _amountError = l10n.walletTopUpAmountError);
      return;
    }
    setState(() {
      _amountError = null;
      _submitting = true;
      _failure = null;
    });
    final key = _idempotencyKey ??= uuidV4();
    final amountString = v.toStringAsFixed(2);
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('wallet_topup_submitted', {'amount': v}));
    final result = await ref
        .read(paymentRepositoryProvider)
        .topUpWallet(
          WalletTopupRequest(
            amount: amountString,
            paymentMethodId: widget.args.method.id,
          ),
          idempotencyKey: key,
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() => _pending = value);
        await _pollUntilDone(value.id);
      case Err(:final failure):
        _handleFailure(failure.code);
    }
  }

  Future<void> _pollUntilDone(String paymentId) async {
    final repo = ref.read(paymentRepositoryProvider);
    const maxTries = 30; // ~90s at 3s intervals
    for (var i = 0; i < maxTries; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final r = await repo.sync(paymentId);
      if (!mounted) return;
      if (r case Ok(:final value)) {
        setState(() => _pending = value);
        if (value.status == PaymentStatus.successful) {
          _handleSuccess(value);
          return;
        }
        if (value.status == PaymentStatus.failed ||
            value.status == PaymentStatus.cancelled) {
          _handleFailure(value.failureReason ?? 'failed');
          return;
        }
      }
    }
    _handleFailure('timeout');
  }

  void _handleSuccess(PaymentResponse payment) {
    setState(() => _submitting = false);
    ref.read(telemetryProvider).emit(TelemetryEvent('wallet_topup_success'));
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(expandedTransactionsProvider);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.walletTopUpSuccess(payment.amount))),
    );
    context.pop();
  }

  void _handleFailure(String reason) {
    setState(() {
      _submitting = false;
      _failure = reason;
    });
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('wallet_topup_failed', {'reason': reason}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.walletTopUpTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            children: [
              _MethodCard(method: widget.args.method),
              const SizedBox(height: TroskySpacing.s16),
              Text(
                l10n.walletTopUpAmount,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
              const SizedBox(height: TroskySpacing.s8),
              Wrap(
                spacing: TroskySpacing.s8,
                runSpacing: TroskySpacing.s8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text(formatCurrencyGhs('$preset.00')),
                      selected: _amountValue == preset.toDouble(),
                      onSelected: (_) {
                        _amount.text = preset.toString();
                        setState(() => _amountError = null);
                        ref
                            .read(telemetryProvider)
                            .emit(
                              TelemetryEvent('wallet_topup_preset_picked', {
                                'amount': preset,
                              }),
                            );
                      },
                    ),
                ],
              ),
              const SizedBox(height: TroskySpacing.s12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() => _amountError = null),
                decoration: InputDecoration(
                  labelText: l10n.walletTopUpCustomAmount,
                  errorText: _amountError,
                  prefixText: '₵ ',
                ),
              ),
              if (_pending != null && _submitting) ...[
                const SizedBox(height: TroskySpacing.s16),
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: TroskySpacing.s12),
                    Expanded(
                      child: Text(
                        l10n.walletTopUpWaiting,
                        style: TroskyTypography.body14Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_failure != null) ...[
                const SizedBox(height: TroskySpacing.s16),
                Text(
                  l10n.walletTopUpFailure,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ],
              const SizedBox(height: TroskySpacing.s24),
              TroskyButton(
                label: _failure != null ? l10n.walletTopUpRetry : _buttonLabel,
                variant: TroskyButtonVariant.primary,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method});
  final PaymentMethodResponse method;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(TroskySpacing.s16),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TroskyColors.mtnYellow,
              borderRadius: BorderRadius.circular(TroskyRadii.r8),
            ),
            alignment: Alignment.center,
            child: const Text('M'),
          ),
          const SizedBox(width: TroskySpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.walletBrandMtnMomo,
                  style: TroskyTypography.body14SemiBold.copyWith(
                    color: TroskyColors.ink,
                  ),
                ),
                Text(
                  method.maskedNumber,
                  style: TroskyTypography.body12Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
