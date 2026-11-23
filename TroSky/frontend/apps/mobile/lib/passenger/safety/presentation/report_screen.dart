// P-13 Report an issue. Category + description + (future) photo attach.
// Submissions go through the safety outbox so a bad connection doesn't
// lose the report; photo upload is deferred to a follow-up PR (backend
// endpoint exists at POST /incidents/{id}/photo).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/safety_providers.dart';
import '../data/safety_outbox.dart';
import '../domain/safety_args.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.args});
  final ReportArgs args;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  IncidentType? _category;
  final TextEditingController _description = TextEditingController();
  bool _submitting = false;
  String? _idempotencyKey;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryProvider).emit(TelemetryEvent('report_opened'));
    });
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _category != null && _description.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_valid) return;
    final l10n = AppLocalizations.of(context);
    final key = _idempotencyKey ??= uuidV4();
    final request = ReportIncidentRequest(
      incidentType: _category!,
      description: _description.text.trim(),
    );
    final outbox = ref.read(safetyOutboxProvider);
    await outbox.enqueue(
      SafetyOutboxEntry(
        id: key,
        kind: SafetyOutboxKind.incident,
        tripId: widget.args.tripId,
        payload: request.toJson(),
        enqueuedAt: DateTime.now().toUtc(),
      ),
    );
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await ref
        .read(safetyRepositoryProvider)
        .reportIncident(widget.args.tripId, request, idempotencyKey: key);
    if (!mounted) return;
    switch (result) {
      case Ok():
        await outbox.ack(key);
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('report_submitted', {
                'category': _category!.name,
                'has_photos': false,
              }),
            );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.reportSuccess)));
        Navigator.of(context).maybePop();
      case Err(:final failure):
        ref
            .read(telemetryProvider)
            .emit(
              TelemetryEvent('report_submit_failed', {'reason': failure.code}),
            );
        setState(() {
          _submitting = false;
          _failure = failure.code;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.reportTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            children: [
              if (widget.args.bookingReference != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: TroskySpacing.s12),
                  child: Text(
                    l10n.reportBookingContext(widget.args.bookingReference!),
                    style: TroskyTypography.body12Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                l10n.reportCategoryLabel,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
              const SizedBox(height: TroskySpacing.s8),
              Wrap(
                spacing: TroskySpacing.s8,
                runSpacing: TroskySpacing.s8,
                children: [
                  for (final t in IncidentType.values)
                    ChoiceChip(
                      label: Text(_categoryLabel(l10n, t)),
                      selected: _category == t,
                      onSelected: (_) {
                        setState(() => _category = t);
                        ref
                            .read(telemetryProvider)
                            .emit(
                              TelemetryEvent('report_category_picked', {
                                'category': t.name,
                              }),
                            );
                      },
                    ),
                ],
              ),
              const SizedBox(height: TroskySpacing.s16),
              Text(
                l10n.reportDescriptionLabel,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.ink,
                ),
              ),
              const SizedBox(height: TroskySpacing.s8),
              TextField(
                controller: _description,
                maxLines: 6,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n.reportDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_failure != null) ...[
                const SizedBox(height: TroskySpacing.s8),
                Text(
                  l10n.reportSubmitFailure,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ],
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.reportSubmit,
                variant: TroskyButtonVariant.primary,
                onPressed: (_valid && !_submitting) ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(AppLocalizations l10n, IncidentType t) => switch (t) {
  IncidentType.accident => l10n.reportCategoryAccident,
  IncidentType.breakdown => l10n.reportCategoryBreakdown,
  IncidentType.delay => l10n.reportCategoryDelay,
  IncidentType.safetyConcern => l10n.reportCategorySafety,
  IncidentType.passengerIssue => l10n.reportCategoryPassenger,
  IncidentType.roadHazard => l10n.reportCategoryRoadHazard,
  IncidentType.other => l10n.reportCategoryOther,
};
