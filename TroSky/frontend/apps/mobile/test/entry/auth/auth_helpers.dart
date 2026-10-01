import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';

import '../../helpers/fakes.dart';

/// A link line such as "New to TroSky? Create account" (one rich text).
Finder link(String text) => find.textContaining(text, findRichText: true);

/// Taps [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The app started with onboarding seen and nobody signed in: Sign in.
Future<TestWorld> openSignIn(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
  List<Object> overrides = const [],
}) async {
  setScreenSize(tester, size);
  final w = world ?? TestWorld();
  await tester.pumpWidget(testApp(world: w, overrides: overrides));
  await tester.pump(splashMinimumDuration);
  await tester.pumpAndSettle();
  return w;
}

/// Sign in → "Create account": Welcome.
Future<TestWorld> openWelcome(
  WidgetTester tester, {
  TestWorld? world,
  Size size = const Size(360, 806),
}) async {
  final w = await openSignIn(tester, world: world, size: size);
  await tapVisible(tester, link('Create account'));
  return w;
}

/// The text field inside the field labelled [label] (the hint or label of
/// a [TroskyInputField]).
Finder field(String hint) =>
    find.ancestor(of: find.text(hint), matching: find.byType(TextField));

Future<void> enter(WidgetTester tester, String hint, String text) async {
  await tester.enterText(field(hint), text);
  await tester.pump();
}

/// Welcome with [phone] → Continue: Your details.
Future<TestWorld> openDetails(
  WidgetTester tester, {
  TestWorld? world,
  String phone = '055 123 4567',
  Size size = const Size(360, 806),
}) async {
  final w = await openWelcome(tester, world: world, size: size);
  await enter(tester, 'XX XXX XXXX', phone);
  await tapVisible(tester, find.text('Continue'));
  return w;
}

/// Fills Your details and taps Create account.
Future<void> submitDetails(
  WidgetTester tester, {
  String name = 'Efua Owusu',
  String email = 'efua.owusu@gmail.com',
  String password = 'Kumasi2026',
}) async {
  await enter(tester, 'e.g. Ama Mensah', name);
  await enter(tester, 'you@gmail.com', email);
  await enter(tester, 'At least 8 characters', password);
  await tapVisible(tester, find.text('Create account'));
}
