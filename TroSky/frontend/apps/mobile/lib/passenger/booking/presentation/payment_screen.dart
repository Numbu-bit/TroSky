import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../entry/auth/presentation/failure_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/presentation/trip_view.dart';
import '../../search/search_prefill.dart';
import '../../seats/application/seat_providers.dart';
import '../../seats/domain/seat_map_layout.dart';
import '../application/booking_watch.dart';
import '../domain/payment_args.dart';

export '../domain/payment_args.dart';

/// Payment (P-07). A booking first waits for the trip's driver to accept it
/// (backend 0.20.0): the screen counts down the driver's deadline, shows a
/// move to another vehicle, the driver's acceptance (then the time left to
/// pay) or that no driver accepted, as [BookingWatchController] reads them
/// from the server. Paying itself is not built yet.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  late DateTime _now;
  bool _cancelling = false;
  bool _closed = false;
  String? _error;

  BookingWatchControllerProvider get _watch =>
      bookingWatchControllerProvider(widget.args);

  @override
  void initState() {
    super.initState();
    _now = ref.read(clockProvider)().toUtc();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _lifecycle = AppLifecycleListener(
      onPause: () => ref.read(_watch.notifier).pause(),
      onResume: () => ref.read(_watch.notifier).resume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = ref.read(clockProvider)().toUtc());
    final watch = ref.read(_watch);
    if (watch.stage == PaymentStage.accepted && _left(watch) == Duration.zero) {
      _expired();
    }
  }

  Duration _left(BookingWatch watch) {
    final left = watch.booking.expiresAt?.difference(_now);
    return left == null || left.isNegative ? Duration.zero : left;
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _close([PaymentOutcome? outcome]) {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    ref.invalidate(heldBookingProvider);
    context.pop(outcome);
  }

  void _expired() {
    if (_closed) return;
    final l10n = AppLocalizations.of(context);
    _say(widget.args.restored ? l10n.paymentExpiredHome : l10n.paymentExpired);
    _close(PaymentOutcome.expired);
  }

  bool get _holdsSeats => switch (ref.read(_watch).stage) {
    PaymentStage.waiting || PaymentStage.moved || PaymentStage.accepted => true,
    _ => false,
  };

  /// Back from a booking just made on Seat Selection: going back to change
  /// seats would leave these held, so ask to release them first.
  Future<void> _back() async {
    if (widget.args.restored) {
      context.pop();
      return;
    }
    if (!_holdsSeats) {
      _close(PaymentOutcome.expired);
      return;
    }
    final release = await showReleaseSeatsPrompt(context);
    if ((release ?? false) && mounted) await _cancel(released: true);
  }

  Future<void> _cancel({bool released = false}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _cancelling = true;
      _error = null;
    });
    final result = await ref.read(_watch.notifier).cancel();
    if (!mounted) return;
    setState(() => _cancelling = false);
    switch (result) {
      case Ok() when released:
        _say(l10n.paymentReleased);
        _close(PaymentOutcome.released);
      case Ok():
        _say(l10n.paymentCancelled);
        _close(PaymentOutcome.cancelled);
      case Err(:final failure) when failure.code == 'INVALID_STATE_TRANSITION':
        // It ended on the server meanwhile; the booking was read again and
        // the screen shows how.
        break;
      case Err(:final failure):
        setState(() => _error = failureMessage(context, failure));
    }
  }

  /// Search again from the same stops, starting over from Home.
  void _searchAgain() {
    final booking = ref.read(_watch).booking;
    final router = GoRouter.of(context);
    _closed = true;
    ref.invalidate(heldBookingProvider);
    final trip = booking.trip;
    final prefill =
        booking.originStopId != null &&
            booking.destinationStopId != null &&
            trip != null
        ? SearchPrefill(
            originStopId: booking.originStopId!,
            originStopName: booking.boardingStopName ?? trip.originStopName,
            destinationStopId: booking.destinationStopId!,
            destinationStopName:
                booking.alightingStopName ?? trip.destinationStopName,
          )
        : null;
    router.goNamed(AppRoute.home.name);
    // Search goes over Home once Home has replaced this stack.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => router.pushNamed(AppRoute.search.name, extra: prefill),
    );
  }

  void _home() {
    _closed = true;
    ref.invalidate(heldBookingProvider);
    context.goNamed(AppRoute.home.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watch = ref.watch(_watch);
    ref.listen(_watch.select((w) => w.stage), (_, stage) {
      if (stage == PaymentStage.holdExpired) _expired();
    });
    final stage = watch.stage;
    final busy = _cancelling;
    return PopScope(
      canPop: widget.args.restored,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_closed && !busy) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: TroskySystemUi.lightIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          body: Column(
            children: [
              TroskyPageHeader(
                title: l10n.paymentTitle,
                subtitle: l10n.paymentSubtitle,
                backLabel: l10n.backLabel,
                onBack: busy ? null : _back,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    TroskySpacing.s18,
                    TroskySpacing.s16,
                    TroskySpacing.s18,
                    TroskySpacing.s24,
                  ),
                  children: [
                    if (stage == PaymentStage.accepted && watch.acceptedHere)
                      ..._banner(
                        l10n.paymentAccepted,
                        TroskyStatusTone.success,
                      ),
                    if (stage == PaymentStage.moved)
                      ..._banner(
                        watch.moveReason == MoveReason.declined
                            ? l10n.paymentMovedDeclined
                            : l10n.paymentMovedUnanswered,
                        TroskyStatusTone.info,
                      ),
                    _card(l10n, watch),
                    ...switch (stage) {
                      PaymentStage.waiting ||
                      PaymentStage.moved => _waiting(l10n, watch),
                      PaymentStage.accepted => [
                        const SizedBox(height: TroskySpacing.s16),
                        Text(
                          l10n.paymentComingSoon,
                          style: TroskyTypography.body13Regular.copyWith(
                            color: TroskyColors.textSecondary,
                          ),
                        ),
                      ],
                      PaymentStage.notAccepted => _notAccepted(l10n),
                      PaymentStage.holdExpired ||
                      PaymentStage.cancelled => const [],
                    },
                    if (watch.offline &&
                        (stage == PaymentStage.waiting ||
                            stage == PaymentStage.moved)) ...[
                      const SizedBox(height: TroskySpacing.s16),
                      _Offline(l10n.paymentOffline),
                    ],
                    if (_error case final error?) ...[
                      const SizedBox(height: TroskySpacing.s12),
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
                    ],
                  ],
                ),
              ),
              _bottom(l10n, watch),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _banner(String text, TroskyStatusTone tone) => [
    TroskyStatusBanner(text: text, tone: tone),
    const SizedBox(height: TroskySpacing.s18),
  ];

  Widget _card(AppLocalizations l10n, BookingWatch watch) {
    final booking = watch.booking;
    final trip = booking.trip;
    final moved = watch.stage == PaymentStage.moved;
    final departs = trip?.scheduledDepartureAt;
    final before = watch.movedFrom?.trip?.scheduledDepartureAt;
    final numbers = booking.tripId == widget.args.booking.tripId
        ? widget.args.seatNumbers
        : null;
    final seats =
        numbers ??
        _seatNumbersFrom(booking, ref.watch(tripSeatsProvider(booking.tripId)));
    return TroskyTripSummaryCard(
      from: booking.boardingStopName ?? trip?.originStopName ?? '',
      to: booking.alightingStopName ?? trip?.destinationStopName ?? '',
      day: departs == null ? '' : _day(l10n, departs),
      time: departs == null ? '' : clockTime(departs),
      previousTime: moved && before != null && before != departs
          ? clockTime(before)
          : null,
      tag: moved ? l10n.paymentNewVehicle : null,
      highlighted: moved,
      facts: [
        TroskyTripFact(
          l10n.paymentVehicle,
          trip?.vehicleRegistrationNumber ?? '–',
        ),
        TroskyTripFact(
          l10n.paymentSeats,
          seats == null ? '…' : _seatList(l10n, seats),
        ),
        TroskyTripFact(
          l10n.paymentTotal,
          _cedis(l10n, booking.totalAmount),
          valueColor: TroskyColors.greenDark,
        ),
      ],
    );
  }

  List<Widget> _waiting(AppLocalizations l10n, BookingWatch watch) {
    final moved = watch.stage == PaymentStage.moved;
    final left = _left(watch);
    final time = _clock(left);
    final window = watch.answerWindow;
    return [
      const SizedBox(height: TroskySpacing.s32),
      const Center(child: TroskyPulseDot()),
      const SizedBox(height: TroskySpacing.s24),
      _Message(
        title: moved ? l10n.paymentNewDriverTitle : l10n.paymentWaitingTitle,
        body: moved ? l10n.paymentNewDriverBody : l10n.paymentWaitingBody,
      ),
      const SizedBox(height: TroskySpacing.s14),
      TroskyCountdown(
        time: time,
        caption: window == null || window <= Duration.zero
            ? null
            : l10n.paymentAnswerWindow(
                (window.inSeconds / 60).round().clamp(1, 60),
              ),
        semanticsLabel: l10n.paymentAnswerTimeLeft(time),
        announce: left.inSeconds % 30 == 0,
      ),
    ];
  }

  List<Widget> _notAccepted(AppLocalizations l10n) => [
    const SizedBox(height: TroskySpacing.s32),
    Center(
      child: TroskyStatusTile(
        icon: TroskyIcons.bookingNotAccepted(color: TroskyColors.textSecondary),
      ),
    ),
    const SizedBox(height: TroskySpacing.s24),
    _Message(
      title: l10n.paymentNotAcceptedTitle,
      body: l10n.paymentNotAcceptedBody,
      large: true,
    ),
  ];

  Widget _bottom(AppLocalizations l10n, BookingWatch watch) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final padding = EdgeInsets.fromLTRB(
      TroskySpacing.s18,
      TroskySpacing.s12,
      TroskySpacing.s18,
      TroskySpacing.s16 + bottom,
    );
    final cancel = TroskyButton(
      label: watch.stage == PaymentStage.waiting
          ? l10n.paymentCancelRequest
          : l10n.paymentCancel,
      variant: TroskyButtonVariant.outlinePill,
      loading: _cancelling,
      onPressed: _cancel,
    );
    switch (watch.stage) {
      case PaymentStage.waiting || PaymentStage.moved:
        return Padding(padding: padding, child: cancel);
      case PaymentStage.accepted:
        final time = _clock(_left(watch));
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: TroskyColors.surface,
            border: Border(
              top: BorderSide(
                color: TroskyColors.border,
                width: TroskyBorders.w1,
              ),
            ),
          ),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: _left(watch).inSeconds % 60 == 0,
                  label: '${l10n.paymentPayWithin} $time',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TroskyIcons.clock(color: TroskyColors.green, size: 16),
                      const SizedBox(width: TroskySpacing.s8),
                      Text(
                        l10n.paymentPayWithin,
                        style: TroskyTypography.body14SemiBold.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: TroskySpacing.s8),
                      Text(
                        time,
                        style: TroskyTypography.heading18ExtraBold.copyWith(
                          color: TroskyColors.greenDark,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                cancel,
              ],
            ),
          ),
        );
      case PaymentStage.notAccepted:
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TroskyButton(
                label: l10n.paymentSearchAgain,
                variant: TroskyButtonVariant.primary,
                onPressed: _searchAgain,
              ),
              const SizedBox(height: TroskySpacing.s4),
              TroskyTextLink(
                prompt: '',
                action: l10n.paymentBackHome,
                actionColor: TroskyColors.blue,
                actionStyle: TroskyTypography.heading14Bold,
                onPressed: _home,
              ),
            ],
          ),
        );
      case PaymentStage.holdExpired || PaymentStage.cancelled:
        return const SizedBox.shrink();
    }
  }

  List<String>? _seatNumbersFrom(
    BookingResponse booking,
    AsyncValue<TripSeatsResponse> map,
  ) {
    final seats = map.value;
    if (seats == null) return null;
    final numbers = {for (final s in seats.seats) s.id: s.seatNumber};
    return [for (final p in booking.passengers) numbers[p.seatId] ?? '?']
      ..sort(compareSeatNumbers);
  }

  /// "Today", "Tomorrow" or "Mon 27 Oct", on the phone's calendar.
  String _day(AppLocalizations l10n, DateTime departs) {
    final local = departs.toLocal();
    final today = DateUtils.dateOnly(_now.toLocal());
    final day = DateUtils.dateOnly(local);
    final days = day.difference(today).inDays;
    if (days == 0) return l10n.paymentToday;
    if (days == 1) return l10n.paymentTomorrow;
    return DateFormat('EEE d MMM', l10n.localeName).format(local);
  }
}

