import 'package:flutter/material.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'booking_format.dart';

/// A centred status title and the sentence under it, as on P-07's states.
/// [large] is the title of an outcome ("No driver accepted your booking").
class PaymentMessage extends StatelessWidget {
  const PaymentMessage({
    super.key,
    required this.title,
    required this.body,
    this.large = false,
  });

  final String title;
  final String body;
  final bool large;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s18),
    child: Column(
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            // Two-line titles sit 1.25 apart in the screenshots.
            style:
                (large
                        ? TroskyTypography.heading22ExtraBold
                        : TroskyTypography.heading20ExtraBold)
                    .copyWith(color: TroskyColors.ink, height: 1.25),
          ),
        ),
        const SizedBox(height: TroskySpacing.s8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// No connection while waiting: the offline banner's amber, as a note.
class PaymentOfflineNote extends StatelessWidget {
  const PaymentOfflineNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s10,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.amberA15,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TroskyTypography.body13Regular.copyWith(
          color: TroskyColors.textPrimary,
        ),
      ),
    ),
  );
}

/// Approve on your phone (P-08, derived from P-07 waiting for the driver):
/// the pulse, what to do on the phone, and the time left on the seat hold,
/// which is the time left to approve.
class PayApproving extends StatelessWidget {
  const PayApproving({
    super.key,
    required this.amount,
    required this.number,
    required this.left,
    required this.offline,
  });

  /// "₵16.00".
  final String amount;

  /// "024 *** 4567"; null when Payment was reopened and doesn't know it.
  final String? number;
  final Duration left;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = timeLeft(left);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TroskySpacing.s32),
        const Center(child: TroskyPulseDot()),
        const SizedBox(height: TroskySpacing.s24),
        PaymentMessage(
          title: l10n.payApproveTitle,
          body: switch (number) {
            final number? => l10n.payApproveBody(amount, number),
            null => l10n.payApproveBodyNoNumber(amount),
          },
        ),
        const SizedBox(height: TroskySpacing.s14),
        TroskyCountdown(
          time: time,
          caption: l10n.payApproveCaption,
          semanticsLabel: l10n.payApproveTimeLeft(time),
          announce: left.inSeconds % 30 == 0,
        ),
        if (offline) ...[
          const SizedBox(height: TroskySpacing.s16),
          PaymentOfflineNote(l10n.paymentOffline),
        ],
      ],
    );
  }
}

/// How a payment ended (P-09, derived from P-07's "No driver accepted"):
/// the outcome's tile, its title and what it means, and on success the
/// booking reference.
class PayOutcome extends StatelessWidget {
  const PayOutcome({
    super.key,
    required this.tile,
    required this.title,
    required this.body,
    this.reference,
  });

  /// Paid: a green check (as "Booking cancelled", P-16). Failed: a red
  /// cross. Time ran out: a grey clock.
  final TroskyStatusTile tile;
  final String title;
  final String body;
  final String? reference;

  /// Paid.
  static TroskyStatusTile get paid => TroskyStatusTile(
    color: TroskyColors.greenA10,
    icon: TroskyIcons.checkCircle(color: TroskyColors.green),
  );

  /// Not paid.
  static TroskyStatusTile get failed => TroskyStatusTile(
    color: TroskyColors.redA10,
    icon: TroskyIcons.circleX(color: TroskyColors.red),
  );

  /// The hold ran out.
  static TroskyStatusTile get timedOut => TroskyStatusTile(
    icon: TroskyIcons.clock(color: TroskyColors.textSecondary, size: 36),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TroskySpacing.s32),
        Center(child: tile),
        const SizedBox(height: TroskySpacing.s24),
        PaymentMessage(title: title, body: body, large: true),
        if (reference case final reference?) ...[
          const SizedBox(height: TroskySpacing.s20),
          Semantics(
            label: '${l10n.payReferenceLabel}: $reference',
            excludeSemantics: true,
            child: Column(
              children: [
                TroskyDetailsLabel(l10n.payReferenceLabel, bold: false),
                const SizedBox(height: TroskySpacing.s4),
                Text(
                  reference,
                  textAlign: TextAlign.center,
                  style: TroskyTypography.heading20ExtraBold.copyWith(
                    color: TroskyColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "I didn't get a prompt" (derived from the leave-payment sheet): what to
/// check, and asking again. True for "Check again".
Future<bool?> showNoPromptSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s24,
          TroskySpacing.s28,
          TroskySpacing.s24,
          TroskySpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.payNoPromptTitle,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.payNoPromptBody,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: l10n.payCheckAgain,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.payKeepWaiting,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}
