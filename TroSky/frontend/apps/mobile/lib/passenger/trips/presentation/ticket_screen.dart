import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../app/secure_window.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/ticket_providers.dart';
import '../domain/ticket_args.dart';
import 'ticket_pill.dart';

/// Ticket (P-10): the boarding pass with the signed QR, one page per
/// booked seat.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.args});

  final TicketArgs args;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.args.initialPage,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _page = widget.args.initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(telemetryProvider)
          .emit(
            TelemetryEvent('ticket_opened', {
              'booking_status': widget.args.booking.status.name,
            }),
          );
    });
  }

  void _onPageChanged(int to) {
    final from = _page;
    setState(() => _page = to);
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('ticket_swiped', {'from': from, 'to': to}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = widget.args.booking;
    final viewAsync = ref.watch(bookingTicketsProvider(booking.id));
    return TroskySecureScreen(
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: viewAsync.when(
          loading: () => _Scaffold(
            booking: booking,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _Scaffold(
            booking: booking,
            child: _OfflineState(
              title: l10n.ticketOfflineTitle,
              subline: l10n.ticketOfflineSubline,
              retryLabel: l10n.ticketRetry,
              onRetry: () => ref.invalidate(bookingTicketsProvider(booking.id)),
            ),
          ),
          data: (view) {
            final tickets = view.tickets;
            if (tickets.isEmpty) {
              return _Scaffold(
                booking: booking,
                child: _ErrorState(message: l10n.ticketEmpty, onRetry: null),
              );
            }
            return _Scaffold(
              booking: booking,
              banner: view.staleBannerVisible ? l10n.ticketOfflineBanner : null,
              child: Column(
                children: [
                  if (tickets.length > 1)
                    _PageIndicator(current: _page, total: tickets.length),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: tickets.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, i) => _TicketPage(
                        booking: booking,
                        ticket: tickets[i],
                        seatIndex: i,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({
    required this.title,
    required this.subline,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String subline;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '$title. $subline',
        container: true,
        child: Padding(
          padding: const EdgeInsets.all(TroskySpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
              const SizedBox(height: TroskySpacing.s8),
              Text(
                subline,
                textAlign: TextAlign.center,
                style: TroskyTypography.body14Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: retryLabel,
                variant: TroskyButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.booking, required this.child, this.banner});

  final BookingResponse booking;
  final Widget child;

  /// Optional "Showing last synced ticket" strip above the content.
  final String? banner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = booking.trip;
    final from = booking.boardingStopName ?? trip?.originStopName ?? '';
    final to = booking.alightingStopName ?? trip?.destinationStopName ?? '';
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: TroskyGradients.navyHeader),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TroskySpacing.s16,
                TroskySpacing.s8,
                TroskySpacing.s20,
                TroskySpacing.s20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(),
                  const SizedBox(height: TroskySpacing.s8),
                  Text(
                    l10n.ticketBoardingPass,
                    style: TroskyTypography.body12SemiBoldH133.copyWith(
                      color: TroskyColors.whiteA55,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: TroskySpacing.s6),
                  Text(
                    l10n.ticketRouteHeadline(from, to),
                    style: TroskyTypography.heading24ExtraBold.copyWith(
                      color: TroskyColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (banner != null) _StaleCacheBanner(message: banner!),
        Expanded(child: child),
      ],
    );
  }
}

class _StaleCacheBanner extends StatelessWidget {
  const _StaleCacheBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: TroskyColors.amberA15,
      padding: const EdgeInsets.symmetric(
        horizontal: TroskySpacing.s16,
        vertical: TroskySpacing.s8,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TroskyTypography.body12SemiBoldH133.copyWith(
            color: TroskyColors.goldText,
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.all(TroskySpacing.s8),
          child: Icon(Icons.chevron_left, color: TroskyColors.white, size: 28),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TroskySpacing.s12),
      child: Semantics(
        label: l10n.ticketPageDotsLabel(current + 1, total),
        child: total > 3
            ? Text(
                l10n.ticketCountOf(current + 1, total),
                style: TroskyTypography.body13Medium.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < total; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: i == current ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == current
                              ? TroskyColors.navy
                              : TroskyColors.border,
                          borderRadius: BorderRadius.circular(TroskyRadii.full),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TicketPage extends ConsumerStatefulWidget {
  const _TicketPage({
    required this.booking,
    required this.ticket,
    required this.seatIndex,
  });

  final BookingResponse booking;
  final TicketResponse ticket;
  final int seatIndex;

  @override
  ConsumerState<_TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<_TicketPage> {
  final GlobalKey _boundaryKey = GlobalKey();

  /// Grabs the RepaintBoundary and writes it to a 3× PNG in the app temp
  /// dir. Returns the temp-file path; a null means capture failed.
  Future<String?> _writeImage() async {
    final context = _boundaryKey.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ticket-${widget.ticket.ticketReference}.png',
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } finally {
      image.dispose();
    }
  }

  Future<void> _save() async {
    await _share('ticket_saved');
  }

  Future<void> _shareTicket() async {
    await _share('ticket_shared');
  }

  Future<void> _share(String event) async {
    final path = await _writeImage();
    if (path == null) return;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent(event, {'seat_index': widget.seatIndex}));
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final trip = widget.booking.trip;
    final departure = trip?.scheduledDepartureAt ?? widget.ticket.issuedAt;
    final pill = ticketPillStateFor(
      widget.ticket.status,
      tripDeparture: departure,
      tripEnd: widget.ticket.expiresAt,
      now: now,
    );
    final passenger = widget.booking.passengers.length > widget.seatIndex
        ? widget.booking.passengers[widget.seatIndex]
        : null;
    final seatNumber = passenger?.seatId ?? '';
    final fromName =
        widget.booking.boardingStopName ?? trip?.originStopName ?? '';
    final toName =
        widget.booking.alightingStopName ?? trip?.destinationStopName ?? '';
    final route = l10n.ticketRouteHeadline(fromName, toName);
    final timeText = DateFormat(
      'HH:mm',
      l10n.localeName,
    ).format(departure.toLocal());
    final qrSemantics = l10n.ticketSemanticLabel(route, timeText, seatNumber);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TroskySpacing.s20,
        TroskySpacing.s16,
        TroskySpacing.s20,
        TroskySpacing.s20,
      ),
      child: Column(
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: Column(
              children: [
                _Card(
                  pill: pill,
                  validatedAt: widget.ticket.validatedAt,
                  qrToken: widget.ticket.qrToken,
                  qrSemantics: qrSemantics,
                  ticketReference: widget.ticket.ticketReference,
                  seatNumber: seatNumber,
                  departs: timeText,
                  fare: widget.booking.fareAmount,
                ),
                const SizedBox(height: TroskySpacing.s14),
                _PassengerCard(
                  name: passenger?.fullName ?? '',
                  paid:
                      widget.booking.status == BookingStatus.confirmed ||
                      widget.booking.status == BookingStatus.completed,
                ),
              ],
            ),
          ),
          const SizedBox(height: TroskySpacing.s12),
          _CantScanExpander(reference: widget.ticket.ticketReference),
          const SizedBox(height: TroskySpacing.s12),
          Row(
            children: [
              Expanded(
                child: TroskyButton(
                  label: l10n.ticketSave,
                  variant: TroskyButtonVariant.outline,
                  onPressed: _save,
                ),
              ),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: TroskyButton(
                  label: l10n.ticketShare,
                  variant: TroskyButtonVariant.primary,
                  onPressed: _shareTicket,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.pill,
    required this.validatedAt,
    required this.qrToken,
    required this.qrSemantics,
    required this.ticketReference,
    required this.seatNumber,
    required this.departs,
    required this.fare,
  });

  final TicketPillState pill;
  final DateTime? validatedAt;
  final String qrToken;
  final String qrSemantics;
  final String ticketReference;
  final String seatNumber;
  final String departs;
  final String fare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
      ),
      padding: const EdgeInsets.all(TroskySpacing.s20),
      child: Column(
        children: [
          TicketPill(state: pill, validatedAt: validatedAt),
          const SizedBox(height: TroskySpacing.s20),
          Semantics(
            label: qrSemantics,
            image: true,
            child: _QrImage(data: qrToken),
          ),
          const SizedBox(height: TroskySpacing.s16),
          Text(
            l10n.ticketScanSubline,
            style: TroskyTypography.body14Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: TroskySpacing.s4),
          Text(
            ticketReference,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textMuted,
            ),
          ),
          const SizedBox(height: TroskySpacing.s16),
          const _DashedDivider(),
          const SizedBox(height: TroskySpacing.s16),
          Row(
            children: [
              Expanded(
                child: _StripItem(label: l10n.ticketSeat, value: seatNumber),
              ),
              Expanded(
                child: _StripItem(label: l10n.ticketDeparts, value: departs),
              ),
              Expanded(
                child: _StripItem(label: l10n.ticketFare, value: '₵$fare'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 220,
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        backgroundColor: TroskyColors.white,
        padding: const EdgeInsets.all(12),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: TroskyColors.navy,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: TroskyColors.navy,
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          const dash = 4.0;
          const gap = 4.0;
          final count = (c.maxWidth / (dash + gap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(width: dash, height: 1, color: TroskyColors.border),
            ],
          );
        },
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TroskyTypography.body12Regular.copyWith(
            color: TroskyColors.textMuted,
          ),
        ),
        const SizedBox(height: TroskySpacing.s4),
        Text(
          value,
          style: TroskyTypography.body16Regular.copyWith(
            color: TroskyColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.name, required this.paid});

  final String name;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '';
    return Container(
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r20),
      ),
      padding: const EdgeInsets.all(TroskySpacing.s16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TroskyColors.navy,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: TroskyTypography.heading20Bold.copyWith(
                color: TroskyColors.white,
              ),
            ),
          ),
          const SizedBox(width: TroskySpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TroskyTypography.body16Regular,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TroskySpacing.s2),
                // TODO(step20): render the verification line from the
                // passenger's Ghana-Card KYC field once the backend
                // ships it; for now the design's placeholder.
                Text(
                  l10n.ticketVerifiedGhanaCard,
                  style: TroskyTypography.body13Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (paid)
            TroskyChip(label: l10n.ticketPaid, color: TroskyChipColor.green),
        ],
      ),
    );
  }
}

@visibleForTesting
Widget cantScanExpanderForTest(String reference) =>
    _CantScanExpander(reference: reference);

class _CantScanExpander extends StatefulWidget {
  const _CantScanExpander({required this.reference});

  final String reference;

  @override
  State<_CantScanExpander> createState() => _CantScanExpanderState();
}

class _CantScanExpanderState extends State<_CantScanExpander> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          toggled: _open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s8),
              child: Text(
                l10n.ticketCantScan,
                textAlign: TextAlign.center,
                style: TroskyTypography.body13Medium.copyWith(
                  color: TroskyColors.blueDark,
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: TroskySpacing.s8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  widget.reference,
                  style: TroskyTypography.body16Regular.copyWith(
                    color: TroskyColors.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: TroskySpacing.s8),
                Semantics(
                  label: AppLocalizations.of(context).bookingCopyReference,
                  button: true,
                  container: true,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: AppLocalizations.of(context).bookingCopyReference,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.reference),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TroskySpacing.s12),
              TroskyButton(
                label: AppLocalizations.of(context).ticketRetry,
                variant: TroskyButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
