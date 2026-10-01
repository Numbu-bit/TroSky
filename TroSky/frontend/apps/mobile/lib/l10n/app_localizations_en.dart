// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get splashTagline => 'Your Journey. On Time.';

  @override
  String get splashSubtitle => 'Ghana\'s Shared Transport Platform';

  @override
  String get splashLoading => 'Loading';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String onboardingPageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get onboarding1Title => 'Book a Seat,\nNot a Whole Car';

  @override
  String get onboarding1Body =>
      'Find a shared vehicle going your way, book a single seat, and split the fare with fellow riders.';

  @override
  String get onboarding2Title => 'Share the Ride,\nSplit the Fare';

  @override
  String get onboarding2Body =>
      'As more passengers board, the cost splits between you, so you pay a fraction of what a private ride would cost.';

  @override
  String get onboarding3Title => 'Subscribe Your\nDaily Commute';

  @override
  String get onboarding3Body =>
      'Set up a recurring commute, your vehicle, guaranteed, every morning and evening.';
}