/// "B3", "B3 & B4", "B3, B4 & B5".
String _seatList(AppLocalizations l10n, List<String> seats) => seats.length < 2
    ? seats.join()
    : l10n.paymentSeatsAnd(
        seats.sublist(0, seats.length - 1).join(', '),
        seats.last,
      );

/// "1:42": minutes and seconds left.
String _clock(Duration left) =>
    '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';

/// "₵16.00": booking amounts keep their pesewas.
String _cedis(AppLocalizations l10n, String amount) =>
    l10n.priceCedis(double.parse(amount).toStringAsFixed(2));

/// A centred status title and the sentence under it. [large] is the
/// not-accepted title.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.large = false});

  final String title;
  final String body;
  final bool large;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s18),
    child: Column(
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            // Two-line titles sit 1.25 apart in the screenshots.
            style:
                (large
                        ? TroskyTypography.heading22ExtraBold
                        : TroskyTypography.heading20ExtraBold)
                    .copyWith(color: TroskyColors.ink, height: 1.25),
          ),
        ),
        const SizedBox(height: TroskySpacing.s8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// No connection while waiting: the offline banner's amber, as a note.
class _Offline extends StatelessWidget {
  const _Offline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s10,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.amberA15,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TroskyTypography.body13Regular.copyWith(
          color: TroskyColors.textPrimary,
        ),
      ),
    ),
  );
}

/// Going back from Payment to change seats: true to release the held seats
/// (cancel the booking), false or null (dismissed) to stay.
Future<bool?> showReleaseSeatsPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s24,
          TroskySpacing.s28,
          TroskySpacing.s24,
          TroskySpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.paymentReleaseTitle,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.paymentReleaseBody,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: l10n.paymentReleaseKeep,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.paymentReleaseConfirm,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}
