import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/booking_format.dart';
import '../application/trips_providers.dart';
import '../domain/booking_view.dart';

/// Trip History (P-15, Figma P13): this month's spending, then the
/// passenger's bookings under two tabs, Upcoming and Past (the design's
/// All / This Month / Last Month became these). A row opens Booking
/// details (P-16). The design's "Export" isn't built.
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  TripsTab _tab = TripsTab.upcoming;
  final _scroll = ScrollController();

  /// Null before the first build.
  bool? _visible;

  /// Load the next page this close to the end of the list.
  static const double _loadMoreExtent = 400;

  /// How far the summary card reaches up into the header (P13: -12 px).
  static const double _overlap = 12;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tabs keep this screen alive offstage, with tickers off. Coming
    // back to it, read the bookings again: one may have been made or paid
    // meanwhile. The rows stay while they reload.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _visible == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
          ..invalidate(tripsControllerProvider)
          ..invalidate(bookingSummaryProvider);
      });
    }
    _visible = visible;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  TripsControllerProvider get _page => tripsControllerProvider(_tab);

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _loadMoreExtent) {
      unawaited(ref.read(_page.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingSummaryProvider);
    await ref.refresh(_page.future).then((_) {}, onError: (Object _) {});
  }

  void _open(BookingResponse booking) => context.pushNamed(
    AppRoute.bookingDetails.name,
    pathParameters: {'bookingId': booking.id},
    extra: booking,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = math.max(
      TroskyAuthHeader.statusBarHeight,
      MediaQuery.viewPaddingOf(context).top,
    );
    // Status bar, the title row (P13: 20/800 beside the Export button's
    // height) and 20 px under it.
    final headerHeight = top + TroskySpacing.s8 + 36 + TroskySpacing.s20;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        // Every child is positioned, so the stack takes the whole screen.
        body: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: Container(
                height: headerHeight,
                decoration: BoxDecoration(
                  gradient: TroskyGradients.historyHeader,
                ),
                padding: EdgeInsets.fromLTRB(
                  TroskySpacing.s20,
                  top + TroskySpacing.s8,
                  TroskySpacing.s20,
                  TroskySpacing.s20,
                ),
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.tripsTitle,
                        style: TroskyTypography.heading20ExtraBold.copyWith(
                          color: TroskyColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: headerHeight - _overlap,
              child: RefreshIndicator(
                color: TroskyColors.green,
                onRefresh: _refresh,
                child: _list(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(AppLocalizations l10n) {
    final summary = ref.watch(bookingSummaryProvider);
    final page = ref.watch(_page);
    final now = ref.watch(clockProvider)();
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s16,
        0,
        TroskySpacing.s16,
        TroskySpacing.s24,
      ),
      children: [
        _summary(l10n, summary),
        // The tabs carry 4 px of extra touch area above and below.
        const SizedBox(height: TroskySpacing.s12),
        TroskySegmentedTabs(
          labels: [l10n.tripsTabUpcoming, l10n.tripsTabPast],
          selected: _tab.index,
          onSelected: (i) => setState(() => _tab = TripsTab.values[i]),
        ),
        const SizedBox(height: TroskySpacing.s12),
        ..._rows(l10n, page, now),
      ],
    );
  }

  Widget _summary(
    AppLocalizations l10n,
    AsyncValue<BookingSummaryResponse> summary,
  ) {
    final value = summary.value;
    if (value == null) {
      // Loading: a grey card. Failed: no card; the rows below say why.
      return summary.hasError
          ? const SizedBox.shrink()
          : const TroskySkeleton(
              width: double.infinity,
              height: 128,
              radius: TroskyRadii.r20,
            );
    }
    return TroskySpendingSummaryCard(
      title: l10n.tripsSpentThisMonth,
      amount: cedis(l10n, value.totalSpent),
      stats: [
        ('${value.tripsCount}', l10n.tripsStatTrips),
        (cedis(l10n, value.averageFare), l10n.tripsStatAvgFare),
        (cedis(l10n, value.totalSaved), l10n.tripsStatSaved),
      ],
    );
  }

  List<Widget> _rows(
    AppLocalizations l10n,
    AsyncValue<TripsPage> page,
    DateTime now,
  ) {
    List<Widget> spaced(List<Widget> rows) => [
      for (final (i, row) in rows.indexed) ...[
        if (i > 0) const SizedBox(height: TroskySpacing.s10),
        row,
      ],
    ];

    final loaded = page.value;
    // A retry shows the skeleton again, not the old error.
    if (page.hasError && loaded == null && !page.isLoading) {
      final error = page.error;
      return [
        _Message(
          text: error is AppFailure
              ? failureMessage(context, error)
              : l10n.errorGeneric,
          action: l10n.offlineRetry,
          onAction: () => ref.invalidate(_page),
        ),
      ];
    }
    if (loaded == null) {
      return [
        Semantics(
          label: l10n.tripsLoading,
          child: Column(
            children: spaced(const [
              TroskyBookingRowSkeleton(),
              TroskyBookingRowSkeleton(),
              TroskyBookingRowSkeleton(),
            ]),
          ),
        ),
      ];
    }
    if (loaded.bookings.isEmpty) {
      return [
        _Message(
          text: _tab == TripsTab.upcoming
              ? l10n.tripsEmptyUpcoming
              : l10n.tripsEmptyPast,
          action: l10n.tripsFindRide,
          onAction: () => context.pushNamed(AppRoute.search.name),
        ),
      ];
    }
    return [
      ...spaced([
        for (final booking in loaded.bookings) _row(l10n, booking, now),
      ]),
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
        Padding(
          padding: const EdgeInsets.only(top: TroskySpacing.s10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tripsLoadMoreError,
                  style: TroskyTypography.body12Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ),
              TroskyTextLink(
                prompt: '',
                action: l10n.offlineRetry,
                onPressed: () => ref.read(_page.notifier).loadMore(),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _row(AppLocalizations l10n, BookingResponse booking, DateTime now) {
    final chip = BookingChip.of(booking);
    final trip = booking.trip;
    final from = booking.boardingStopName ?? trip?.originStopName ?? '';
    final to = booking.alightingStopName ?? trip?.destinationStopName ?? '';
    return TroskyBookingRow(
      route: '$from → $to',
      when: trip == null
          ? ''
          : bookingWhen(l10n, trip.scheduledDepartureAt, now),
      price: cedis(l10n, booking.totalAmount),
      status: chip.label(l10n),
      tone: chip.tag,
      struck: chip.struck,
      onPressed: () => _open(booking),
    );
  }
}

/// A message in place of the rows, with one action.
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
