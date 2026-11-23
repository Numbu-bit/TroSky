import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../l10n/app_localizations.dart';

/// The pill above the QR. Colour + label come from [ticketPillStateFor]
/// mapped onto [TroskyChip]'s existing tones so no new tokens appear.
class TicketPill extends StatelessWidget {
  const TicketPill({super.key, required this.state, this.validatedAt});

  final TicketPillState state;

  /// Required when [state] is [TicketPillState.used] — the time the
  /// backend validated the ticket.
  final DateTime? validatedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (state) {
      TicketPillState.notYetValid => (
        l10n.ticketPillNotYetValid,
        TroskyChipColor.gray,
      ),
      TicketPillState.readyToBoard => (
        l10n.ticketPillReadyToBoard,
        TroskyChipColor.green,
      ),
      TicketPillState.used => (
        l10n.ticketPillUsed(_validatedTime(l10n, validatedAt)),
        TroskyChipColor.blue,
      ),
      TicketPillState.expired => (
        l10n.ticketPillExpired,
        TroskyChipColor.amber,
      ),
      TicketPillState.notValid => (
        l10n.ticketPillNotValid,
        TroskyChipColor.red,
      ),
    };
    return TroskyChip(label: label, color: color);
  }

  String _validatedTime(AppLocalizations l10n, DateTime? at) => at == null
      ? ''
      : DateFormat('HH:mm', l10n.localeName).format(at.toLocal());
}
