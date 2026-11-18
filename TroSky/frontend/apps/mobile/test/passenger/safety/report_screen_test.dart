// Widget tests for P-13 Report.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/safety/application/safety_providers.dart';
import 'package:mobile/passenger/safety/data/safety_outbox.dart';
import 'package:mobile/passenger/safety/domain/safety_args.dart';
import 'package:mobile/passenger/safety/presentation/report_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeSafety implements SafetyRepository {
  final reports = <(String, ReportIncidentRequest)>[];

  @override
  Future<Result<IncidentResponse>> reportIncident(
    String tripId,
    ReportIncidentRequest request, {
    required String idempotencyKey,
  }) async {
    reports.add((tripId, request));
    return Ok(
      IncidentResponse(
        id: 'i1',
        tripId: tripId,
        reportedBy: 'u1',
        incidentType: request.incidentType,
        severity: IncidentSeverity.medium,
        description: request.description,
        status: IncidentStatus.reported,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  @override
  Future<Result<SosAlertResponse>> triggerTripSos(
    String tripId,
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<SosAlertResponse>> triggerSos(
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async => const Err(NetworkFailure());

  @override
  Future<Result<IncidentResponse>> uploadIncidentPhoto(
    String incidentId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async => const Err(NetworkFailure());
}

class _Tel implements TelemetryService {
  final events = <TelemetryEvent>[];
  @override
  void emit(TelemetryEvent event) => events.add(event);
}

/// A SafetyOutbox that no-ops instead of touching Hive/secure storage —
/// keeps the test off the platform channels entirely.
class _NoopOutbox extends SafetyOutbox {
  _NoopOutbox();
  @override
  Future<void> enqueue(SafetyOutboxEntry entry) async {}
  @override
  Future<void> ack(String id) async {}
  @override
  Future<List<SafetyOutboxEntry>> pending() async => [];
  @override
  Future<void> replay(SafetyRepository repository) async {}
}

Widget _host({
  required SafetyRepository safety,
  required TelemetryService tel,
}) => ProviderScope(
  overrides: [
    safetyRepositoryProvider.overrideWithValue(safety),
    telemetryProvider.overrideWithValue(tel),
    safetyOutboxProvider.overrideWithValue(_NoopOutbox()),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: const ReportScreen(args: ReportArgs(tripId: 't1')),
  ),
);

void main() {
  testWidgets('submit is disabled until a category + ≥10-char description', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final safety = _FakeSafety();
    await tester.pumpWidget(_host(safety: safety, tel: _Tel()));
    await tester.pumpAndSettle();
    // No category, no description: submit disabled -> tap is a no-op.
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(safety.reports, isEmpty);
    // Pick a category + type a short description -> still disabled.
    await tester.tap(find.text('Safety concern').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'too short');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(safety.reports, isEmpty);
    // Long enough -> submit fires.
    await tester.enterText(
      find.byType(TextField),
      'There was a serious safety issue on this trip.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(safety.reports.length, 1);
    expect(safety.reports.single.$2.incidentType, IncidentType.safetyConcern);
    expect(
      safety.reports.single.$2.description,
      'There was a serious safety issue on this trip.',
    );
  });
}
