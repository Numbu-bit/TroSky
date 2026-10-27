import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/offline_banner.dart';
import 'package:mobile/app/server_wake_bar.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';

import '../helpers/fakes.dart';

const _waking = 'Waking up the server, this can take up to a minute…';

/// A screen with a count, to show it keeps its state under the bar.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('Count $_count'),
      ),
    ),
  );
}

Widget _app({required List<Object> overrides, required Widget home}) =>
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ServerWakeBar(child: child!),
        home: home,
      ),
    );

void main() {
  testWidgets('while the server wakes the bar is on top, and the screen '
      'below keeps its state', (tester) async {
    final answer = Completer<bool>();
    final wake = ServerWake(
      ping: (_) => answer.future,
      hasInternet: () async => true,
    );
    addTearDown(wake.dispose);
    tester.view
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        overrides: [serverWakeProvider.overrideWithValue(wake)],
        home: const _Counter(),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pump();

    unawaited(wake.ready());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_waking), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_waking), findsOneWidget);
    // The bar takes the status bar's place; the screen starts below it.
    expect(tester.getTopLeft(find.text(_waking)).dy, greaterThan(24));
    final below = tester.getBottomLeft(find.byType(Material).first).dy;
    expect(tester.getTopLeft(find.byType(_Counter)).dy, below);
    expect(find.text('Count 1'), findsOneWidget);
    await tester.tap(find.text('Count 1'));
    await tester.pump();

    answer.complete(true);
    await tester.pump();
    expect(find.text(_waking), findsNothing);
    expect(find.text('Count 2'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(_Counter)).dy, 0);
  });

  testWidgets('a server that answers within 2 s shows no bar', (tester) async {
    final wake = ServerWake(
      ping: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        return true;
      },
      hasInternet: () async => true,
    );
    addTearDown(wake.dispose);
    await tester.pumpWidget(
      _app(
        overrides: [serverWakeProvider.overrideWithValue(wake)],
        home: const _Counter(),
      ),
    );

    unawaited(wake.ready());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_waking), findsNothing);
    }
    expect(wake.state, ServerState.awake);
  });

  testWidgets('the offline banner says "offline" only when the phone has no '
      'internet', (tester) async {
    // A new scope for each state: a scope keeps its first overrides.
    Future<void> banner(ServerState state) => tester.pumpWidget(
      KeyedSubtree(
        key: ValueKey(state),
        child: _app(
          overrides: [
            serverStatusProvider.overrideWith(() => FixedServerStatus(state)),
          ],
          home: const Scaffold(body: OfflineBanner()),
        ),
      ),
    );

    await banner(ServerState.offline);
    expect(
      find.text("You're offline. Showing your last saved details."),
      findsOneWidget,
    );

    await banner(ServerState.unreachable);
    expect(
      find.text("The server isn't answering. Showing your last saved details."),
      findsOneWidget,
    );
  });
}
