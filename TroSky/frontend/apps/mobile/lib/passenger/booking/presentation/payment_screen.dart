import 'dart:async';

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
import '../../search/presentation/trip_view.dart';
import '../../search/search_prefill.dart';
import '../../seats/application/seat_providers.dart';
import '../../trips/application/trips_providers.dart';
import '../application/booking_watch.dart';
import '../application/pay_controller.dart';
import '../domain/pay_method.dart';
import '../domain/payment_args.dart';
import 'booking_format.dart';
import 'pay_method_sheet.dart';
import 'pay_views.dart';

export '../domain/payment_args.dart';

/// Payment (P-07). A booking first waits for the trip's driver to accept it
/// (backend 0.20.0): the screen counts down the driver's deadline, shows a
/// move to another vehicle, the driver's acceptance (then the time left to
/// pay) or that no driver accepted, as [BookingWatchController] reads them
/// from the server. Once accepted the passenger pays ([PayController]):
/// from the wallet at once, or by MTN MoMo, approved on the phone (P-08);
/// then the outcome (P-09).
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

  /// The waiting content is taller than the screen (a small phone, large
  /// text): the countdown goes in the bottom bar, as "Pay within" does once
  /// accepted, so the deadline never scrolls out of sight.
  bool _countdownBelow = false;
  String? _error;

  /// The method the passenger picked; until then the one [PayOptions]
  /// offers first.
  PayMethod? _method;

  BookingWatchControllerProvider get _watch =>
      bookingWatchControllerProvider(widget.args);

  PayControllerProvider get _pay => payControllerProvider(widget.args);

  @override
  void initState() {
    super.initState();
    _now = ref.read(clockProvider)().toUtc();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _lifecycle = AppLifecycleListener(
      onPause: () {
        ref.read(_watch.notifier).pause();
        ref.read(_pay.notifier).pause();
      },
      onResume: () {
        ref.read(_watch.notifier).resume();
        ref.read(_pay.notifier).resume();
      },
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
    if (watch.stage != PaymentStage.accepted || _left(watch) > Duration.zero) {
      return;
    }
    // The hold ran out: unpaid, the seats are gone; while MoMo waits for
    // the payer, the payment is asked once more first.
    final pay = ref.read(_pay);
    switch (pay.stage) {
      case PayStage.idle:
        _expired();
      case PayStage.failed when !pay.holdOver:
        _expired();
      case PayStage.approving:
        ref.read(_pay.notifier).timeUp();
      case PayStage.paying ||
          PayStage.paid ||
          PayStage.failed ||
          PayStage.timedOut:
        break;
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

  /// Back from a booking just made on Seat Selection asks first (decision
  /// 31): keep the seats held and leave for Home, where a card leads back
  /// here, or release them and choose again. Reopened from Home or Trips,
  /// Back just goes back: the seats stay held either way. Once paying
  /// started, Back leaves (a MoMo payment goes on; Home's card leads back
  /// to it), and from a failure it returns to choosing how to pay.
  Future<void> _back() async {
    final pay = ref.read(_pay);
    switch (pay.stage) {
      case PayStage.paying:
        return;
      case PayStage.failed when !pay.holdOver:
        ref.read(_pay.notifier).reset();
        return;
      case PayStage.approving ||
          PayStage.paid ||
          PayStage.failed ||
          PayStage.timedOut:
        _leave();
        return;
      case PayStage.idle:
        break;
    }
    if (widget.args.restored) {
      context.pop();
      return;
    }
    if (!_holdsSeats) {
      _close(PaymentOutcome.expired);
      return;
    }
    final choice = await showLeavePaymentSheet(
      context,
      timeLeft: timeLeft(_left(ref.read(_watch))),
    );
    if (!mounted) return;
    switch (choice) {
      case LeaveChoice.keep:
        _home();
      case LeaveChoice.release:
        await _cancel(released: true);
      case null:
        break;
    }
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

  /// Back where Payment came from: Trips or Home for a reopened booking,
  /// Home for a new one (Seat Selection is behind it).
  void _leave() {
    if (!widget.args.restored) return _home();
    _closed = true;
    ref.invalidate(heldBookingProvider);
    context.pop();
  }

  void _trips() {
    _closed = true;
    context.goNamed(AppRoute.trips.name);
  }

  /// The method shown: the one picked, else the one used last or the best
  /// fit for [amount].
  PayMethod _chosen(PayOptions? options, String amount) =>
      _method ?? options?.initial(amount) ?? const WalletPay();

  /// Pays with the method shown. The controller ignores a second tap.
  void _payNow() {
    final booking = ref.read(_watch).booking;
    final method = _chosen(
      ref.read(payOptionsProvider).value,
      booking.totalAmount,
    );
    ref.read(_pay.notifier).pay(method);
  }

  /// "Change" (or "Change method" after a failure): the method sheet.
  Future<void> _changeMethod() async {
    final booking = ref.read(_watch).booking;
    PayOptions options;
    try {
      options = await ref.read(payOptionsProvider.future);
    } on Object {
      // Neither could be read: the wallet, and a new number.
      options = const PayOptions(wallet: null, numbers: []);
    }
    if (!mounted) return;
    final picked = await showPayMethodSheet(
      context,
      options: options,
      chosen: _chosen(options, booking.totalAmount),
      amount: booking.totalAmount,
    );
    if (!mounted) return;
    ref.read(_pay.notifier).reset();
    if (picked != null) setState(() => _method = picked);
  }

  Future<void> _noPrompt() async {
    final check = await showNoPromptSheet(context);
    if (check == true && mounted) await ref.read(_pay.notifier).checkNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watch = ref.watch(_watch);
    final pay = ref.watch(_pay);
    ref
      ..listen(_watch.select((w) => w.stage), (_, stage) {
        final pay = ref.read(_pay);
        final unpaid =
            pay.stage == PayStage.idle ||
            (pay.stage == PayStage.failed && !pay.holdOver);
        if (stage == PaymentStage.holdExpired && unpaid) _expired();
      })
      ..listen(_pay.select((p) => p.stage), (_, stage) {
        // Trips, its card, the booking and Home's card read it again.
        if (stage == PayStage.idle || stage == PayStage.paying) return;
        refreshBookings(ref, widget.args.booking.id);
        if (stage == PayStage.paid) ref.invalidate(payOptionsProvider);
      });
    final stage = watch.stage;
    // Kept while the booking is to be paid, so "Change method" after a
    // failure still has the wallet and the numbers.
    if (stage == PaymentStage.accepted) ref.watch(payOptionsProvider);
    final paying = switch (pay.stage) {
      PayStage.idle || PayStage.paying => false,
      _ => true,
    };
    final busy = _cancelling || pay.stage == PayStage.paying;
    final error =
        _error ??
        switch (pay) {
          PayFlow(stage: PayStage.idle, :final error?) => failureMessage(
            context,
            error,
          ),
          _ => null,
        };
    return PopScope(
      canPop:
          widget.args.restored &&
          !busy &&
          !(pay.stage == PayStage.failed && !pay.holdOver),
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
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _checkFit,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      TroskySpacing.s18,
                      TroskySpacing.s16,
                      TroskySpacing.s18,
                      _listBottomPadding,
                    ),
                    children: [
                      if (stage == PaymentStage.accepted &&
                          watch.acceptedHere &&
                          !paying)
                        ..._banner(
                          l10n.paymentAccepted,
                          TroskyStatusTone.success,
                        ),
                      if (stage == PaymentStage.moved && !paying)
                        ..._banner(
                          watch.moveReason == MoveReason.declined
                              ? l10n.paymentMovedDeclined
                              : l10n.paymentMovedUnanswered,
                          TroskyStatusTone.info,
                        ),
                      _card(l10n, watch),
                      if (paying)
                        _payStage(l10n, watch, pay)
                      else
                        ...switch (stage) {
                          PaymentStage.waiting ||
                          PaymentStage.moved => _waiting(l10n, watch),
                          PaymentStage.accepted => [
                            const SizedBox(height: TroskySpacing.s16),
                            _payWith(l10n, watch, pay),
                          ],
                          PaymentStage.notAccepted => _notAccepted(l10n),
                          PaymentStage.holdExpired ||
                          PaymentStage.cancelled => const [],
                        },
                      if (watch.offline &&
                          (stage == PaymentStage.waiting ||
                              stage == PaymentStage.moved)) ...[
                        const SizedBox(height: TroskySpacing.s16),
                        PaymentOfflineNote(l10n.paymentOffline),
                      ],
                      if (error != null) ...[
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
              ),
              _bottom(l10n, watch, pay),
            ],
          ),
        ),
      ),
    );
  }

  /// Space under the list; scrolling only it away hides nothing.
  static const double _listBottomPadding = TroskySpacing.s24;

  bool _checkFit(ScrollMetricsNotification notification) {
    final stage = ref.read(_watch).stage;
    final waiting =
        stage == PaymentStage.waiting || stage == PaymentStage.moved;
    if (waiting &&
        !_countdownBelow &&
        notification.metrics.maxScrollExtent > _listBottomPadding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _countdownBelow = true);
      });
    }
    return false;
  }

  /// "2-minute response window", when the window is known.
  String? _windowCaption(AppLocalizations l10n, BookingWatch watch) {
    final window = watch.answerWindow;
    if (window == null || window <= Duration.zero) return null;
    return l10n.paymentAnswerWindow(
      (window.inSeconds / 60).round().clamp(1, 60),
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
        seatNumbersFrom(
          booking,
          ref.watch(tripSeatsProvider(booking.tripId)).value,
        );
    return TroskyTripSummaryCard(
      from: booking.boardingStopName ?? trip?.originStopName ?? '',
      to: booking.alightingStopName ?? trip?.destinationStopName ?? '',
      day: departs == null ? '' : bookingDay(l10n, departs, _now),
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
          seats == null ? '…' : seatList(l10n, seats),
        ),
        TroskyTripFact(
          l10n.paymentTotal,
          cedis(l10n, booking.totalAmount),
          valueColor: TroskyColors.greenDark,
        ),
      ],
    );
  }

  List<Widget> _waiting(AppLocalizations l10n, BookingWatch watch) {
    final moved = watch.stage == PaymentStage.moved;
    final left = _left(watch);
    final time = timeLeft(left);
    return [
      const SizedBox(height: TroskySpacing.s32),
      const Center(child: TroskyPulseDot()),
      const SizedBox(height: TroskySpacing.s24),
      PaymentMessage(
        title: moved ? l10n.paymentNewDriverTitle : l10n.paymentWaitingTitle,
        body: moved ? l10n.paymentNewDriverBody : l10n.paymentWaitingBody,
      ),
      if (!_countdownBelow) ...[
        const SizedBox(height: TroskySpacing.s14),
        TroskyCountdown(
          time: time,
          caption: _windowCaption(l10n, watch),
          semanticsLabel: l10n.paymentAnswerTimeLeft(time),
          announce: left.inSeconds % 30 == 0,
        ),
      ],
    ];
  }

  /// "PAY WITH" (P-07): the method shown, its balance or number, "Change".
  Widget _payWith(AppLocalizations l10n, BookingWatch watch, PayFlow pay) {
    final options = ref.watch(payOptionsProvider);
    final amount = watch.booking.totalAmount;
    final value = options.value;
    final method = _chosen(value, amount);
    final wallet = value?.wallet;
    final covers = value?.walletCovers(amount) ?? true;
    final (kind, title, detail) = switch (method) {
      WalletPay() => (
        TroskyPayMethodKind.wallet,
        l10n.payWallet,
        switch (wallet) {
          null when options.isLoading => '…',
          null => l10n.payWalletBalanceUnknown,
          _ when !covers => l10n.payWalletNotEnough(
            cedis(l10n, wallet.balance),
          ),
          _ => l10n.payWalletBalance(cedis(l10n, wallet.balance)),
        },
      ),
      MomoPay(:final method) => (
        TroskyPayMethodKind.momo,
        l10n.payMomo,
        momoDetail(method),
      ),
    };
    return TroskyPayWithCard(
      label: l10n.payWithLabel,
      kind: kind,
      title: title,
      detail: detail,
      detailColor: method is WalletPay && !covers
          ? TroskyColors.redDark
          : TroskyColors.textSecondary,
      action: l10n.payChange,
      onPressed: pay.stage == PayStage.paying ? null : _changeMethod,
    );
  }

  /// Pay can be tapped: the options are in (or failed: the server
  /// decides), and the method can pay.
  bool _canPay(BookingWatch watch, PayFlow pay) {
    if (pay.stage != PayStage.idle) return false;
    final options = ref.read(payOptionsProvider);
    if (options.isLoading && !options.hasValue) return false;
    final amount = watch.booking.totalAmount;
    final method = _chosen(options.value, amount);
    return method is! WalletPay ||
        (options.value?.walletCovers(amount) ?? true);
  }

  /// After Pay: approving on the phone (P-08) or the outcome (P-09).
  Widget _payStage(AppLocalizations l10n, BookingWatch watch, PayFlow pay) {
    final total = cedis(l10n, watch.booking.totalAmount);
    final booking = pay.booking ?? watch.booking;
    switch (pay.stage) {
      case PayStage.approving:
        final method = pay.method;
        return PayApproving(
          amount: total,
          number: method is MomoPay
              ? localMasked(method.method.maskedNumber)
              : null,
          left: _left(watch),
          offline: pay.offline,
        );
      case PayStage.paid:
        final wallet = pay.payment?.channel == PaymentChannel.wallet;
        return PayOutcome(
          tile: PayOutcome.paid,
          title: l10n.paySuccessTitle,
          body: wallet
              ? l10n.paySuccessWallet(total)
              : l10n.paySuccessMomo(total),
          reference: booking.bookingReference,
        );
      case PayStage.failed when !pay.holdOver:
        final reason = (pay.payment?.failureReason ?? '').toUpperCase();
        final why = switch (reason) {
          _ when pay.error?.code == 'INSUFFICIENT_WALLET_BALANCE' =>
            l10n.payFailedWallet(total),
          _ when reason.contains('DECLIN') || reason.contains('REJECT') =>
            l10n.payFailedDeclined,
          _ when reason.contains('EXPIRED') || reason.contains('TIMEOUT') =>
            l10n.payFailedExpired,
          _
              when reason.contains('NOT_ENOUGH_FUNDS') ||
                  reason.contains('INSUFFICIENT') =>
            l10n.payFailedMomoFunds,
          _ => l10n.payFailedGeneric,
        };
        return PayOutcome(
          tile: PayOutcome.failed,
          title: l10n.payFailedTitle,
          body: '$why ${l10n.payFailedHeld(timeLeft(_left(watch)))}',
        );
      case PayStage.failed || PayStage.timedOut:
        final late = pay.payment?.status == PaymentStatus.successful;
        return PayOutcome(
          tile: PayOutcome.timedOut,
          title: l10n.payTimedOutTitle,
          body: late ? l10n.payLateBody(total) : l10n.payTimedOutBody,
        );
      case PayStage.idle || PayStage.paying:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _notAccepted(AppLocalizations l10n) => [
    const SizedBox(height: TroskySpacing.s32),
    Center(
      child: TroskyStatusTile(
        icon: TroskyIcons.bookingNotAccepted(color: TroskyColors.textSecondary),
      ),
    ),
    const SizedBox(height: TroskySpacing.s24),
    PaymentMessage(
      title: l10n.paymentNotAcceptedTitle,
      body: l10n.paymentNotAcceptedBody,
      large: true,
    ),
  ];

  Widget _bottom(AppLocalizations l10n, BookingWatch watch, PayFlow pay) {
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
    // The white bar of the accepted design: a timer row above the button.
    Widget panel(Widget timer, [Widget? button]) => DecoratedBox(
      decoration: const BoxDecoration(
        color: TroskyColors.surface,
        border: Border(
          top: BorderSide(color: TroskyColors.border, width: TroskyBorders.w1),
        ),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            timer,
            const SizedBox(height: TroskySpacing.s12),
            button ?? cancel,
          ],
        ),
      ),
    );
    // Search again, or Home: nothing more to do with this booking.
    Widget over() => Padding(
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
    switch (pay.stage) {
      case PayStage.approving:
        return Padding(
          padding: padding,
          child: TroskyButton(
            label: l10n.payNoPrompt,
            variant: TroskyButtonVariant.outlinePill,
            onPressed: _noPrompt,
          ),
        );
      case PayStage.paid:
        // "View ticket" joins it with tickets (Step 16).
        return Padding(
          padding: padding,
          child: TroskyButton(
            label: l10n.payGoToTrips,
            variant: TroskyButtonVariant.primary,
            onPressed: _trips,
          ),
        );
      case PayStage.failed when !pay.holdOver:
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TroskyButton(
                label: l10n.payTryAgain,
                variant: TroskyButtonVariant.primary,
                onPressed: _payNow,
              ),
              const SizedBox(height: TroskySpacing.s4),
              TroskyTextLink(
                prompt: '',
                action: l10n.payChangeMethod,
                actionColor: TroskyColors.blue,
                actionStyle: TroskyTypography.heading14Bold,
                onPressed: _changeMethod,
              ),
            ],
          ),
        );
      case PayStage.failed || PayStage.timedOut:
        return over();
      case PayStage.idle || PayStage.paying:
        break;
    }
    switch (watch.stage) {
      case PaymentStage.waiting || PaymentStage.moved:
        if (!_countdownBelow) return Padding(padding: padding, child: cancel);
        final left = _left(watch);
        final time = timeLeft(left);
        final caption = _windowCaption(l10n, watch);
        return panel(
          Semantics(
            liveRegion: left.inSeconds % 30 == 0,
            label: l10n.paymentAnswerTimeLeft(time),
            excludeSemantics: true,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TroskySpacing.s8,
              children: [
                TroskyIcons.clock(color: TroskyColors.green, size: 16),
                Text(
                  time,
                  style: TroskyTypography.heading18ExtraBold.copyWith(
                    color: TroskyColors.greenDark,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (caption != null)
                  Text(
                    caption,
                    style: TroskyTypography.body12Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        );
      case PaymentStage.accepted:
        final time = timeLeft(_left(watch));
        return panel(
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
          TroskyButton(
            label: l10n.payButton(cedis(l10n, watch.booking.totalAmount)),
            variant: TroskyButtonVariant.primary,
            loading: pay.stage == PayStage.paying,
            onPressed: _canPay(watch, pay) ? _payNow : null,
          ),
        );
      case PaymentStage.notAccepted:
        return over();
      case PaymentStage.holdExpired || PaymentStage.cancelled:
        return const SizedBox.shrink();
    }
  }
}

/// What the passenger chose on the leave-payment sheet.
enum LeaveChoice {
  /// Keep the seats held and go to Home (they can pay from Home or Trips).
  keep,

  /// Release the seats and choose again.
  release,
}

/// "Leave payment?" (decision 31, derived from the cancel sheet of P-16):
/// the seats stay held for [timeLeft] ("9:12"). Null: stay on Payment.
Future<LeaveChoice?> showLeavePaymentSheet(
  BuildContext context, {
  required String timeLeft,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<LeaveChoice>(
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
                l10n.paymentLeaveTitle,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.paymentLeaveBody(timeLeft),
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: l10n.paymentLeaveKeep,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(LeaveChoice.keep),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.paymentReleaseConfirm,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(LeaveChoice.release),
            ),
          ],
        ),
      ),
    ),
  );
}
