import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../entry/auth/presentation/failure_messages.dart';
import '../../l10n/app_localizations.dart';
import '../booking/presentation/booking_format.dart';
import '../trips/application/trips_providers.dart';

/// How a cancel from the sheet went.
@immutable
class CancelOutcome {
  const CancelOutcome(
    this.booking, {
    required this.reason,
    required this.requested,
  });

  /// As the server answered: `cancelled`, `refund_pending`, or unchanged.
  final BookingResponse booking;

  /// What the passenger picked in the sheet.
  final CancelReason reason;

  /// The trip had started: the cancel waits for TroSky, and the booking
  /// stays as it was (backend/app/services/booking_service.py).
  final bool requested;
}

/// The one-and-only cancel sheet (P-16). Every passenger-initiated cancel
/// — from Payment's "Release seats", from the back-gesture leave sheet,
/// and from Booking Details — goes through this sheet.
///
/// `confirmLabel` lets callers reuse the words the site already shows
/// (e.g. "Release seats" on the Payment screen) while the reason, refund
/// box and backend call stay the same.
///
/// Null when the passenger keeps the booking.
Future<CancelOutcome?> showCancelBookingSheet(
  BuildContext context, {
  required BookingResponse booking,
  TripStatus? tripStatus,
  String? confirmLabel,
}) => showModalBottomSheet<CancelOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: TroskyColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TroskyRadii.r24)),
  ),
  builder: (context) => CancelBookingSheet(
    key: const Key('cancel-booking-sheet'),
    booking: booking,
    tripStatus: tripStatus,
    confirmLabel: confirmLabel,
  ),
);

/// Public so tests can assert constructor identity across all three
/// entry points.
class CancelBookingSheet extends ConsumerStatefulWidget {
  const CancelBookingSheet({
    super.key,
    required this.booking,
    this.tripStatus,
    this.confirmLabel,
  });

  final BookingResponse booking;
  final TripStatus? tripStatus;
  final String? confirmLabel;

  @override
  ConsumerState<CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends ConsumerState<CancelBookingSheet> {
  CancelReason? _reason;
  bool _busy = false;
  String? _error;

  bool get _started => switch (widget.tripStatus ??
      widget.booking.trip?.status) {
    TripStatus.boarding || TripStatus.inProgress || TripStatus.paused => true,
    _ => false,
  };

  /// A "paid" booking is one the backend would refund on cancel.
  bool get _paid => widget.booking.status == BookingStatus.confirmed;

  Future<void> _confirm() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final before = widget.booking.status;
    final result = await ref
        .read(bookingRepositoryProvider)
        .cancel(widget.booking.id, reason: reason);
    // TODO(G37): also forward a free-text note for CancelReason.other once
    // the backend accepts `reason_note` (today the request model is
    // extra="forbid"). The sheet drops the free-text input for now to
    // avoid showing a field whose contents don't go anywhere.
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(
          CancelOutcome(
            value,
            reason: reason,
            requested:
                value.status == before &&
                value.status != BookingStatus.cancelled,
          ),
        );
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failureMessage(context, failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Where the refund goes, as the backend does it
    // (backend/app/services/refund_service.py `approve`): the wallet is
    // credited; MTN MoMo has no refund API, so the team pays it out.
    final channel = _paid
        ? ref.watch(bookingPaymentProvider(widget.booking.id)).value?.channel
        : null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
                l10n.cancelSheetTitle,
                style: TroskyTypography.heading22ExtraBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s6),
            Text(
              l10n.cancelSheetSubtitle,
              style: TroskyTypography.body13Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            for (final reason in CancelReason.values)
              TroskyRadioOption(
                label: cancelReasonLabel(l10n, reason),
                selected: _reason == reason,
                onPressed: () => setState(() => _reason = reason),
              ),
            const SizedBox(height: TroskySpacing.s16),
            if (_started)
              TroskyRefundBox(
                title: l10n.cancelReviewTitle,
                body: l10n.cancelReviewBody,
              )
            else if (_paid)
              TroskyRefundBox(
                title: l10n.cancelRefundTitle(
                  cedis(l10n, widget.booking.totalAmount),
                ),
                body: switch (channel) {
                  PaymentChannel.wallet => l10n.cancelRefundBodyWallet,
                  PaymentChannel.mtnMomo => l10n.cancelRefundBodyMomo,
                  _ => l10n.cancelRefundBody,
                },
              ),
            if (_error case final error?) ...[
              const SizedBox(height: TroskySpacing.s12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TroskyTypography.body13Medium.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ),
            ],
            const SizedBox(height: TroskySpacing.s16),
            TroskyButton(
              label: widget.confirmLabel ?? l10n.cancelConfirm,
              variant: TroskyButtonVariant.danger,
              loading: _busy,
              onPressed: (_busy || _reason == null) ? null : _confirm,
            ),
            const SizedBox(height: TroskySpacing.s10),
            TroskyButton(
              label: l10n.cancelKeep,
              variant: TroskyButtonVariant.outlinePill,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The P-16 label for a reason: a single `l10n` lookup so Booking
/// Details, the sheet and any analytics stay in sync.
String cancelReasonLabel(AppLocalizations l10n, CancelReason reason) =>
    switch (reason) {
      CancelReason.changeOfPlans => l10n.cancelReasonPlans,
      CancelReason.foundAnotherRide => l10n.cancelReasonAnotherRide,
      CancelReason.departureTime => l10n.cancelReasonTime,
      CancelReason.other => l10n.cancelReasonOther,
    };
