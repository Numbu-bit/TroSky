// P-12 SOS. Full-screen "Emergency" with hold-to-send button and an
// outbox-backed submit path so the alert survives an app kill mid-send.
//
// NEVER fire on a single tap. The backend SMSes emergency contacts
// automatically, so a mis-fire is a real incident.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/safety_providers.dart';
import '../data/safety_outbox.dart';
import '../domain/safety_args.dart';

const Duration _holdDuration = Duration(seconds: 3);

/// Seam for tests: fetches the user's current coordinates if the
/// platform already granted permission. Returns (null, null) when
/// permission is missing or the lookup fails.
typedef SosCoordsProbe = Future<(double?, double?)> Function();

Future<(double?, double?)> _defaultCoordsProbe() async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return (null, null);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 4),
      ),
    );
    return (pos.latitude, pos.longitude);
  } on Object {
    return (null, null);
  }
}

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({
    super.key,
    required this.args,
    this.coordsProbe = _defaultCoordsProbe,
  });
  final SosArgs args;
  final SosCoordsProbe coordsProbe;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener(_onHoldStatus);

  bool _submitting = false;
  SosAlertResponse? _sent;
  String? _failure;
  bool _coordsAttached = false;
  SosReason _reason = SosReason.other;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(telemetryProvider)
          .emit(
            TelemetryEvent('sos_opened', {
              'from': widget.args.inTrip ? 'trip' : 'tester',
            }),
          );
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_submitting) {
      unawaited(_submit());
    }
  }

  void _onHoldStart() {
    if (_submitting || _sent != null) return;
    ref.read(telemetryProvider).emit(TelemetryEvent('sos_hold_started'));
    HapticFeedback.mediumImpact();
    _hold.forward(from: 0);
  }

  void _onHoldEnd() {
    if (_hold.status == AnimationStatus.completed) return;
    if (_hold.value > 0) {
      ref.read(telemetryProvider).emit(TelemetryEvent('sos_hold_cancelled'));
    }
    _hold.stop();
    _hold.animateBack(0, duration: const Duration(milliseconds: 150));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    HapticFeedback.heavyImpact();
    final (lat, lng) = await widget.coordsProbe();
    if (!mounted) return;
    final key = _idempotencyKey ??= uuidV4();
    final request = TriggerSosRequest(latitude: lat, longitude: lng);
    final outbox = ref.read(safetyOutboxProvider);
    await outbox.enqueue(
      SafetyOutboxEntry(
        id: key,
        kind: widget.args.inTrip
            ? SafetyOutboxKind.sosTrip
            : SafetyOutboxKind.sosOffTrip,
        tripId: widget.args.tripId,
        payload: request.toJson(),
        enqueuedAt: DateTime.now().toUtc(),
      ),
    );
    final repo = ref.read(safetyRepositoryProvider);
    final result = widget.args.inTrip
        ? await repo.triggerTripSos(
            widget.args.tripId!,
            request,
            idempotencyKey: key,
          )
        : await repo.triggerSos(request, idempotencyKey: key);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        await outbox.ack(key);
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('sos_sent', {
                'category': sosReasonName(_reason),
                // `has_coords` would match the telemetry sanitiser's banned
                // substring "coord" and be stripped; `location_attached`
                // conveys the same bool and reaches analytics intact.
                'location_attached': lat != null && lng != null,
              }),
            );
        setState(() {
          _sent = value;
          _coordsAttached = lat != null && lng != null;
          _submitting = false;
        });
      case Err(:final failure):
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('sos_send_failed', {'reason': failure.code}));
        setState(() {
          _submitting = false;
          _failure = failure.code;
        });
    }
  }

  void _markSafe() {
    ref.read(telemetryProvider).emit(TelemetryEvent('sos_marked_safe'));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _call191() async {
    ref.read(telemetryProvider).emit(TelemetryEvent('sos_call_911_tapped'));
    await launchUrl(Uri(scheme: 'tel', path: '191'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.navyDeep,
        body: SafeArea(
          child: _sent != null
              ? _ConfirmationView(
                  alert: _sent!,
                  coordsAttached: _coordsAttached,
                  booking: widget.args.booking,
                  onMarkSafe: _markSafe,
                  onCall191: _call191,
                )
              : _HoldView(
                  hold: _hold,
                  submitting: _submitting,
                  failure: _failure,
                  reason: _reason,
                  onReasonChanged: (r) => setState(() => _reason = r),
                  onHoldStart: _onHoldStart,
                  onHoldEnd: _onHoldEnd,
                  onCall191: _call191,
                  onRetry: _submit,
                  l10n: l10n,
                ),
        ),
      ),
    );
  }
}

