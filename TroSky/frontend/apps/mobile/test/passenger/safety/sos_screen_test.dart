// Widget tests for P-12. The outbox is a no-op subclass to keep the test
// off platform channels; the network side is mocked.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/safety/application/safety_providers.dart';
import 'package:mobile/passenger/safety/data/safety_outbox.dart';
import 'package:mobile/passenger/safety/domain/safety_args.dart';
import 'package:mobile/passenger/safety/presentation/sos_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

class _FakeSafety implements SafetyRepository {
  final List<(String?, TriggerSosRequest)> sosCalls = [];

  @override
  Future<Result<SosAlertResponse>> triggerTripSos(
    String tripId,
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async {
    sosCalls.add((tripId, request));
    return Ok(
      SosAlertResponse(
        id: 'a1',
        tripId: tripId,
        triggeredBy: 'u1',
        status: SosAlertStatus.active,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  @override
  Future<Result<SosAlertResponse>> triggerSos(
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) async {
    sosCalls.add((null, request));
    return Ok(
      SosAlertResponse(
        id: 'a1',
        triggeredBy: 'u1',
        status: SosAlertStatus.active,
        createdAt: DateTime.utc(2026, 11, 18),
      ),
    );
  }

  @override
  Future<Result<IncidentResponse>> reportIncident(
    String tripId,
    ReportIncidentRequest request, {
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
  required TelemetryService telemetry,
}) => ProviderScope(
  overrides: [
    safetyRepositoryProvider.overrideWithValue(safety),
    telemetryProvider.overrideWithValue(telemetry),
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
    home: SosScreen(
      args: const SosArgs(),
      coordsProbe: () async => (null, null),
    ),
  ),
);

void main() {
  testWidgets(
    'the SOS screen renders with Emergency title + Call 191 + chips',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(safety: _FakeSafety(), telemetry: _Tel()));
      await tester.pumpAndSettle();
      expect(find.text('Emergency'), findsOneWidget);
      expect(find.text('Call 191'), findsOneWidget);
      expect(find.text('Hold for 3 seconds'), findsOneWidget);
      // The four reason chips.
      expect(find.text('Driver danger'), findsOneWidget);
      expect(find.text('Accident'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    },
  );

  testWidgets('a single tap on SOS does not send', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final safety = _FakeSafety();
    await tester.pumpWidget(_host(safety: safety, telemetry: _Tel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(safety.sosCalls, isEmpty);
  });

  testWidgets('sos_opened fires on first frame', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tel = _Tel();
    await tester.pumpWidget(_host(safety: _FakeSafety(), telemetry: tel));
    await tester.pumpAndSettle();
    expect(tel.events.any((e) => e.name == 'sos_opened'), isTrue);
  });
}
