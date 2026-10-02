import '../../../l10n/app_localizations.dart';

/// Parts of the day for the Home greeting.
enum DayPart { morning, afternoon, evening }

/// Morning from 5:00 to 11:59, afternoon from 12:00 to 16:59, evening from
/// 17:00 to 4:59, on the phone's clock.
DayPart dayPartOf(DateTime time) => switch (time.hour) {
  >= 5 && < 12 => DayPart.morning,
  >= 12 && < 17 => DayPart.afternoon,
  _ => DayPart.evening,
};

/// "Good morning", "Good afternoon" or "Good evening" for [time].
String greetingFor(AppLocalizations l10n, DateTime time) =>
    switch (dayPartOf(time)) {
      DayPart.morning => l10n.homeGreetingMorning,
      DayPart.afternoon => l10n.homeGreetingAfternoon,
      DayPart.evening => l10n.homeGreetingEvening,
    };
