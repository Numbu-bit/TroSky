import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/booking_format.dart';

/// How a cancel from the sheet went.
@immutable
class CancelOutcome {
  const CancelOutcome(this.booking, {required this.requested});

  /// As the server answered: `cancelled`, `refund_pending`, or unchanged.
  final BookingResponse booking;

  /// The trip had started: the cancel waits for TroSky, and the booking
  /// stays as it was (backend/app/services/booking_service.py).
  final bool requested;
}

/// The cancel sheet (P-16): why, what comes back, then
/// `POST /bookings/{id}/cancel`. Null when the passenger keeps the booking.
Future<CancelOutcome?> showCancelBookingSheet(
  BuildContext context, {
  required BookingResponse booking,
  TripStatus? tripStatus,
}) => showModalBottomSheet<CancelOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: TroskyColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TroskyRadii.r24)),
  ),
  builder: (context) =>
      _CancelBookingSheet(booking: booking, tripStatus: tripStatus),
);

enum _Reason { plans, anotherRide, time, other }

class _CancelBookingSheet extends ConsumerStatefulWidget {
  const _CancelBookingSheet({required this.booking, this.tripStatus});

  final BookingResponse booking;
  final TripStatus? tripStatus;

  @override
  ConsumerState<_CancelBookingSheet> createState() =>
      _CancelBookingSheetState();
}

class _CancelBookingSheetState extends ConsumerState<_CancelBookingSheet> {
  _Reason _reason = _Reason.plans;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _started => switch (widget.tripStatus ??
      widget.booking.trip?.status) {
    TripStatus.boarding || TripStatus.inProgress || TripStatus.paused => true,
    _ => false,
  };

  String _reasonText(AppLocalizations l10n) => switch (_reason) {
    _Reason.plans => l10n.cancelReasonPlans,
    _Reason.anotherRide => l10n.cancelReasonAnotherRide,
    _Reason.time => l10n.cancelReasonTime,
    _Reason.other =>
      _note.text.trim().isEmpty ? l10n.cancelReasonOther : _note.text.trim(),
  };

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final before = widget.booking.status;
    final result = await ref
        .read(bookingRepositoryProvider)
        .cancel(widget.booking.id, reason: _reasonText(l10n));
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(
          CancelOutcome(
            value,
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
    final paid = widget.booking.status == BookingStatus.confirmed;
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
            for (final reason in _Reason.values)
              TroskyRadioOption(
                label: switch (reason) {
                  _Reason.plans => l10n.cancelReasonPlans,
                  _Reason.anotherRide => l10n.cancelReasonAnotherRide,
                  _Reason.time => l10n.cancelReasonTime,
                  _Reason.other => l10n.cancelReasonOther,
                },
                selected: _reason == reason,
                onPressed: () => setState(() => _reason = reason),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: TextField(
                controller: _note,
                maxLength: 200,
                enabled: !_busy,
                // Writing here is choosing "Other".
                onTap: () => setState(() => _reason = _Reason.other),
                onChanged: (_) => setState(() => _reason = _Reason.other),
                style: TroskyTypography.body13Regular.copyWith(
                  color: TroskyColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: l10n.cancelReasonHint,
                  hintStyle: TroskyTypography.body13Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: TroskyColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: TroskySpacing.s14,
                    vertical: TroskySpacing.s12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TroskyRadii.r12),
                    borderSide: const BorderSide(color: TroskyColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TroskyRadii.r12),
                    borderSide: const BorderSide(color: TroskyColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TroskyRadii.r12),
                    borderSide: const BorderSide(color: TroskyColors.green),
                  ),
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s16),
            if (_started)
              TroskyRefundBox(
                title: l10n.cancelReviewTitle,
                body: l10n.cancelReviewBody,
              )
            else if (paid)
              TroskyRefundBox(
                title: l10n.cancelRefundTitle(
                  cedis(l10n, widget.booking.totalAmount),
                ),
                body: l10n.cancelRefundBody,
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
              label: l10n.cancelConfirm,
              variant: TroskyButtonVariant.danger,
              loading: _busy,
              onPressed: _busy ? null : _confirm,
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
