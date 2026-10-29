import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../entry/auth/presentation/welcome_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../application/pay_controller.dart';
import '../domain/pay_method.dart';
import 'booking_format.dart';

/// "Pay with" (derived from the cancel sheet of P-16 and the Wallet's
/// payment methods, P9): the TroSky Wallet and its balance (not choosable
/// when it doesn't hold [amount]), the saved MTN MoMo numbers, and a new
/// number, checked here and saved (`POST /users/me/payment-methods`)
/// before it is chosen. Null when the passenger keeps [chosen].
Future<PayMethod?> showPayMethodSheet(
  BuildContext context, {
  required PayOptions options,
  required PayMethod chosen,
  required String amount,
}) => showModalBottomSheet<PayMethod>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  backgroundColor: TroskyColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TroskyRadii.r24)),
  ),
  builder: (context) =>
      _PayMethodSheet(options: options, chosen: chosen, amount: amount),
);

/// A saved number's second line: "024 *** 4567 · My MTN".
String momoDetail(PaymentMethodResponse method) => [
  localMasked(method.maskedNumber),
  if (method.label case final label? when label.trim().isNotEmpty) label,
].join(' · ');

class _PayMethodSheet extends ConsumerStatefulWidget {
  const _PayMethodSheet({
    required this.options,
    required this.chosen,
    required this.amount,
  });

  final PayOptions options;
  final PayMethod chosen;
  final String amount;

  @override
  ConsumerState<_PayMethodSheet> createState() => _PayMethodSheetState();
}

class _PayMethodSheetState extends ConsumerState<_PayMethodSheet> {
  final _phone = TextEditingController();
  bool _adding = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final number = tryNormalizePhoneNumber(_phone.text);
    if (number == null) {
      setState(() => _error = l10n.payNumberInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(paymentRepositoryProvider);
    final result = await repository.addMethod(
      PaymentMethodCreateRequest(
        channel: PaymentChannel.mtnMomo,
        phoneNumber: number,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        ref.invalidate(payOptionsProvider);
        Navigator.of(context).pop(MomoPay(value));
        return;
      case Err(:final failure) when failure.code == 'CONFLICT':
        // Saved already: use that one.
        final saved = await repository.methods();
        if (!mounted) return;
        final match = saved.valueOrNull
            ?.where(
              (m) => m.channel == PaymentChannel.mtnMomo && _same(m, number),
            )
            .firstOrNull;
        if (match != null) {
          ref.invalidate(payOptionsProvider);
          Navigator.of(context).pop(MomoPay(match));
          return;
        }
        setState(() => _error = failureMessage(context, failure));
      case Err(:final failure) when failure.code == 'VALIDATION_ERROR':
        setState(() => _error = l10n.payNumberInvalid);
      case Err(:final failure):
        setState(() => _error = failureMessage(context, failure));
    }
    setState(() => _saving = false);
  }

  /// [method]'s masked number ("+23324•••4567") is [number]'s.
  static bool _same(PaymentMethodResponse method, String number) =>
      method.maskedNumber.startsWith(number.substring(0, 6)) &&
      method.maskedNumber.endsWith(number.substring(number.length - 4));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = widget.options;
    final wallet = options.wallet;
    final covers = options.walletCovers(widget.amount);
    final total = cedis(l10n, widget.amount);
    const divider = Divider(height: 1, color: TroskyColors.border);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s20,
          TroskySpacing.s12,
          TroskySpacing.s20,
          TroskySpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: TroskySheetHandle()),
            const SizedBox(height: TroskySpacing.s16),
            Semantics(
              header: true,
              child: Text(
                l10n.payMethodSheetTitle,
                style: TroskyTypography.heading22ExtraBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s6),
            Text(
              l10n.payMethodSheetSubtitle(total),
              style: TroskyTypography.body13Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            TroskyPayMethodOption(
              kind: TroskyPayMethodKind.wallet,
              title: l10n.payWallet,
              detail: wallet == null
                  ? l10n.payWalletBalanceUnknown
                  : l10n.payWalletBalance(cedis(l10n, wallet.balance)),
              note: covers ? null : l10n.payMethodNotEnough(total),
              selected: widget.chosen is WalletPay,
              onPressed: () => Navigator.of(context).pop(const WalletPay()),
            ),
            for (final number in options.numbers) ...[
              divider,
              TroskyPayMethodOption(
                kind: TroskyPayMethodKind.momo,
                title: l10n.payMomo,
                detail: momoDetail(number),
                selected: widget.chosen == MomoPay(number),
                onPressed: () => Navigator.of(context).pop(MomoPay(number)),
              ),
            ],
            divider,
            const SizedBox(height: TroskySpacing.s4),
            if (!_adding)
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => setState(() => _adding = true),
                  borderRadius: BorderRadius.circular(TroskyRadii.r8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TroskySpacing.s4,
                      ),
                      child: Align(
                        widthFactor: 1,
                        child: Text(
                          l10n.payAddNumber,
                          style: TroskyTypography.body13SemiBold.copyWith(
                            color: TroskyColors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: TroskySpacing.s12),
              PhoneField(
                controller: _phone,
                errorText: _error,
                onSubmitted: _saving ? null : (_) => _save(),
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.payAddNumberSave,
                variant: TroskyButtonVariant.primary,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
