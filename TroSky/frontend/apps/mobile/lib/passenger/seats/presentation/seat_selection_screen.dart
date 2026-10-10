import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../entry/auth/domain/auth_inputs.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/payment_screen.dart';
import '../../search/presentation/trip_view.dart';
import '../application/seat_providers.dart';
import '../domain/seat_map_layout.dart';
import '../domain/seat_selection_args.dart';

/// The backend's limit of seats per booking (`passengers` max_length).
const int maxSeatsPerBooking = 10;

/// Seat Selection (P-05, Figma P7): the trip's real seat map
/// (decision 25), the seats booked so far, and the fare (decision 24). The
/// map is fetched again every [seatRefreshEvery]; a chosen seat someone
/// else takes is unchosen, with a message. Reserving holds the seats as a
/// booking and opens Payment.
class SeatSelectionScreen extends ConsumerStatefulWidget {
  const SeatSelectionScreen({super.key, required this.args});

  final SeatSelectionArgs args;

  @override
  ConsumerState<SeatSelectionScreen> createState() =>
      _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  /// Seat ids, in the order they were chosen.
  final List<String> _selected = [];

  /// Sent with the reservation; a retry of the same choice reuses it, so a
  /// lost answer can't hold the seats twice.
  String? _idempotencyKey;
  bool _reserving = false;

  /// Payment is open for a booking made here: its seats are ours, not
  /// "just taken".
  bool _paying = false;
  String? _error;
  bool _tripClosed = false;
  Timer? _refresh;
  ValueListenable<TickerModeData>? _onScreen;

  TripSearchResultResponse get _trip => widget.args.trip;
  TripSeatsProvider get _seats => tripSeatsProvider(_trip.tripId);

  /// The price of the seats chosen (one when none are), for the passenger's
  /// stops.
  FareQuoteProvider get _quote => fareQuoteProvider(
    FareQuoteRequest(
      _trip.tripId,
      originStopId: widget.args.boardingStopId,
      destinationStopId: widget.args.alightingStop.id,
      seats: math.max(_selected.length, 1),
    ),
  );

