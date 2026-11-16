// Tap-trigger behaviour tests for the hidden tester menu. These assume
// TESTER_MENU is NOT set in the test environment (default for `flutter
// test`), so TesterMenuTapCounter is a pass-through. We assert that.
//
// Opening-behaviour and counter-reset tests use a simple pure state
// helper (`_TapCounter`) so we don't depend on whether the const is
// true or false in the test binary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/tester/tester_menu.dart';

/// Pure replica of the tap-window logic inside [TesterMenuTapCounter].
/// Opening the sheet is a `bool` result instead of a `showModalBottomSheet`
/// so this stays a plain unit test.
class _TapCounter {
  _TapCounter({required this.now, required this.window, required this.count});

  final DateTime Function() now;
  final Duration window;
  final int count;
  final List<DateTime> _taps = [];
  int opens = 0;

  bool tap() {
    final n = now();
    _taps.removeWhere((t) => n.difference(t) > window);
    _taps.add(n);
    if (_taps.length >= count) {
      _taps.clear();
      opens++;
      return true;
    }
    return false;
  }

  /// Called when the host widget is torn down (sheet opens, Profile
  /// leaves, etc.): forget what we counted so far.
  void reset() => _taps.clear();
}

void main() {
  group('tap counter', () {
    test('7 taps within 3 s opens the sheet', () {
      var t = DateTime.utc(2026, 11, 16, 10);
      final c = _TapCounter(
        now: () => t,
        window: const Duration(seconds: 3),
        count: 7,
      );
      for (var i = 0; i < 6; i++) {
        expect(c.tap(), isFalse, reason: 'tap $i');
        t = t.add(const Duration(milliseconds: 300));
      }
      expect(c.tap(), isTrue, reason: '7th tap opens');
      expect(c.opens, 1);
    });

    test('6 taps alone does not open', () {
      var t = DateTime.utc(2026, 11, 16, 10);
      final c = _TapCounter(
        now: () => t,
        window: const Duration(seconds: 3),
        count: 7,
      );
      for (var i = 0; i < 6; i++) {
        expect(c.tap(), isFalse);
        t = t.add(const Duration(milliseconds: 300));
      }
      expect(c.opens, 0);
    });

    test('a slow sequence (one tap per second) does not open after 7 '
        '— the oldest taps fall off the 3 s window', () {
      var t = DateTime.utc(2026, 11, 16, 10);
      final c = _TapCounter(
        now: () => t,
        window: const Duration(seconds: 3),
        count: 7,
      );
      for (var i = 0; i < 10; i++) {
        expect(c.tap(), isFalse, reason: 'slow tap $i');
        t = t.add(const Duration(seconds: 1));
      }
      expect(c.opens, 0);
    });

    test('counter resets after an open (next 7 taps also fire)', () {
      var t = DateTime.utc(2026, 11, 16, 10);
      final c = _TapCounter(
        now: () => t,
        window: const Duration(seconds: 3),
        count: 7,
      );
      for (var i = 0; i < 7; i++) {
        c.tap();
        t = t.add(const Duration(milliseconds: 300));
      }
      expect(c.opens, 1);
      // Enough gap that nothing carries over.
      t = t.add(const Duration(seconds: 10));
      for (var i = 0; i < 7; i++) {
        c.tap();
        t = t.add(const Duration(milliseconds: 300));
      }
      expect(c.opens, 2);
    });

    test('reset() (host widget torn down) forgets the buffered taps', () {
      var t = DateTime.utc(2026, 11, 16, 10);
      final c = _TapCounter(
        now: () => t,
        window: const Duration(seconds: 3),
        count: 7,
      );
      for (var i = 0; i < 5; i++) {
        c.tap();
        t = t.add(const Duration(milliseconds: 200));
      }
      c.reset();
      // Five more taps should not add up to seven — fresh start.
      for (var i = 0; i < 5; i++) {
        expect(c.tap(), isFalse);
        t = t.add(const Duration(milliseconds: 200));
      }
      expect(c.opens, 0);
    });
  });

  group('TesterMenuTapCounter when TESTER_MENU is unset (release default)', () {
    testWidgets('passes the child through: taps hit the underlying widget', (
      tester,
    ) async {
      // The test binary runs without `--dart-define=TESTER_MENU=true`, so
      // `testerMenuEnabled` is false and the wrapper is a pass-through.
      expect(
        testerMenuEnabled,
        isFalse,
        reason: 'this test file must run without TESTER_MENU set',
      );

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TesterMenuTapCounter(
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(
                    key: Key('inner'),
                    width: 200,
                    height: 40,
                    child: Text('Good morning,'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('inner')));
        await tester.pump();
      }
      expect(taps, 7, reason: 'every tap reaches the inner handler');
    });
  });
}
