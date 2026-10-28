import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../../app/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../search/search_prefill.dart';
import '../../application/home_providers.dart';
import 'held_booking_card.dart';

/// The white sheet under the Home map (P5): the handle, a booking with
/// seats held (decision 31), "Favourite Routes"
/// with "See all", the route chips (decision 15), and the subscribe banner
/// when its feature is on (decision 16). Below the handle it scrolls, so
/// small phones and large text lose nothing.
class HomeSheet extends ConsumerWidget {
  const HomeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final promo = ref.watch(
      envProvider.select((env) => env.has(Feature.subscriptions)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TroskyRadii.r20),
        ),
        boxShadow: TroskyShadows.bottomSheet,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: TroskySpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TroskySheetHandle(),
            const SizedBox(height: TroskySpacing.s14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  TroskySpacing.s16,
                  0,
                  TroskySpacing.s16,
                  TroskySpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A booking with seats held comes first (decision 31).
                    const HeldBookingCard(),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.homeFavouriteRoutes,
                              style: TroskyTypography.heading15Bold.copyWith(
                                color: TroskyColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.pushNamed(
                              AppRoute.favouriteRoutes.name,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: TroskySpacing.s12,
                              ),
                              child: Text(
                                l10n.homeSeeAll,
                                style: TroskyTypography.body12SemiBold.copyWith(
                                  color: TroskyColors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TroskySpacing.s10),
                    const _FavouriteRoutes(),
                    if (promo) ...[
                      const SizedBox(height: TroskySpacing.s14),
                      TroskyPromoBanner(
                        eyebrow: l10n.homePromoEyebrow,
                        title: l10n.homePromoTitle,
                        body: l10n.homePromoBody,
                        action: l10n.homePromoAction,
                        onPressed: () =>
                            context.pushNamed(AppRoute.subscribe.name),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chips; grey pills while loading; one line when there are none or
/// they failed (with Retry).
class _FavouriteRoutes extends ConsumerWidget {
  const _FavouriteRoutes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routes = ref.watch(favouriteRoutesProvider);
    final lineStyle = TroskyTypography.body12Regular.copyWith(
      color: TroskyColors.textSecondary,
    );
    return routes.when(
      skipLoadingOnRefresh: false,
      loading: () => Semantics(
        label: l10n.homeFavouritesLoading,
        excludeSemantics: true,
        child: Wrap(
          spacing: TroskySpacing.s8,
          runSpacing: TroskySpacing.s8,
          children: [
            for (final width in const [118.0, 94.0, 124.0, 126.0])
              TroskySkeleton(width: width, height: 36, radius: TroskyRadii.r20),
          ],
        ),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(child: Text(l10n.homeFavouritesError, style: lineStyle)),
          TroskyTextLink(
            prompt: '',
            action: l10n.offlineRetry,
            onPressed: () => ref.invalidate(favouriteRoutesProvider),
          ),
        ],
      ),
      data: (routes) => routes.isEmpty
          ? Text(l10n.homeFavouritesEmpty, style: lineStyle)
          : Wrap(
              spacing: TroskySpacing.s8,
              runSpacing: TroskySpacing.s8,
              children: [
                for (final route in routes)
                  TroskyRouteChip(
                    label: _label(l10n, route),
                    onPressed: () => context.pushNamed(
                      AppRoute.search.name,
                      extra: SearchPrefill.fromFavourite(route),
                    ),
                  ),
              ],
            ),
    );
  }

  /// The passenger's own name for the route, else "Madina → Circle".
  static String _label(AppLocalizations l10n, FavouriteRouteResponse route) {
    final label = route.label?.trim();
    if (label != null && label.isNotEmpty) return label;
    return l10n.homeRoute(route.originStopName, route.destinationStopName);
  }
}
