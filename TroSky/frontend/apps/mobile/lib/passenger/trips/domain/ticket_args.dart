import 'package:trosky_api/trosky_api.dart';

/// Opens the Ticket screen for a booking already loaded on Trips.
class TicketArgs {
  const TicketArgs({required this.booking, this.initialPage = 0});

  final BookingResponse booking;

  /// Which seat the PageView opens on (default: 0 = first seat).
  final int initialPage;
}

/// Feature flag that gates both the "Show ticket" button in booking
/// details and the whole [TicketScreen]. Off by default on every env
/// until PR 2 of Step 16 lands (encrypted Hive cache + save/share).
/// Build staging/demo with `--dart-define=TICKET_QR_ENABLED=true` to try
/// it locally.
const bool ticketQrEnabled = bool.fromEnvironment('TICKET_QR_ENABLED');
