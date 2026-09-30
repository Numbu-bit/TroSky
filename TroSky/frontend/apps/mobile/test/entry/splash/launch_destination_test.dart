import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/session_store_provider.dart';
import 'package:mobile/entry/splash/data/onboarding_store.dart';
import 'package:mobile/entry/splash/domain/launch_destination.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';

import '../../helpers/fakes.dart';

class _FailingOnboardingStore implements OnboardingStore {
  @override
  Future<bool> isSeen() => Future.error(StateError('storage unavailable'));

  @override
  Future<void> markSeen() async {}
}

void main() {
  group('LaunchDestination.choose', () {
    test('onboarding first, then a session skips sign-in', () {
      LaunchDestination choose(bool seen, bool session) =>
          LaunchDestination.choose(onboardingSeen: seen, hasSession: session);

      expect(choose(false, false), LaunchDestination.onboarding);
      expect(choose(false, true), LaunchDestination.onboarding);
      expect(choose(true, false), LaunchDestination.signIn);
      expect(choose(true, true), LaunchDestination.home);
    });
  });

  group('launchDestinationProvider', () {
    ProviderContainer container(
      OnboardingStore onboarding, {
      Future<void>? firstFrameShown,
    }) {
      final container = ProviderContainer(
        overrides: [
          onboardingStoreProvider.overrideWithValue(onboarding),
          sessionStoreProvider.overrideWithValue(
            const FakeSessionStore(hasSession: true),
          ),
          firstFrameShownProvider.overrideWith(
            (ref) => firstFrameShown ?? Future.value(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('answers only after the 1.5 s minimum', () {
      fakeAsync((async) {
        final c = container(FakeOnboardingStore(seen: true));
        final sub = c.listen(launchDestinationProvider, (_, _) {});
        addTearDown(sub.close);

        async.elapse(const Duration(milliseconds: 1499));
        expect(c.read(launchDestinationProvider).hasValue, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(c.read(launchDestinationProvider).value, LaunchDestination.home);
      });
    });

    test('the 1.5 s starts when the first frame is on screen', () {
      fakeAsync((async) {
        final shown = Completer<void>();
        final c = container(
          FakeOnboardingStore(seen: true),
          firstFrameShown: shown.future,
        );
        final sub = c.listen(launchDestinationProvider, (_, _) {});
        addTearDown(sub.close);

        // A slow first frame: the checks are done, but nothing is visible.
        async.elapse(const Duration(seconds: 3));
        expect(c.read(launchDestinationProvider).hasValue, isFalse);

        shown.complete();
        async.elapse(const Duration(milliseconds: 1499));
        expect(c.read(launchDestinationProvider).hasValue, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(c.read(launchDestinationProvider).value, LaunchDestination.home);
      });
    });

    test('a failed onboarding read shows onboarding', () {
      fakeAsync((async) {
        final c = container(_FailingOnboardingStore());
        final sub = c.listen(launchDestinationProvider, (_, _) {});
        addTearDown(sub.close);

        async.elapse(splashMinimumDuration);
        expect(
          c.read(launchDestinationProvider).value,
          LaunchDestination.onboarding,
        );
      });
    });
  });
}
