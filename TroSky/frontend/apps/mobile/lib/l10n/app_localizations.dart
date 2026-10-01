import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Heading under the logo on the splash screen (S-01).
  ///
  /// In en, this message translates to:
  /// **'Your Journey. On Time.'**
  String get splashTagline;

  /// Line under the splash heading (S-01).
  ///
  /// In en, this message translates to:
  /// **'Ghana\'s Shared Transport Platform'**
  String get splashSubtitle;

  /// Screen reader label for the animated loading dots on the splash screen.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get splashLoading;

  /// Top-right link on every onboarding page (S-02); skips to Sign Up.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Button on onboarding pages 1 and 2 (S-02).
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Button on the last onboarding page (S-02); goes to Sign Up.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// Screen reader label for the onboarding page dots (S-02).
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String onboardingPageOf(int page, int count);

  /// Onboarding page 1 heading (S-02). The line break is part of the design.
  ///
  /// In en, this message translates to:
  /// **'Book a Seat,\nNot a Whole Car'**
  String get onboarding1Title;

  /// Onboarding page 1 text (S-02).
  ///
  /// In en, this message translates to:
  /// **'Find a shared vehicle going your way, book a single seat, and split the fare with fellow riders.'**
  String get onboarding1Body;

  /// Onboarding page 2 heading (S-02). The line break is part of the design.
  ///
  /// In en, this message translates to:
  /// **'Share the Ride,\nSplit the Fare'**
  String get onboarding2Title;

  /// Onboarding page 2 text (S-02).
  ///
  /// In en, this message translates to:
  /// **'As more passengers board, the cost splits between you, so you pay a fraction of what a private ride would cost.'**
  String get onboarding2Body;

  /// Onboarding page 3 heading (S-02). The line break is part of the design.
  ///
  /// In en, this message translates to:
  /// **'Subscribe Your\nDaily Commute'**
  String get onboarding3Title;

  /// Onboarding page 3 text (S-02).
  ///
  /// In en, this message translates to:
  /// **'Set up a recurring commute, your vehicle, guaranteed, every morning and evening.'**
  String get onboarding3Body;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
