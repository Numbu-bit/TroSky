import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_auth/trosky_auth.dart';

import '../../onboarding/data/onboarding_store.dart';
import '../domain/launch_destination.dart';

part 'launch_destination_provider.g.dart';

/// The splash screen stays on screen at least this long, even when the
/// checks finish sooner.
const Duration splashMinimumDuration = Duration(milliseconds: 1500);

/// Completes when the first frame is on screen, which is when the native
/// launch screen gives way to the splash. On a slow phone that can be over
/// a second after the splash is first built.
@Riverpod(keepAlive: true)
Future<void> firstFrameShown(Ref ref) =>
    WidgetsBinding.instance.waitUntilFirstFrameRasterized;

/// Reads the onboarding flag and restores the saved session while the
/// splash is shown for [splashMinimumDuration], then picks where to go.
@riverpod
Future<LaunchDestination> launchDestination(Ref ref) async {
  final onboarding = ref.watch(onboardingStoreProvider);
  final session = ref.watch(sessionControllerProvider.future);
  final shown = ref.watch(firstFrameShownProvider.future);

  final (onboardingSeen, hasSession, _) = await (
    _falseOnError(onboarding.isSeen),
    _falseOnError(() async => await session is SessionAuthenticated),
    shown.then((_) => Future<void>.delayed(splashMinimumDuration)),
  ).wait;

  return LaunchDestination.choose(
    onboardingSeen: onboardingSeen,
    hasSession: hasSession,
  );
}

/// A failed read must not leave the app stuck on the splash screen, so it
/// counts as "no": onboarding is shown again, or the user signs in again.
Future<bool> _falseOnError(Future<bool> Function() read) async {
  try {
    return await read();
  } on Object {
    return false;
  }
}
