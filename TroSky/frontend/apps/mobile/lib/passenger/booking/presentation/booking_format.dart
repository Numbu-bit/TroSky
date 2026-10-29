import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';

import '../../../l10n/app_localizations.dart';
import '../../search/presentation/trip_view.dart';
import '../../seats/domain/seat_map_layout.dart';

// How a booking reads on Payment (P-07), Trip History (P-15) and Booking
// details (P-16). Days are on the phone's calendar.

int _daysFrom(DateTime now, DateTime departs) => DateUtils.dateOnly(
  departs.toLocal(),
).difference(DateUtils.dateOnly(now.toLocal())).inDays;

/// "Today", "Tomorrow" or "Mon 27 Oct".
String bookingDay(AppLocalizations l10n, DateTime departs, DateTime now) =>
    switch (_daysFrom(now, departs)) {
      0 => l10n.paymentToday,
      1 => l10n.paymentTomorrow,
      _ => DateFormat('EEE d MMM', l10n.localeName).format(departs.toLocal()),
    };

/// "Today, 08:30", "Yesterday, 17:15", "Mon, 07:45" within a week, else
/// "12 Oct, 08:30": a Trip History row (P13).
String bookingWhen(AppLocalizations l10n, DateTime departs, DateTime now) {
  final days = _daysFrom(now, departs);
  final local = departs.toLocal();
  final day = switch (days) {
    0 => l10n.paymentToday,
    1 => l10n.paymentTomorrow,
    -1 => l10n.tripsYesterday,
    _ when days.abs() < 7 => DateFormat('EEE', l10n.localeName).format(local),
    _ => DateFormat('d MMM', l10n.localeName).format(local),
  };
  return l10n.tripsWhen(day, clockTime(departs));
}

/// "B3", "B3 & B4", "B3, B4 & B5".
String seatList(AppLocalizations l10n, List<String> seats) => seats.length < 2
    ? seats.join()
    : l10n.paymentSeatsAnd(
        seats.sublist(0, seats.length - 1).join(', '),
        seats.last,
      );

/// "1:42": minutes and seconds left.
String timeLeft(Duration left) =>
    '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';

/// "₵16.00": booking amounts keep their pesewas.
String cedis(AppLocalizations l10n, String amount) =>
    l10n.priceCedis(double.parse(amount).toStringAsFixed(2));

/// The booked seats' numbers in seat order, from the trip's seat map ("?"
/// for one the map lacks); null until the map is in.
List<String>? seatNumbersFrom(
  BookingResponse booking,
  TripSeatsResponse? seats,
) {
  if (seats == null) return null;
  final numbers = {for (final s in seats.seats) s.id: s.seatNumber};
  return [for (final p in booking.passengers) numbers[p.seatId] ?? '?']
    ..sort(compareSeatNumbers);
}
