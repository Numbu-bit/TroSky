import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../app/offline_banner.dart';
import '../../../app/routes.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/application/home_providers.dart';
import '../application/search_providers.dart';
import '../../seats/domain/seat_selection_args.dart';
import '../domain/journey.dart';
import 'search_screen.dart';
import 'trip_view.dart';
import 'widgets/search_header.dart';

/// What Search Results asks of Search when it closes.
enum ResultsOutcome {
  /// No pickup could be found from the phone's position: choose a stop.
  choosePickup,
}

/// Search Results (P-03, Figma P6): the vehicles for a journey, a page at
/// a time, with the filter pills of decision 22.
///
/// Mock and live mode both show the full design from the backend's data:
/// the fare for the passenger's stretch with the saving (G20), and the
/// vehicles already on the road, approaching or past the stop (G21).
/// Trips that haven't set off show where to board instead.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, required this.search});

  final JourneySearch search;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late JourneySearch _search = widget.search;
  SearchSort _sort = SearchSort.departure;
  bool _minibusOnly = false;
  bool _showPassed = false;
  bool _saving = false;
  final _scroll = ScrollController();

  /// Load the next page this close to the end of the list.
  static const double _loadMoreExtent = 400;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  TripResultsControllerProvider get _results => tripResultsControllerProvider(
    ResultsRequest(_search, sort: _sort, minibusOnly: _minibusOnly),
  );

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _loadMoreExtent) {
      unawaited(ref.read(_results.notifier).loadMore());
    }
  }

  void _setWhen(SearchWhen when) => setState(() {
    _search = _search.copyWith(when: when);
    _showPassed = false;
  });

  Future<void> _schedule() async {
    final at = await pickDepartureTime(
      context,
      _search.when.at,
      now: ref.read(clockProvider)(),
    );
    if (at != null && mounted) _setWhen(SearchWhen.at(at));
  }

  /// Where this search boards, for saving it as a favourite: the chosen
  /// stop, or the stop the backend picked from the phone's position.
  SearchStop? _boardingStop(List<TripSearchResultResponse> trips) =>
      switch (_search.origin) {
        StopOrigin(:final stop) => stop,
        CurrentLocationOrigin() => switch (trips
            .where((t) => t.pickupStopId != null)
            .firstOrNull) {
          final trip? => SearchStop(
            id: trip.pickupStopId!,
            name: trip.pickupStopName ?? '',
          ),
          null => null,
        },
      };

  Future<void> _saveRoute(SearchStop origin, bool saved) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    if (saved) return say(l10n.resultsRouteExists);
    setState(() => _saving = true);
    final result = await ref
        .read(userRepositoryProvider)
        .addFavouriteRoute(
          FavouriteRouteCreateRequest(
            originStopId: origin.id,
            destinationStopId: _search.destination.id,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        ref.invalidate(favouriteRoutesProvider);
        say(l10n.resultsRouteSaved);
      case Err(:final failure) when failure.code == 'FAVOURITE_ROUTE_EXISTS':
        ref.invalidate(favouriteRoutesProvider);
        say(l10n.resultsRouteExists);
      case Err(:final failure) when failure.code == 'FAVOURITE_ROUTES_LIMIT':
        say(l10n.resultsRouteLimit);
      case Err(:final failure):
        say(failureMessage(context, failure));
    }
  }

  void _open(TripSearchResultResponse trip) {
    final boarding = switch (_search.origin) {
      StopOrigin(:final stop) => (stop.id, stop.name),
      CurrentLocationOrigin() => (trip.pickupStopId, trip.pickupStopName),
    };
    // A "Current location" search books from the same position.
    final position = _search.origin is CurrentLocationOrigin
        ? ref.read(locationControllerProvider).position
        : null;
    context.pushNamed(
      AppRoute.seatSelection.name,
      extra: SeatSelectionArgs(
        trip: trip,
        boardingStopId: boarding.$1,
        boardingStopName:
            boarding.$2 ??
            AppLocalizations.of(context).searchCurrentLocationShort,
        alightingStop: _search.destination,
        pickupLatitude: position?.latitude,
        pickupLongitude: position?.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(_results);
    final trips = results.value?.trips ?? const <TripSearchResultResponse>[];
    final view = ResultsView.arrange(trips);
    final offline = ref.watch(
      sessionControllerProvider.select(
        (s) => switch (s.value) {
          SessionAuthenticated(:final offline) => offline,
          _ => false,
        },
      ),
    );
    final originName = switch (_search.origin) {
      CurrentLocationOrigin() => l10n.searchCurrentLocation,
      StopOrigin(:final stop) => stop.name,
    };

    // After a page arrives the list may not fill the screen: ask for more.
    if (results.value case final loaded? when loaded.hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchHeader(
              label: l10n.resultsRouteLabel,
              title: l10n.resultsJourney(switch (_search.origin) {
                CurrentLocationOrigin() =>
                  _boardingStop(trips)?.name ?? originName,
                StopOrigin(:final stop) => stop.name,
              }, _search.destination.name),
              backLabel: l10n.backLabel,
              onBack: () => context.pop(),
              trailing: _saveButton(l10n, trips),
              child: JourneyPanel(
                children: [
                  JourneyCell(
                    dotColor: TroskyColors.green,
                    active: true,
                    child: Text(
                      originName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: journeyText(active: true),
                    ),
                  ),
                  JourneyCell(
                    dotColor: TroskyColors.amber,
                    active: false,
                    child: Text(
                      _search.destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: journeyText(active: false),
                    ),
                  ),
                ],
              ),
            ),
            if (offline) const OfflineBanner(),
            if (view.approachKnown)
              TroskyInfoBanner(
                text: l10n.resultsApproaching,
                action: _showPassed
                    ? l10n.resultsHidePassed
                    : l10n.resultsShowAll,
                actionColor: _showPassed
                    ? TroskyColors.red
                    : TroskyColors.textSecondary,
                onAction: () => setState(() => _showPassed = !_showPassed),
              ),
            PillBar(
              children: [
                TroskyFilterPill(
                  label: l10n.filterNow,
                  selected: _search.when.isNow,
                  onPressed: () => _setWhen(const SearchWhen.now()),
                ),
                TroskyFilterPill(
                  label: _search.when.at == null
                      ? l10n.filterSchedule
                      : scheduleLabel(_search.when.at!),
                  selected: !_search.when.isNow,
                  onPressed: _schedule,
                ),
                for (final (sort, label) in [
                  (SearchSort.cheapest, l10n.filterCheapest),
                  (SearchSort.fastest, l10n.filterFastest),
                ])
                  TroskyFilterPill(
                    label: label,
                    selected: _sort == sort,
                    onPressed: () => setState(
                      () => _sort = _sort == sort ? SearchSort.departure : sort,
                    ),
                  ),
                TroskyFilterPill(
                  label: l10n.filterMinibus,
                  selected: _minibusOnly,
                  onPressed: () => setState(() => _minibusOnly = !_minibusOnly),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: TroskyColors.green,
                onRefresh: () => ref
                    .refresh(_results.future)
                    .then((_) {}, onError: (Object _) {}),
                child: _body(l10n, results, view),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _saveButton(
    AppLocalizations l10n,
    List<TripSearchResultResponse> trips,
  ) {
    final origin = _boardingStop(trips);
    if (origin == null) return null;
    final favourites = ref.watch(favouriteRoutesProvider).value ?? const [];
    final saved = favourites.any(
      (f) =>
          f.originStopId == origin.id &&
          f.destinationStopId == _search.destination.id,
    );
    return TroskyHeaderIconButton(
      semanticsLabel: saved
          ? l10n.resultsRouteSavedLabel
          : l10n.resultsSaveRoute,
      selected: saved,
      onPressed: _saving ? null : () => _saveRoute(origin, saved),
      child: TroskyIcons.star(
        color: saved ? TroskyColors.amber : TroskyColors.white,
        filled: saved,
      ),
    );
  }

  Widget _body(
    AppLocalizations l10n,
    AsyncValue<TripResults> results,
    ResultsView view,
  ) {
    const padding = EdgeInsets.fromLTRB(
      TroskySpacing.s14,
      TroskySpacing.s12,
      TroskySpacing.s14,
      TroskySpacing.s20,
    );
    Widget list(List<Widget> children) => ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: TroskySpacing.s10),
          child,
        ],
      ],
    );

    if (results.hasError && !results.hasValue) {
      final error = results.error;
      final needsPickup =
          error is LocationUnavailable ||
          (error is AppFailure && error.code == 'NO_PICKUP_NEARBY');
      return list([
        _Message(
          text: switch (error) {
            LocationUnavailable() => l10n.resultsNoLocation,
            AppFailure(code: 'NO_PICKUP_NEARBY') => l10n.resultsNoPickup,
            final AppFailure failure => failureMessage(context, failure),
            _ => l10n.resultsEmpty,
          },
          action: needsPickup ? l10n.resultsChoosePickup : l10n.offlineRetry,
          onAction: needsPickup
              ? () => context.pop(ResultsOutcome.choosePickup)
              : () => ref.invalidate(_results),
        ),
      ]);
    }
    final loaded = results.value;
    if (loaded == null || (results.isLoading && results.isReloading)) {
      return list([
        Semantics(
          label: l10n.resultsLoading,
          child: const Column(
            children: [
              _SkeletonCard(),
              SizedBox(height: TroskySpacing.s10),
              _SkeletonCard(),
              SizedBox(height: TroskySpacing.s10),
              _SkeletonCard(),
            ],
          ),
        ),
      ]);
    }
    if (loaded.trips.isEmpty && _minibusOnly) {
      return list([
        _Message(
          text: l10n.resultsNoMinibus,
          action: l10n.resultsShowAllVehicles,
          onAction: () => setState(() => _minibusOnly = false),
        ),
      ]);
    }
    if (loaded.trips.isEmpty) {
      return list([
        _Message(
          text: l10n.resultsEmpty,
          action: l10n.resultsTryAnotherTime,
          onAction: _schedule,
        ),
      ]);
    }
    Widget card(TripSearchResultResponse trip) => tripCard(
      l10n,
      trip,
      bestMatch: identical(trip, view.bestMatch),
      onPressed: () => _open(trip),
    );
    // The backend sends vehicles that passed the stop last, so their block
    // closes the list.
    return list([
      for (final trip in view.upcoming) card(trip),
      if (_showPassed)
        for (final trip in view.passed) tripCard(l10n, trip, bestMatch: false)
      else if (view.passed.isNotEmpty)
        TroskyDashedButton(
          label: l10n.resultsShowPassed(view.passed.length),
          onPressed: () => setState(() => _showPassed = true),
        ),
      if (loaded.loadingMore)
        const Padding(
          padding: EdgeInsets.all(TroskySpacing.s12),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: TroskyColors.green,
              ),
            ),
          ),
        )
      else if (loaded.loadMoreError != null)
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.resultsLoadMoreError,
                style: TroskyTypography.body12Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
            ),
            TroskyTextLink(
              prompt: '',
              action: l10n.offlineRetry,
              onPressed: () => ref.read(_results.notifier).loadMore(),
            ),
          ],
        ),
    ]);
  }
}

/// A message in place of the results, with one action.
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s10,
        vertical: TroskySpacing.s32,
      ),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TroskyTypography.heading15Bold.copyWith(
                color: TroskyColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: TroskySpacing.s16),
          TroskyButton(
            label: action,
            variant: TroskyButtonVariant.outline,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// A grey stand-in for a trip card while results load.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s16,
        TroskySpacing.s14,
        TroskySpacing.s16,
        TroskySpacing.s16,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.cardSubtle,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TroskySkeleton(width: 120, height: 16),
              Spacer(),
              TroskySkeleton(width: 56, height: 18, radius: TroskyRadii.r20),
            ],
          ),
          SizedBox(height: TroskySpacing.s8),
          TroskySkeleton(width: 170, height: 12),
          SizedBox(height: TroskySpacing.s14),
          TroskySkeleton(width: 90, height: 22),
        ],
      ),
    );
  }
}
