import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/home_providers.dart';
import '../greeting.dart';

/// The navy header of Home (P5): the greeting and the passenger's name, the
/// location chip and the bell, then the search bar.
///
/// It starts 48 px from the top, where the design's status bar ends, or
/// below a taller real one (decision 5).
class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({super.key});

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader> {
  // Back from the background, the greeting may be out of date.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final session = ref.watch(sessionControllerProvider).value;
    final fullName = switch (session) {
      SessionAuthenticated(:final user) => user.profile?.fullName.trim(),
      _ => null,
    };
    final top = math.max(48.0, MediaQuery.viewPaddingOf(context).top);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: TroskyGradients.navyHeader),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s20,
          top,
          TroskySpacing.s20,
          TroskySpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greetingFor(l10n, now),
                        style: TroskyTypography.body12Regular.copyWith(
                          color: TroskyColors.whiteA55,
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s2),
                      Semantics(
                        header: true,
                        child: Text(
                          fullName == null || fullName.isEmpty
                              ? l10n.homeNameFallback
                              : l10n.homeName(fullName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TroskyTypography.heading20Bold.copyWith(
                            color: TroskyColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TroskySpacing.s8),
                const Flexible(flex: 2, child: _LocationChip()),
                const SizedBox(width: TroskySpacing.s8),
                _Bell(
                  label: l10n.homeNotifications,
                  onPressed: () =>
                      context.pushNamed(AppRoute.notifications.name),
                ),
              ],
            ),
            const SizedBox(height: TroskySpacing.s14),
            TroskySearchBar(
              hint: l10n.homeSearchHint,
              trailing: l10n.homeSearchNow,
              onPressed: () => context.pushNamed(AppRoute.search.name),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Madina, Accra": the nearest stop, or "Accra" when location is off or
/// no stop is near. A grey bar while it is still being worked out.
class _LocationChip extends ConsumerWidget {
  const _LocationChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final location = ref.watch(locationControllerProvider);
    final stop = ref.watch(nearestStopProvider);
    final loading =
        !location.settled ||
        (location.position != null && stop.isLoading && !stop.hasValue);
    final place = switch (stop.value) {
      final NearbyStopResponse stop => placeName(stop),
      null => l10n.homeLocationFallback,
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        label: loading
            ? l10n.homeLocationLoading
            : l10n.homeLocationLabel(place),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TroskySpacing.s10,
            vertical: TroskySpacing.s6,
          ),
          decoration: BoxDecoration(
            color: TroskyColors.whiteA10,
            borderRadius: BorderRadius.circular(TroskyRadii.r20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: TroskyColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: TroskySpacing.s6),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: TroskySpacing.s3),
                  child: TroskySkeleton(
                    width: 56,
                    height: 10,
                    radius: TroskyRadii.r4,
                    color: TroskyColors.whiteA30,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TroskyTypography.body11Medium.copyWith(
                      color: TroskyColors.whiteA90,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stop's name, with its city when the name doesn't already say it:
/// "Madina, Accra", as the design shows.
String placeName(NearbyStopResponse stop) {
  final city = stop.city?.trim();
  if (city == null ||
      city.isEmpty ||
      stop.name.toLowerCase().contains(city.toLowerCase())) {
    return stop.name;
  }
  return '${stop.name}, $city';
}

/// The bell: a 36 px disc at 12 % white with 🔔, inside a 48 px touch area.
class _Bell extends StatelessWidget {
  const _Bell({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        // The touch area reaches 6 px past the disc, into the header's
        // padding, so the disc stays where the design puts it.
        child: Transform.translate(
          offset: const Offset(6, 0),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: TroskyColors.whiteA12,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '🔔',
                  textScaler: TextScaler.noScaling,
                  style: TroskyTypography.body16Regular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
