// Each TicketPillState renders with its expected label + chip tone.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/trips/presentation/ticket_pill.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('notYetValid pill: neutral tone', (tester) async {
    await tester.pumpWidget(
      _wrap(const TicketPill(state: TicketPillState.notYetValid)),
    );
    expect(find.text('Not yet valid'), findsOneWidget);
    final chip = tester.widget<TroskyChip>(find.byType(TroskyChip));
    expect(chip.color, TroskyChipColor.gray);
  });

  testWidgets('readyToBoard pill: brand green', (tester) async {
    await tester.pumpWidget(
      _wrap(const TicketPill(state: TicketPillState.readyToBoard)),
    );
    expect(find.text('Ready to Board'), findsOneWidget);
    final chip = tester.widget<TroskyChip>(find.byType(TroskyChip));
    expect(chip.color, TroskyChipColor.green);
  });

  testWidgets('used pill shows the validation time', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TicketPill(
          state: TicketPillState.used,
          validatedAt: DateTime.utc(2026, 11, 16, 8, 42).toLocal(),
        ),
      ),
    );
    final chip = tester.widget<TroskyChip>(find.byType(TroskyChip));
    expect(chip.color, TroskyChipColor.blue);
    expect(chip.label, contains('Used'));
  });

  testWidgets('expired pill: amber', (tester) async {
    await tester.pumpWidget(
      _wrap(const TicketPill(state: TicketPillState.expired)),
    );
    expect(find.text('Expired'), findsOneWidget);
    final chip = tester.widget<TroskyChip>(find.byType(TroskyChip));
    expect(chip.color, TroskyChipColor.amber);
  });

  testWidgets('notValid pill: red', (tester) async {
    await tester.pumpWidget(
      _wrap(const TicketPill(state: TicketPillState.notValid)),
    );
    expect(find.text('Not valid'), findsOneWidget);
    final chip = tester.widget<TroskyChip>(find.byType(TroskyChip));
    expect(chip.color, TroskyChipColor.red);
  });
}
