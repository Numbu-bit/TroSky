import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
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
  void initState() {
    super.initState();
    _page = widget.args.initialPage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = widget.args.booking;
    final ticketsAsync = ref.watch(bookingTicketsProvider(booking.id));
    return Scaffold(
      backgroundColor: TroskyColors.background,
      body: ticketsAsync.when(
        loading: () => _Scaffold(
          booking: booking,
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _Scaffold(
          booking: booking,
          child: _ErrorState(
            message: l10n.ticketError,
            onRetry: () => ref.invalidate(bookingTicketsProvider(booking.id)),
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return _Scaffold(
              booking: booking,
              child: _ErrorState(message: l10n.ticketEmpty, onRetry: null),
            );
          }
          return _Scaffold(
            booking: booking,
            child: Column(
              children: [
                if (tickets.length > 1)
                  _PageIndicator(current: _page, total: tickets.length),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: tickets.length,
                    onPageChanged: (i) => setState(() => _page = i),
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
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.booking, required this.child});

  final BookingResponse booking;
  final Widget child;

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
        Expanded(child: child),
      ],
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

class _TicketPage extends ConsumerWidget {
  const _TicketPage({
    required this.booking,
    required this.ticket,
    required this.seatIndex,
  });

  final BookingResponse booking;
  final TicketResponse ticket;
  final int seatIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final trip = booking.trip;
    final departure = trip?.scheduledDepartureAt ?? ticket.issuedAt;
    final pill = ticketPillStateFor(
      ticket.status,
      tripDeparture: departure,
      tripEnd: ticket.expiresAt,
      now: now,
    );
    final passenger = booking.passengers.length > seatIndex
        ? booking.passengers[seatIndex]
        : null;
    final seatNumber = passenger?.seatId ?? '';
    final fromName = booking.boardingStopName ?? trip?.originStopName ?? '';
    final toName = booking.alightingStopName ?? trip?.destinationStopName ?? '';
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
          _Card(
            pill: pill,
            validatedAt: ticket.validatedAt,
            qrToken: ticket.qrToken,
            qrSemantics: qrSemantics,
            ticketReference: ticket.ticketReference,
            seatNumber: seatNumber,
            departs: timeText,
            fare: booking.fareAmount,
          ),
          const SizedBox(height: TroskySpacing.s14),
          _PassengerCard(
            name: passenger?.fullName ?? '',
            paid:
                booking.status == BookingStatus.confirmed ||
                booking.status == BookingStatus.completed,
          ),
          const SizedBox(height: TroskySpacing.s12),
          _CantScanExpander(reference: ticket.ticketReference),
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
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: widget.reference),
                    );
                  },
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