  /// The last quote that arrived, shown while the next one loads.
  FareQuoteResponse? _lastQuote;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(seatRefreshEvery, (_) => _refreshSeats());
    ref.listenManual(_seats, (_, next) {
      if (_reserving || _paying) return;
      if (next.value case final map?) _dropTaken(map);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onScreen = TickerMode.getValuesNotifier(context);
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void _refreshSeats() {
    if (!mounted || !(_onScreen?.value.enabled ?? true)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    ref
      ..invalidate(_seats)
      ..invalidate(_quote);
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Chosen seats someone else has taken are unchosen; false when none
  /// were.
  bool _dropTaken(TripSeatsResponse map, {Set<String> also = const {}}) {
    final free = {
      for (final s in map.seats)
        if (s.isAvailable && !also.contains(s.id)) s.id,
    };
    final lost = _selected.where((id) => !free.contains(id)).toList();
    if (lost.isEmpty) return false;
    final numbers = [
      for (final s in map.seats)
        if (lost.contains(s.id)) s.seatNumber,
    ]..sort(compareSeatNumbers);
    setState(() {
      _selected.removeWhere(lost.contains);
      _idempotencyKey = null;
    });
    _say(
      AppLocalizations.of(
        context,
      ).seatsJustTaken(numbers.length, numbers.join(', ')),
    );
    return true;
  }

  void _toggle(TripSeatResponse seat) {
    if (_selected.contains(seat.id)) {
      setState(() => _selected.remove(seat.id));
    } else if (_selected.length >= maxSeatsPerBooking) {
      _say(AppLocalizations.of(context).seatsMax(maxSeatsPerBooking));
      return;
    } else {
      setState(() => _selected.add(seat.id));
    }
    setState(() {
      _idempotencyKey = null;
      _error = null;
    });
  }

  Future<void> _reserve(TripSeatsResponse map) async {
    final l10n = AppLocalizations.of(context);
    final user = switch (ref.read(sessionControllerProvider).value) {
      SessionAuthenticated(:final user) => user,
      _ => null,
    };
    if (user == null || _selected.isEmpty || _reserving) return;
    final seats = [
      for (final s in map.seats)
        if (_selected.contains(s.id)) s,
    ];
    final args = widget.args;
    final request = BookingCreateRequest(
      tripId: _trip.tripId,
      passengers: passengersFor(l10n: l10n, user: user, seats: seats),
      originStopId: args.fromPhonePosition ? null : args.boardingStopId,
      destinationStopId: args.alightingStop.id,
      pickupLatitude: args.pickupLatitude,
      pickupLongitude: args.pickupLongitude,
    );
    final key = _idempotencyKey ??= uuidV4();
    setState(() {
      _reserving = true;
      _error = null;
    });
    final result = await ref
        .read(bookingRepositoryProvider)
        .create(request, idempotencyKey: key);
    if (!mounted) return;
    setState(() => _reserving = false);
    switch (result) {
      case Ok(:final value):
        await _openPayment(value, seats);
      case Err(:final failure) when failure.code == 'SEAT_NOT_AVAILABLE':
        final seatId = failure.details['seat_id'];
        ref.invalidate(_seats);
        // Only the seat the server names is unchosen; the others stay.
        if (!_dropTaken(map, also: {if (seatId is String) seatId})) {
          setState(() => _error = failureMessage(context, failure));
        }
      case Err(:final failure) when failure.code == 'ACCOUNT_NOT_VERIFIED':
        final verified = await context.pushNamed<bool>(
          AppRoute.verifyCode.name,
          extra: CodeRequest(
            purpose: CodePurpose.verifyAccount,
            target: user.phoneNumber,
            alreadySent: false,
          ),
        );
        if (verified == true && mounted) {
          final latest = ref.read(_seats).value ?? map;
          await _reserve(latest);
        }
      // Not open for booking any more, or gone (404: the trip, or a seat
      // that is no longer on its vehicle).
      case Err(:final failure)
          when failure.code == 'TRIP_NOT_BOOKABLE' ||
              failure is NotFoundFailure:
        setState(() {
          _tripClosed = true;
          _error = l10n.seatsTripClosed;
        });
      // Sent once the backend lets trips on the road be booked ahead of
      // the vehicle (origin/backend after 0.12.0).
      case Err(:final failure) when failure.code == 'PICKUP_ALREADY_PASSED':
        setState(() {
          _tripClosed = true;
          _error = l10n.seatsPickupPassed;
        });
      case Err(:final failure) when failure.code == 'STOP_NOT_ON_ROUTE':
        setState(() {
          _tripClosed = true;
          _error = l10n.seatsStopsChanged;
        });
      case Err(:final failure) when failure.code == 'IDEMPOTENCY_KEY_REUSED':
        // The key went with another choice; the next try gets a new one.
        _idempotencyKey = null;
        setState(() => _error = failureMessage(context, failure));
      case Err(:final failure):
        setState(() => _error = failureMessage(context, failure));
    }
  }

  Future<void> _openPayment(
    BookingResponse booking,
    List<TripSeatResponse> seats,
  ) async {
    _paying = true;
    // Home mustn't open it a second time.
    ref.read(shownBookingsProvider.notifier).add(booking.id);
    final outcome = await context.pushNamed<PaymentOutcome>(
      AppRoute.payment.name,
      extra: PaymentArgs(
        booking: booking,
        seatNumbers: [for (final s in seats) s.seatNumber]
          ..sort(compareSeatNumbers),
      ),
    );
    _paying = false;
    if (!mounted) return;
    // A new choice, or the same one again, is a new booking.
    _idempotencyKey = null;
    switch (outcome) {
      case PaymentOutcome.cancelled:
        context.pop();
        return;
      case PaymentOutcome.expired:
        // Payment said to choose again; the seats may have gone meanwhile.
        setState(_selected.clear);
      case PaymentOutcome.released || null:
        // The same seats are free again and stay chosen.
        break;
    }
    ref.invalidate(_seats);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seats = ref.watch(_seats);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(args: widget.args),
            Expanded(
              child: switch (seats) {
                AsyncValue(:final value?) => _content(l10n, value),
                AsyncValue(:final error?) => _LoadError(
                  message: switch (error) {
                    AppFailure(code: 'CONFLICT') ||
                    NotFoundFailure() => l10n.seatsNoVehicle,
                    final AppFailure f => failureMessage(context, f),
                    _ => l10n.seatsLoadError,
                  },
                  onRetry: () => ref.invalidate(_seats),
                ),
                _ => Semantics(
                  label: l10n.seatsLoading,
                  child: const Center(
                    child: CircularProgressIndicator(color: TroskyColors.green),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n, TripSeatsResponse map) {
    final booked = map.totalSeats - map.availableSeats;
    final layout = SeatMapLayout.of(map.seats);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s14,
            TroskySpacing.s14,
            TroskySpacing.s14,
            0,
          ),
          child: TroskyBookedCounter(
            booked: booked,
            total: map.totalSeats,
            suffix: l10n.seatsBookedSuffix(map.totalSeats),
            semanticsLabel: l10n.seatsBookedLabel(booked, map.totalSeats),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TroskySpacing.s14,
              vertical: TroskySpacing.s12,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TroskySpacing.s16,
                vertical: TroskySpacing.s20,
              ),
              decoration: BoxDecoration(
                color: TroskyColors.surface,
                borderRadius: BorderRadius.circular(TroskyRadii.r24),
                boxShadow: TroskyShadows.seatMapCard,
              ),
              child: Column(
                children: [
                  TroskyVehicleCab(
                    plate: _trip.vehicleRegistrationNumber ?? '',
                  ),
                  const SizedBox(height: TroskySpacing.s16),
                  TroskySeatLegend(
                    available: l10n.seatsLegendAvailable,
                    taken: l10n.seatsLegendTaken,
                    selected: l10n.seatsLegendSelected,
                  ),
                  const SizedBox(height: TroskySpacing.s18),
                  // Wide vehicles shrink to fit the card.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _SeatGrid(
                      layout: layout,
                      seat: (seat) => _seat(l10n, seat),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _FarePanel(
          fare: _fare(),
          selected: [
            for (final s in map.seats)
              if (_selected.contains(s.id)) s,
          ],
          reserving: _reserving,
          error: _error,
          tripClosed: _tripClosed,
          onClear: () => setState(() {
            _selected.clear();
            _idempotencyKey = null;
          }),
          onReserve: () => _reserve(map),
          onBackToResults: () => context.pop(),
        ),
      ],
    );
  }

  /// The price on the panel (decision 24 ended): the fare quote; while the
  /// quote for a new number of seats loads, the last one; if it fails, the
  /// search result's fare, so the screen stays usable.
  SeatFare _fare() {
    final state = ref.watch(_quote);
    if (state.value case final quote?) _lastQuote = quote;
    final quote = switch (state) {
      AsyncValue(:final value?) => value,
      AsyncValue(hasError: true) => null,
      _ => _lastQuote,
    };
    return quote == null ? SeatFare.ofTrip(_trip) : SeatFare.ofQuote(quote);
  }

  Widget _seat(AppLocalizations l10n, TripSeatResponse seat) {
    final selected = _selected.contains(seat.id);
    final state = !seat.isAvailable
        ? TroskySeatState.taken
        : selected
        ? TroskySeatState.selected
        : TroskySeatState.available;
    return TroskySeat(
      key: ValueKey(seat.id),
      number: seat.seatNumber,
      state: state,
      semanticsLabel: switch (state) {
        TroskySeatState.taken => l10n.seatLabelTaken(seat.seatNumber),
        TroskySeatState.selected => l10n.seatLabelSelected(seat.seatNumber),
        TroskySeatState.available => l10n.seatLabel(seat.seatNumber),
      },
      onPressed: seat.isAvailable ? () => _toggle(seat) : null,
    );
  }
}

/// The P7 header: navy to dark blue, the round back button, "Choose Your
/// Seat" and `<from> → <to> · <plate> · Departs <time>`.
class _Header extends StatelessWidget {
  const _Header({required this.args});

  final SeatSelectionArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = math.max(48.0, MediaQuery.viewPaddingOf(context).top);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: TroskyGradients.seatSelectionHeader),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s16,
          top + TroskySpacing.s4,
          TroskySpacing.s16,
          TroskySpacing.s16,
        ),
        child: Row(
          children: [
            Transform.translate(
              offset: const Offset(-6, 0),
              child: TroskyHeaderIconButton(
                semanticsLabel: l10n.backLabel,
                onPressed: () => context.pop(),
                child: TroskyIcons.back(color: TroskyColors.white),
              ),
            ),
            const SizedBox(width: TroskySpacing.s6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.seatsTitle,
                      style: TroskyTypography.heading17Bold.copyWith(
                        color: TroskyColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: TroskySpacing.s1),
                  Text(
                    l10n.seatsSubtitle(
                      args.boardingStopName,
                      args.alightingStop.name,
                      args.trip.vehicleRegistrationNumber ?? '',
                      clockTime(args.trip.scheduledDepartureAt),
                    ),
                    style: TroskyTypography.body11Regular.copyWith(
                      color: TroskyColors.whiteA55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seats, row by row (decision 25): 8 px between seats, 10 between
/// rows, the aisle as a 20 px gap or a column, a shorter last row centred.
class _SeatGrid extends StatelessWidget {
  const _SeatGrid({required this.layout, required this.seat});

  final SeatMapLayout layout;
  final Widget Function(TripSeatResponse seat) seat;

  static const double _gap = TroskySpacing.s8;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final (i, row) in layout.rows.indexed) {
      if (i > 0) {
        rows.add(SizedBox(height: TroskySpacing.s10 + (row.bench ? 4 : 0)));
      }
      rows.add(row.bench ? _bench(row) : _row(row));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _bench(SeatMapRow row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: _spaced([
      for (final s in row.cells)
        if (s != null) seat(s),
    ]),
  );

  Widget _row(SeatMapRow row) {
    final cells = <Widget>[];
    for (var c = 1; c <= layout.columns; c++) {
      final s = row.cells[c - 1];
      if (layout.aisleColumn == c) {
        cells.add(
          s != null
              ? seat(s)
              : layout.seatInAisle
              ? SizedBox(
                  width: TroskySeat.size.width,
                  child: const Center(child: TroskySeatAisle()),
                )
              : const TroskySeatAisle(),
        );
      } else {
        cells.add(
          s != null ? seat(s) : SizedBox.fromSize(size: TroskySeat.size),
        );
      }
      if (layout.aisleAfter == c) cells.add(const TroskySeatAisle());
    }
    return Row(mainAxisSize: MainAxisSize.min, children: _spaced(cells));
  }

  static List<Widget> _spaced(List<Widget> items) => [
    for (final (i, item) in items.indexed) ...[
      if (i > 0) const SizedBox(width: _gap),
      item,
    ],
  ];
}

/// One seat's price on the panel: [current] (what it costs now), [solo]
/// (riding alone) and [minimum] (the lowest it can drop to; unknown from
/// an older backend).
@immutable
class SeatFare {
  const SeatFare({required this.current, required this.solo, this.minimum});

  factory SeatFare.ofQuote(FareQuoteResponse quote) => SeatFare(
    current: double.parse(quote.current),
    solo: double.parse(quote.solo),
    minimum: double.parse(quote.minimum),
  );

  /// From the search result: one seat, as it stood then.
  factory SeatFare.ofTrip(TripSearchResultResponse trip) => switch (trip.fare) {
    final fare? => SeatFare(
      current: double.parse(fare.current),
      solo: double.parse(fare.solo),
      minimum: double.parse(fare.minimum),
    ),
    null => SeatFare(
      current: double.parse(trip.fareAmount),
      solo: double.parse(trip.fareAmount),
    ),
  };

  final double current;
  final double solo;
  final double? minimum;
}

/// The bottom panel of P7: the group strip, the price and the button.
class _FarePanel extends StatelessWidget {
  const _FarePanel({
    required this.fare,
    required this.selected,
    required this.reserving,
    required this.error,
    required this.tripClosed,
    required this.onClear,
    required this.onReserve,
    required this.onBackToResults,
  });

  final SeatFare fare;
  final List<TripSeatResponse> selected;
  final bool reserving;
  final String? error;
  final bool tripClosed;
  final VoidCallback onClear;
  final VoidCallback onReserve;
  final VoidCallback onBackToResults;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = selected.length;
    final times = math.max(count, 1);
    final perSeat = fare.current;
    final total = perSeat * times;
    // Riding alone costs more: crossed out. Not when there's no saving.
    final solo = fare.solo > fare.current ? fare.solo * times : null;
    // "Drops to": only when more riders would lower the price.
    final dropsTo = switch (fare.minimum) {
      final minimum? when minimum < fare.current => minimum,
      _ => null,
    };
    final numbers = [for (final s in selected) s.seatNumber]
      ..sort(compareSeatNumbers);
    final totalText = _cedis2(l10n, total);
    final label = switch (count) {
      0 => l10n.seatsSelectToContinue,
      1 => l10n.seatsReserveOne(numbers.single),
      _ => l10n.seatsReserveMany(count, totalText),
    };
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(
        TroskySpacing.s14,
        0,
        TroskySpacing.s14,
        TroskySpacing.s14 + bottom,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s18,
        vertical: TroskySpacing.s14,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
        boxShadow: TroskyShadows.bottomSheet,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[
            _GroupStrip(numbers: numbers, onClear: onClear),
            const SizedBox(height: TroskySpacing.s12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: [
                    if (count > 1)
                      l10n.seatsPriceTimes(_cedis2(l10n, perSeat), count)
                    else
                      l10n.seatsYouPayNow,
                    totalText,
                    if (solo != null) l10n.seatsWas(_cedis2(l10n, solo)),
                    if (dropsTo != null) ...[
                      l10n.seatsDropsTo(_cedis2(l10n, dropsTo)),
                      l10n.seatsAsMoreJoin,
                    ],
                  ].join(', '),
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count > 1
                            ? l10n.seatsPriceTimes(
                                _cedis2(l10n, perSeat),
                                count,
                              )
                            : l10n.seatsYouPayNow,
                        style: TroskyTypography.body11Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s2),
                      Wrap(
                        spacing: TroskySpacing.s8,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          TroskyPriceFlash(
                            value: totalText,
                            style: TroskyTypography.heading30ExtraBoldH100
                                .copyWith(color: TroskyColors.ink),
                          ),
                          if (solo != null)
                            Text(
                              _cedis2(l10n, solo),
                              style: TroskyTypography.body13Regular.copyWith(
                                color: TroskyColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: TroskyColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: TroskySpacing.s8),
              if (dropsTo != null)
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TroskySpacing.s10,
                          vertical: TroskySpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: TroskyColors.amberA15,
                          borderRadius: BorderRadius.circular(TroskyRadii.r20),
                        ),
                        child: Text(
                          l10n.seatsDropsTo(_cedis2(l10n, dropsTo)),
                          style: TroskyTypography.body11Bold.copyWith(
                            color: TroskyColors.goldText,
                          ),
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s3),
                      Text(
                        l10n.seatsAsMoreJoin,
                        style: TroskyTypography.body10Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: TroskySpacing.s10),
          if (error case final error?) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TroskyTypography.body13Regular.copyWith(
                  color: TroskyColors.red,
                ),
              ),
            ),
            if (tripClosed)
              TroskyTextLink(
                prompt: '',
                action: l10n.seatsBackToResults,
                onPressed: onBackToResults,
              ),
            const SizedBox(height: TroskySpacing.s8),
          ],
          TroskyButton(
            label: label,
            variant: TroskyButtonVariant.seatCta,
            loading: reserving,
            onPressed: count == 0 || tripClosed ? null : onReserve,
          ),
        ],
      ),
    );
  }
}

/// "1 seat selected / Seats: 4" with Clear (P7).
class _GroupStrip extends StatelessWidget {
  const _GroupStrip({required this.numbers, required this.onClear});

  final List<String> numbers;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.only(left: TroskySpacing.s12),
      decoration: BoxDecoration(
        color: TroskyColors.greenA06,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Row(
        children: [
          const Text(
            '👥',
            textScaler: TextScaler.noScaling,
            style: TroskyTypography.body14Regular,
          ),
          const SizedBox(width: TroskySpacing.s10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numbers.length == 1
                        ? l10n.seatsOneSelected
                        : l10n.seatsManySelected(numbers.length),
                    style: TroskyTypography.body11Bold.copyWith(
                      color: TroskyColors.greenDark,
                    ),
                  ),
                  Text(
                    l10n.seatsList(numbers.join(', ')),
                    style: TroskyTypography.body10Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.seatsClear,
            onTap: onClear,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TroskySpacing.s12,
                  vertical: TroskySpacing.s12,
                ),
                child: Text(
                  l10n.seatsClear,
                  style: TroskyTypography.body10Bold.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TroskySpacing.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TroskyTypography.heading15Bold.copyWith(
              color: TroskyColors.textPrimary,
            ),
          ),
          const SizedBox(height: TroskySpacing.s16),
          TroskyButton(
            label: AppLocalizations.of(context).offlineRetry,
            variant: TroskyButtonVariant.outline,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// "₵14.00": the seat screen shows pesewas, as the design does.
String _cedis2(AppLocalizations l10n, double amount) =>
    l10n.priceCedis(amount.toStringAsFixed(2));