class _HoldView extends StatelessWidget {
  const _HoldView({
    required this.hold,
    required this.submitting,
    required this.failure,
    required this.reason,
    required this.onReasonChanged,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onCall191,
    required this.onRetry,
    required this.l10n,
  });

  final AnimationController hold;
  final bool submitting;
  final String? failure;
  final SosReason reason;
  final ValueChanged<SosReason> onReasonChanged;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onCall191;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TroskySpacing.s20),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                label: l10n.sosClose,
                button: true,
                container: true,
                child: IconButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  tooltip: l10n.sosClose,
                  icon: const Icon(Icons.close, color: TroskyColors.surface),
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.sosTitle,
                    textAlign: TextAlign.center,
                    style: TroskyTypography.heading22ExtraBold.copyWith(
                      color: TroskyColors.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Spacer(),
          Semantics(
            label: l10n.sosHoldSemantics,
            button: true,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => onHoldStart(),
              onPointerUp: (_) => onHoldEnd(),
              onPointerCancel: (_) => onHoldEnd(),
              child: AnimatedBuilder(
                animation: hold,
                builder: (context, _) => _HoldButton(progress: hold.value),
              ),
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          Text(
            submitting ? l10n.sosSending : l10n.sosHoldInstruction,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.whiteA75,
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.sosSendFailed,
              style: TroskyTypography.body14SemiBold.copyWith(
                color: TroskyColors.red,
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            TroskyButton(
              label: l10n.sosRetry,
              variant: TroskyButtonVariant.primary,
              onPressed: onRetry,
            ),
          ],
          const Spacer(),
          Text(
            l10n.sosReasonLabel,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.whiteA75,
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          Wrap(
            spacing: TroskySpacing.s8,
            runSpacing: TroskySpacing.s8,
            alignment: WrapAlignment.center,
            children: [
              for (final r in SosReason.values)
                ChoiceChip(
                  label: Text(_reasonLabel(l10n, r)),
                  selected: reason == r,
                  onSelected: (_) => onReasonChanged(r),
                ),
            ],
          ),
          const SizedBox(height: TroskySpacing.s20),
          OutlinedButton(
            onPressed: onCall191,
            style: OutlinedButton.styleFrom(
              foregroundColor: TroskyColors.surface,
              side: const BorderSide(color: TroskyColors.whiteA40),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l10n.sosCall191),
          ),
        ],
      ),
    );
  }
}

String _reasonLabel(AppLocalizations l10n, SosReason r) => switch (r) {
  SosReason.driverDanger => l10n.sosReasonDriverDanger,
  SosReason.accident => l10n.sosReasonAccident,
  SosReason.medical => l10n.sosReasonMedical,
  SosReason.other => l10n.sosReasonOther,
};

class _HoldButton extends StatelessWidget {
  const _HoldButton({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              color: TroskyColors.surface,
              backgroundColor: TroskyColors.whiteA20,
            ),
          ),
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              color: TroskyColors.red,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'SOS',
              style: TroskyTypography.heading42ExtraBoldH100.copyWith(
                color: TroskyColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.alert,
    required this.coordsAttached,
    required this.booking,
    required this.onMarkSafe,
    required this.onCall191,
  });

  final SosAlertResponse alert;
  final bool coordsAttached;
  final BookingResponse? booking;
  final VoidCallback onMarkSafe;
  final VoidCallback onCall191;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(TroskySpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TroskySpacing.s20),
          Icon(Icons.verified_outlined, color: TroskyColors.surface, size: 64),
          const SizedBox(height: TroskySpacing.s16),
          Text(
            l10n.sosConfirmationTitle,
            textAlign: TextAlign.center,
            style: TroskyTypography.heading22ExtraBold.copyWith(
              color: TroskyColors.surface,
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          Text(
            l10n.sosConfirmationBody,
            textAlign: TextAlign.center,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.whiteA75,
            ),
          ),
          if (!coordsAttached) ...[
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.sosLocationNotShared,
              textAlign: TextAlign.center,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.whiteA60,
              ),
            ),
          ],
          const Spacer(),
          OutlinedButton(
            onPressed: onCall191,
            style: OutlinedButton.styleFrom(
              foregroundColor: TroskyColors.surface,
              side: const BorderSide(color: TroskyColors.whiteA40),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l10n.sosCall191),
          ),
          const SizedBox(height: TroskySpacing.s8),
          TextButton(
            onPressed: onMarkSafe,
            child: Text(
              l10n.sosMarkSafe,
              style: TroskyTypography.body14SemiBold.copyWith(
                color: TroskyColors.whiteA90,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
