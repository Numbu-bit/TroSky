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

  /// Welcome screen (S-04, P4_SignUp) heading, as designed.
  ///
  /// In en, this message translates to:
  /// **'Welcome to TroSky'**
  String get welcomeTitle;

  /// Welcome screen (S-04, P4_SignUp) subtitle, as designed.
  ///
  /// In en, this message translates to:
  /// **'Your journey. On time. Every time.'**
  String get welcomeSubtitle;

  /// Label above the phone field, in capitals as designed.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneLabel;

  /// Placeholder in the phone field, as designed.
  ///
  /// In en, this message translates to:
  /// **'XX XXX XXXX'**
  String get phoneHint;

  /// Screen reader label for the country prefix.
  ///
  /// In en, this message translates to:
  /// **'Country: Ghana, +233'**
  String get phoneCountry;

  /// Title of the one-item country sheet.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countrySheetTitle;

  /// The only country in the sheet.
  ///
  /// In en, this message translates to:
  /// **'Ghana (+233)'**
  String get countryGhana;

  /// Note under the country list.
  ///
  /// In en, this message translates to:
  /// **'TroSky is only in Ghana for now.'**
  String get countryOnlyGhana;

  /// Welcome screen (S-04, P4_SignUp) button. 'Continue' instead of the design's 'Send OTP' (decision 11).
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get welcomeContinue;

  /// Welcome screen (S-04, P4_SignUp) divider, as designed.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get welcomeOrContinueWith;

  /// Welcome screen (S-04, P4_SignUp) email button, as designed.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get welcomeContinueWithEmail;

  /// Ghana Card note, before the green words.
  ///
  /// In en, this message translates to:
  /// **'Optionally verify your '**
  String get welcomeGhanaCardBefore;

  /// Ghana Card note, the green bold words.
  ///
  /// In en, this message translates to:
  /// **'Ghana Card'**
  String get welcomeGhanaCardHighlight;

  /// Ghana Card note, after the green words.
  ///
  /// In en, this message translates to:
  /// **' for extra trust and higher wallet limits.'**
  String get welcomeGhanaCardAfter;

  /// Welcome screen (S-04, P4_SignUp) link prompt (not in Figma).
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get welcomeHaveAccount;

  /// Welcome screen (S-04, P4_SignUp) link action.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get welcomeSignIn;

  /// Welcome screen (S-04, P4_SignUp) driver link prompt (decision 7).
  ///
  /// In en, this message translates to:
  /// **'Driving for TroSky?'**
  String get welcomeDriverPrompt;

  /// Welcome screen (S-04, P4_SignUp) driver link action; switches to driver mode.
  ///
  /// In en, this message translates to:
  /// **'Sign up as a driver'**
  String get welcomeDriverAction;

  /// Welcome screen (S-04, P4_SignUp) shown in driver mode.
  ///
  /// In en, this message translates to:
  /// **'Signing up as a driver.'**
  String get welcomeDriverModePrompt;

  /// Welcome screen (S-04, P4_SignUp) switches back to passenger mode.
  ///
  /// In en, this message translates to:
  /// **'Sign up as a passenger instead'**
  String get welcomeDriverModeAction;

  /// Your details screen (S-06, not in Figma) heading.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get detailsTitle;

  /// Your details screen (S-06, not in Figma) subtitle.
  ///
  /// In en, this message translates to:
  /// **'A few more details to create your account.'**
  String get detailsSubtitle;

  /// Your details screen (S-06, not in Figma) subtitle in driver mode.
  ///
  /// In en, this message translates to:
  /// **'A few more details to create your driver account.'**
  String get detailsSubtitleDriver;

  /// Label above the name field.
  ///
  /// In en, this message translates to:
  /// **'FULL NAME'**
  String get nameLabel;

  /// Placeholder in the name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ama Mensah'**
  String get nameHint;

  /// Label above the email field.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get emailLabel;

  /// Placeholder in the email field.
  ///
  /// In en, this message translates to:
  /// **'you@gmail.com'**
  String get emailHint;

  /// Your details screen (S-06, not in Figma) helper under the email field.
  ///
  /// In en, this message translates to:
  /// **'Use your Gmail address'**
  String get emailHelper;

  /// Label above the password field.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get passwordLabel;

  /// Placeholder in the password field.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHint;

  /// Button that shows the password.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get passwordShow;

  /// Button that hides the password.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get passwordHide;

  /// Password rule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordRuleLength;

  /// Password rule.
  ///
  /// In en, this message translates to:
  /// **'An upper-case letter'**
  String get passwordRuleUpper;

  /// Password rule.
  ///
  /// In en, this message translates to:
  /// **'A lower-case letter'**
  String get passwordRuleLower;

  /// Password rule.
  ///
  /// In en, this message translates to:
  /// **'A number'**
  String get passwordRuleDigit;

  /// Your details screen (S-06, not in Figma) button.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get detailsCreateAccount;

  /// Title of the sheet on Your details (S-06) before asking for location; the Home location sheet with sign-up copy.
  ///
  /// In en, this message translates to:
  /// **'Confirm you\'re in Ghana'**
  String get detailsLocationTitle;

  /// Body of the sign-up location sheet.
  ///
  /// In en, this message translates to:
  /// **'TroSky is only available in Ghana for now. To create your account, we check your location once. It isn\'t saved.'**
  String get detailsLocationBody;

  /// S-06, under the form: location was refused (or the server said LOCATION_REQUIRED). Shown with Try again.
  ///
  /// In en, this message translates to:
  /// **'TroSky needs your location once to confirm you\'re in Ghana.'**
  String get detailsLocationNeeded;

  /// S-06: location refused for good. Shown with Try again and Open settings.
  ///
  /// In en, this message translates to:
  /// **'TroSky needs your location once to confirm you\'re in Ghana. Location is blocked for TroSky: allow it in Settings.'**
  String get detailsLocationBlocked;

  /// S-06: the phone's location is switched off. Shown with Try again.
  ///
  /// In en, this message translates to:
  /// **'TroSky needs your location once to confirm you\'re in Ghana. Turn on your phone\'s location, then try again.'**
  String get detailsLocationServiceOff;

  /// S-06: no position came within 10 seconds. Shown with Try again.
  ///
  /// In en, this message translates to:
  /// **'TroSky couldn\'t find your location to confirm you\'re in Ghana. Try again in a moment.'**
  String get detailsLocationNotFound;

  /// S-06: the server said LOCATION_NOT_SERVED (the phone is outside Ghana).
  ///
  /// In en, this message translates to:
  /// **'TroSky is only available in Ghana for now.'**
  String get detailsLocationNotServed;

  /// S-06: link under a location message; asks for the location again and creates the account.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get detailsTryAgain;

  /// S-06: link under the blocked-location message; opens TroSky's page in the phone's settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get detailsOpenSettings;

  /// Code verification screen (S-07, not in Figma) heading.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeTitle;

  /// Code verification screen (S-07, not in Figma) subtitle; target is masked.
  ///
  /// In en, this message translates to:
  /// **'Code sent by text to {target}'**
  String codeSentByText(String target);

  /// Code verification screen (S-07, not in Figma) subtitle; target is masked.
  ///
  /// In en, this message translates to:
  /// **'Code sent by email to {target}'**
  String codeSentByEmail(String target);

  /// Screen reader label for the code boxes.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeFieldLabel;

  /// Code verification screen (S-07, not in Figma) button.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get codeVerify;

  /// Code verification screen (S-07, not in Figma) resend link.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get codeResend;

  /// Code verification screen (S-07, not in Figma) before the resend link.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it?'**
  String get codeResendPrompt;

  /// Code verification screen (S-07, not in Figma) while the resend cooldown runs.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String codeResendIn(int seconds);

  /// Code verification screen (S-07, not in Figma) after resending.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get codeResent;

  /// Code verification screen (S-07, not in Figma) after the cooldown, for sign-in codes (decision 10).
  ///
  /// In en, this message translates to:
  /// **'No code? Check this number has a TroSky account.'**
  String get codeNoAccountHint;

  /// Sign in screen (S-05, not in Figma) heading.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// Sign in screen (S-05, not in Figma) subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your journey.'**
  String get signInSubtitle;

  /// Sign in screen (S-05, not in Figma) switches to email.
  ///
  /// In en, this message translates to:
  /// **'Use email instead'**
  String get signInUseEmail;

  /// Sign in screen (S-05, not in Figma) switches to phone.
  ///
  /// In en, this message translates to:
  /// **'Use phone instead'**
  String get signInUsePhone;

  /// Sign in screen (S-05, not in Figma) button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// Sign in screen (S-05, not in Figma) before the code link.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPrompt;

  /// Sign in screen (S-05, not in Figma) code link (decision 10).
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get signInWithCode;

  /// Sign in screen (S-05, not in Figma) before the create-account link.
  ///
  /// In en, this message translates to:
  /// **'New to TroSky?'**
  String get signInNewPrompt;

  /// Sign in screen (S-05, not in Figma) create-account link.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signInCreateAccount;

  /// Sign in screen (S-05, not in Figma) heading in code mode.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get signInCodeTitle;

  /// Sign in screen (S-05, not in Figma) subtitle in code mode.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text a code to your phone.'**
  String get signInCodeSubtitle;

  /// Sign in screen (S-05, not in Figma) button in code mode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get signInSendCode;

  /// Sign in screen (S-05, not in Figma) leaves code mode.
  ///
  /// In en, this message translates to:
  /// **'Use my password instead'**
  String get signInUsePassword;

  /// Screen reader label for back buttons.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backLabel;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Ghana phone number.'**
  String get errorPhoneInvalid;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Enter your full name.'**
  String get errorNameRequired;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errorEmailInvalid;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Use your Gmail address ({domains}).'**
  String errorEmailDomain(String domains);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'This email already has a TroSky account.'**
  String get errorEmailTaken;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'This number already has a TroSky account.'**
  String get errorPhoneTaken;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Your password needs all four of these.'**
  String get errorPasswordRules;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get errorPasswordRequired;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'That phone number, email or password isn\'t right.'**
  String get errorInvalidCredentials;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Too many wrong passwords. Try again after {time}.'**
  String errorAccountLocked(String time);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'This account is suspended. Contact TroSky support.'**
  String get errorAccountSuspended;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait {seconds} s and try again.'**
  String errorRateLimited(int seconds);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a moment and try again.'**
  String get errorRateLimitedNoTime;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'The network is slow right now. Try again.'**
  String get errorTimeout;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check it and try again.'**
  String get errorCodeInvalid;

  /// Error message (wording from the Step 7 brief).
  ///
  /// In en, this message translates to:
  /// **'Code expired — resend'**
  String get errorCodeExpired;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Resend a new code.'**
  String get errorCodeAttempts;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'This code is no longer valid. Resend a new one.'**
  String get errorCodeMissing;

  /// Error message after OTP sign-in 404.
  ///
  /// In en, this message translates to:
  /// **'No account for this number'**
  String get errorNoAccount;

  /// Post-sign-in sheet (S-10).
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t a driver account yet'**
  String get roleNotDriverTitle;

  /// Post-sign-in sheet (S-10).
  ///
  /// In en, this message translates to:
  /// **'Become a driver to start driving with TroSky, or carry on as a passenger.'**
  String get roleNotDriverBody;

  /// Post-sign-in sheet (S-10) primary button.
  ///
  /// In en, this message translates to:
  /// **'Become a driver'**
  String get roleBecomeDriver;

  /// Post-sign-in sheet (S-10) second button.
  ///
  /// In en, this message translates to:
  /// **'Continue as passenger'**
  String get roleContinuePassenger;

  /// Post-sign-in sheet for a driver-only account in passenger mode.
  ///
  /// In en, this message translates to:
  /// **'This is a driver account'**
  String get roleDriverAccountTitle;

  /// Post-sign-in sheet
  ///
  /// In en, this message translates to:
  /// **'Switch to driver mode to continue.'**
  String get roleDriverAccountBody;

  /// Post-sign-in sheet button.
  ///
  /// In en, this message translates to:
  /// **'Switch to driver mode'**
  String get roleSwitchToDriver;

  /// Post-sign-in sheet second button: signs out.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get roleUseAnotherAccount;

  /// Banner on Home after an offline start (decision 9).
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing your last saved details.'**
  String get offlineBanner;

  /// Banner button that checks the session again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get offlineRetry;

  /// Sign out button on the Profile tab and the driver placeholder screens.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Passenger tab bar: Home tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Passenger tab bar: Trips tab.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tabTrips;

  /// Passenger tab bar: Wallet tab.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get tabWallet;

  /// Passenger tab bar: Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Home header greeting before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Home header greeting from noon to 5 pm.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Home header greeting from 5 pm to 5 am.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// Home header: the passenger's full name and a waving hand, as designed.
  ///
  /// In en, this message translates to:
  /// **'{name} 👋'**
  String homeName(String name);

  /// Home header when the account has no name yet.
  ///
  /// In en, this message translates to:
  /// **'Welcome 👋'**
  String get homeNameFallback;

  /// Home location chip when location is off or no stop is near.
  ///
  /// In en, this message translates to:
  /// **'Accra'**
  String get homeLocationFallback;

  /// Screen reader label for the Home location chip.
  ///
  /// In en, this message translates to:
  /// **'Your area: {place}'**
  String homeLocationLabel(String place);

  /// Screen reader label for the Home location chip while it loads.
  ///
  /// In en, this message translates to:
  /// **'Finding your area'**
  String get homeLocationLoading;

  /// Screen reader label for the bell on Home.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotifications;

  /// Home search bar prompt.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get homeSearchHint;

  /// Home search bar: travel time, now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get homeSearchNow;

  /// Screen reader label for the my-location map button.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get homeMyLocation;

  /// Text on the red SOS map button.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get homeSos;

  /// Screen reader label for the SOS map button.
  ///
  /// In en, this message translates to:
  /// **'SOS, emergency help'**
  String get homeSosLabel;

  /// Screen reader label for the passenger's dot on the map.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get homeYouAreHere;

  /// Screen reader label for a vehicle on the Home map.
  ///
  /// In en, this message translates to:
  /// **'{route}, {seats, plural, =1{1 seat free} other{{seats} seats free}}'**
  String homeVehicle(String route, int seats);

  /// Small note on the map when vehicles failed to load; next to Retry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load vehicles'**
  String get homeVehiclesError;

  /// Screen reader label for the map while it loads.
  ///
  /// In en, this message translates to:
  /// **'Loading map'**
  String get homeMapLoading;

  /// Home sheet heading.
  ///
  /// In en, this message translates to:
  /// **'Favourite Routes'**
  String get homeFavouriteRoutes;

  /// Home sheet link to all favourite routes.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// A favourite route chip on Home.
  ///
  /// In en, this message translates to:
  /// **'{origin} → {destination}'**
  String homeRoute(String origin, String destination);

  /// Home sheet line when the passenger has no favourite routes (decision 15).
  ///
  /// In en, this message translates to:
  /// **'No favourite routes yet.'**
  String get homeFavouritesEmpty;

  /// Home sheet line when favourites failed to load; next to Retry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your favourite routes.'**
  String get homeFavouritesError;

  /// Screen reader label for the favourites skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading favourite routes'**
  String get homeFavouritesLoading;

  /// Small label on the Home subscribe banner.
  ///
  /// In en, this message translates to:
  /// **'NEW FEATURE'**
  String get homePromoEyebrow;

  /// Home subscribe banner title (decision 16).
  ///
  /// In en, this message translates to:
  /// **'Subscribe your commute'**
  String get homePromoTitle;

  /// Home subscribe banner line.
  ///
  /// In en, this message translates to:
  /// **'Save up to 40% with a monthly plan'**
  String get homePromoBody;

  /// Home subscribe banner button.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get homePromoAction;

  /// Title of the sheet asking for location, shown once on Home.
  ///
  /// In en, this message translates to:
  /// **'See rides near you'**
  String get homeLocationPromptTitle;

  /// Body of the location sheet on Home.
  ///
  /// In en, this message translates to:
  /// **'TroSky uses your location to show the nearest stop and the vehicles around you. You can still search for trips without it.'**
  String get homeLocationPromptBody;

  /// Location sheet button; then the phone asks for permission.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get homeLocationAllow;

  /// Location sheet button; Home centres on Accra.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get homeLocationNotNow;

  /// Message when the passenger taps my-location after refusing location for good.
  ///
  /// In en, this message translates to:
  /// **'Location is off for TroSky. Turn it on in Settings.'**
  String get homeLocationBlocked;

  /// Message when the phone's location service is off.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s location is off.'**
  String get homeLocationServiceOff;

  /// Message when the phone gives no position in time.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your location.'**
  String get homeLocationNotFound;

  /// Action that opens the phone settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeOpenSettings;

  /// Title of the Notifications placeholder.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get placeholderNotifications;

  /// Title of the Favourite Routes placeholder (P-14).
  ///
  /// In en, this message translates to:
  /// **'Favourite Routes'**
  String get placeholderFavouriteRoutes;

  /// Title of the Subscribe placeholder (P-10).
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get placeholderSubscribe;

  /// Title of the SOS placeholder (P-15).
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get placeholderSos;

  /// Line on every placeholder screen.
  ///
  /// In en, this message translates to:
  /// **'This screen is coming soon.'**
  String get placeholderSoon;

  /// A price in Ghana cedis.
  ///
  /// In en, this message translates to:
  /// **'₵{amount}'**
  String priceCedis(String amount);

  /// A walking distance under 1 km.
  ///
  /// In en, this message translates to:
  /// **'{metres} m'**
  String distanceMetres(int metres);

  /// A distance of 1 km or more, one decimal.
  ///
  /// In en, this message translates to:
  /// **'{kilometres} km'**
  String distanceKilometres(String kilometres);

  /// Vehicle type on a trip card.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get vehicleBus;

  /// Vehicle type on a trip card (P6).
  ///
  /// In en, this message translates to:
  /// **'Minibus'**
  String get vehicleMinibus;

  /// Vehicle type on a trip card.
  ///
  /// In en, this message translates to:
  /// **'Shuttle'**
  String get vehicleShuttle;

  /// Vehicle type on a trip card (P6 "Saloon Car").
  ///
  /// In en, this message translates to:
  /// **'Saloon Car'**
  String get vehicleSedan;

  /// Vehicle type on a trip card when the type is unknown.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicleOther;

  /// Small label above the title of the Search screen (P-02).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// Title of the Search screen (P-02).
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get searchTitle;

  /// Screen reader label of the From field.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get searchFromLabel;

  /// Screen reader label of the To field.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get searchToLabel;

  /// From value meaning the phone position (decision 19).
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get searchCurrentLocation;

  /// Line under "Current location" in the stop list.
  ///
  /// In en, this message translates to:
  /// **'Board at the nearest stop'**
  String get searchCurrentLocationHint;

  /// From field hint when no pickup is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a pickup stop'**
  String get searchFromHint;

  /// To field hint.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get searchToHint;

  /// Line in the stop list when location can't be used.
  ///
  /// In en, this message translates to:
  /// **'Location is off. Choose a pickup stop.'**
  String get searchLocationOff;

  /// When pill: travel now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get searchWhenNow;

  /// When pill: pick a date and time.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get searchWhenSchedule;

  /// Heading over stop name search results.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get searchStopsHeading;

  /// Stop search with no results.
  ///
  /// In en, this message translates to:
  /// **'No stops match \"{query}\".'**
  String searchNoStops(String query);

  /// Stop search failed; next to Retry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search stops.'**
  String get searchStopsError;

  /// Hint while the stop query is 1 character.
  ///
  /// In en, this message translates to:
  /// **'Type 2 letters or more to search stops.'**
  String get searchTypeMore;

  /// Heading over stops near the passenger.
  ///
  /// In en, this message translates to:
  /// **'Nearby stops'**
  String get searchNearbyHeading;

  /// Heading over the last searches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentHeading;

  /// Heading over favourite route chips on Search.
  ///
  /// In en, this message translates to:
  /// **'Favourite routes'**
  String get searchFavouritesHeading;

  /// Origin name of a recent search made from the current location.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get searchCurrentLocationShort;

  /// Search screen main button.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// How far a nearby stop is.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String searchStopDistance(String distance);

  /// Small label above the journey on Search Results (P6).
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get resultsRouteLabel;

  /// The searched journey on Search Results.
  ///
  /// In en, this message translates to:
  /// **'{origin} → {destination}'**
  String resultsJourney(String origin, String destination);

  /// Banner on Search Results when the API reports approaching vehicles (decision 21).
  ///
  /// In en, this message translates to:
  /// **'Showing vehicles still approaching your stop'**
  String get resultsApproaching;

  /// Banner action: also show vehicles that passed the stop.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get resultsShowAll;

  /// Banner action: hide vehicles that passed the stop.
  ///
  /// In en, this message translates to:
  /// **'Hide passed'**
  String get resultsHidePassed;

  /// Filter pill: departures from now (decision 22).
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get filterNow;

  /// Filter pill: pick a date and time (decision 22).
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get filterSchedule;

  /// Filter pill: sort by price (decision 22).
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get filterCheapest;

  /// Filter pill: sort by arrival time (decision 22).
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get filterFastest;

  /// Filter pill: minibuses only (decision 22).
  ///
  /// In en, this message translates to:
  /// **'Minibus'**
  String get filterMinibus;

  /// Tag on the first bookable card after sorting (decision 22).
  ///
  /// In en, this message translates to:
  /// **'BEST MATCH'**
  String get resultsBestMatch;

  /// Times line on a trip card.
  ///
  /// In en, this message translates to:
  /// **'Departs {departs} · ETA {eta}'**
  String resultsTimes(String departs, String eta);

  /// Times line on a trip card without an arrival time.
  ///
  /// In en, this message translates to:
  /// **'Departs {departs}'**
  String resultsDeparts(String departs);

  /// Free seats chip on a trip card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{count} seats}}'**
  String resultsSeats(int count);

  /// Chip on a trip card with no free seats.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get resultsFull;

  /// Chip on a trip card whose vehicle passed the stop.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get resultsPassed;

  /// Badge on a trip card when the API reports the vehicle's ETA to the stop (decision 21).
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min away · approaching your stop'**
  String resultsApproachingBadge(int minutes);

  /// Badge on a trip card in live mode (decision 21).
  ///
  /// In en, this message translates to:
  /// **'Board at {stop} · {distance} away'**
  String resultsBoardAt(String stop, String distance);

  /// Badge on a trip card without a walking distance.
  ///
  /// In en, this message translates to:
  /// **'Board at {stop}'**
  String resultsBoardAtStop(String stop);

  /// Saving pill on a trip card when the API gives a solo fare (decision 20).
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String resultsSave(int percent);

  /// Strip on a card whose vehicle passed the stop.
  ///
  /// In en, this message translates to:
  /// **'Already passed your stop — unavailable'**
  String get resultsPassedNote;

  /// Dashed button at the end of Search Results.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 vehicle that already passed your stop} other{Show {count} vehicles that already passed your stop}}'**
  String resultsShowPassed(int count);

  /// Search Results with nothing found.
  ///
  /// In en, this message translates to:
  /// **'No vehicles on this route right now'**
  String get resultsEmpty;

  /// Button under the empty results: pick a date and time.
  ///
  /// In en, this message translates to:
  /// **'Try another time'**
  String get resultsTryAnotherTime;

  /// Minibus filter left nothing.
  ///
  /// In en, this message translates to:
  /// **'No minibuses among these trips.'**
  String get resultsNoMinibus;

  /// Button that turns the Minibus filter off.
  ///
  /// In en, this message translates to:
  /// **'Show all vehicles'**
  String get resultsShowAllVehicles;

  /// Loading the next page failed; next to Retry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more trips.'**
  String get resultsLoadMoreError;

  /// NO_PICKUP_NEARBY on Search Results.
  ///
  /// In en, this message translates to:
  /// **'No pickup stop is within walking distance of you.'**
  String get resultsNoPickup;

  /// No position for a Current location search.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your location.'**
  String get resultsNoLocation;

  /// Button back to Search with From to fill in.
  ///
  /// In en, this message translates to:
  /// **'Choose a pickup stop'**
  String get resultsChoosePickup;

  /// Screen reader label of the star in the results header.
  ///
  /// In en, this message translates to:
  /// **'Save this route'**
  String get resultsSaveRoute;

  /// Screen reader label of the filled star.
  ///
  /// In en, this message translates to:
  /// **'Saved to your favourite routes'**
  String get resultsRouteSavedLabel;

  /// Snackbar after saving the route.
  ///
  /// In en, this message translates to:
  /// **'Saved to your favourite routes.'**
  String get resultsRouteSaved;

  /// FAVOURITE_ROUTE_EXISTS, or the star is already filled.
  ///
  /// In en, this message translates to:
  /// **'This route is already in your favourites.'**
  String get resultsRouteExists;

  /// FAVOURITE_ROUTES_LIMIT.
  ///
  /// In en, this message translates to:
  /// **'You can save up to 20 routes. Remove one first.'**
  String get resultsRouteLimit;

  /// Screen reader label of a trip card, before the badge and fare.
  ///
  /// In en, this message translates to:
  /// **'{vehicle} {plate}. {times}. {seats}.'**
  String resultsTripLabel(
    String vehicle,
    String plate,
    String times,
    String seats,
  );

  /// Screen reader: the crossed-out solo price.
  ///
  /// In en, this message translates to:
  /// **'was {price}'**
  String resultsWas(String price);

  /// Screen reader label of the skeleton cards.
  ///
  /// In en, this message translates to:
  /// **'Loading trips'**
  String get resultsLoading;

  /// Seat Selection header title (P7).
  ///
  /// In en, this message translates to:
  /// **'Choose Your Seat'**
  String get seatsTitle;

  /// Seat Selection header line (P7).
  ///
  /// In en, this message translates to:
  /// **'{origin} → {destination} · {plate} · Departs {departs}'**
  String seatsSubtitle(
    String origin,
    String destination,
    String plate,
    String departs,
  );

  /// After the booked count on the counter card (P7), e.g. "5/14 booked".
  ///
  /// In en, this message translates to:
  /// **'/{total} booked'**
  String seatsBookedSuffix(int total);

  /// Screen reader label of the booked counter.
  ///
  /// In en, this message translates to:
  /// **'{booked} of {total} seats booked'**
  String seatsBookedLabel(int booked, int total);

  /// Seat map legend.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get seatsLegendAvailable;

  /// Seat map legend.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get seatsLegendTaken;

  /// Seat map legend.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get seatsLegendSelected;

  /// Screen reader label of a free seat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String seatLabel(String number);

  /// Screen reader label of a taken seat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}, taken'**
  String seatLabelTaken(String number);

  /// Screen reader label of a selected seat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}, selected'**
  String seatLabelSelected(String number);

  /// Group strip on the fare panel (P7).
  ///
  /// In en, this message translates to:
  /// **'1 seat selected'**
  String get seatsOneSelected;

  /// Group strip on the fare panel (P7).
  ///
  /// In en, this message translates to:
  /// **'{count} seats selected (group booking)'**
  String seatsManySelected(int count);

  /// Group strip: the chosen seat numbers.
  ///
  /// In en, this message translates to:
  /// **'Seats: {seats}'**
  String seatsList(String seats);

  /// Group strip: unselect every seat.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get seatsClear;

  /// Fare panel label for one seat (P7).
  ///
  /// In en, this message translates to:
  /// **'You pay now'**
  String get seatsYouPayNow;

  /// Fare panel label for several seats (P7).
  ///
  /// In en, this message translates to:
  /// **'{price} × {count} seats'**
  String seatsPriceTimes(String price, int count);

  /// Fare panel pill (P7, mock mode until G20).
  ///
  /// In en, this message translates to:
  /// **'↓ Drops to {price}'**
  String seatsDropsTo(String price);

  /// Under the "Drops to" pill (P7).
  ///
  /// In en, this message translates to:
  /// **'as more riders join'**
  String get seatsAsMoreJoin;

  /// Screen reader: the crossed-out solo price.
  ///
  /// In en, this message translates to:
  /// **'was {price}'**
  String seatsWas(String price);

  /// Seat Selection button with no seat chosen (P7).
  ///
  /// In en, this message translates to:
  /// **'Select Seats to Continue'**
  String get seatsSelectToContinue;

  /// Seat Selection button for one seat (P7).
  ///
  /// In en, this message translates to:
  /// **'Reserve Seat {number}'**
  String seatsReserveOne(String number);

  /// Seat Selection button for several seats (P7).
  ///
  /// In en, this message translates to:
  /// **'Reserve {count} Seats · {total}'**
  String seatsReserveMany(int count, String total);

  /// Trying to pick more seats than a booking allows.
  ///
  /// In en, this message translates to:
  /// **'You can book up to {max} seats at once.'**
  String seatsMax(int max);

  /// A selected seat was booked by someone else (refresh or SEAT_NOT_AVAILABLE).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Seat {seats} was just taken. Choose another seat.} other{Seats {seats} were just taken. Choose other seats.}}'**
  String seatsJustTaken(int count, String seats);

  /// TRIP_NOT_BOOKABLE.
  ///
  /// In en, this message translates to:
  /// **'This trip can no longer be booked. Choose another one.'**
  String get seatsTripClosed;

  /// Reserving failed with PICKUP_ALREADY_PASSED: the vehicle is on the road and past the boarding stop.
  ///
  /// In en, this message translates to:
  /// **'This vehicle has already passed your pickup. Choose another one.'**
  String get seatsPickupPassed;

  /// Reserving failed with STOP_NOT_ON_ROUTE: the route changed since the search.
  ///
  /// In en, this message translates to:
  /// **'This trip no longer stops where you chose. Choose another one.'**
  String get seatsStopsChanged;

  /// Action after TRIP_NOT_BOOKABLE.
  ///
  /// In en, this message translates to:
  /// **'Back to results'**
  String get seatsBackToResults;

  /// Screen reader label while the seat map loads.
  ///
  /// In en, this message translates to:
  /// **'Loading seats'**
  String get seatsLoading;

  /// The seat map failed to load; next to Retry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the seats.'**
  String get seatsLoadError;

  /// GET /trips/{id}/seats: no vehicle or layout.
  ///
  /// In en, this message translates to:
  /// **'This trip has no vehicle yet, so its seats can\'t be chosen.'**
  String get seatsNoVehicle;

  /// Passenger 1 name when the account has no name (decision 23).
  ///
  /// In en, this message translates to:
  /// **'TroSky passenger'**
  String get bookingPassengerFallback;

  /// Name of each extra passenger (decision 23).
  ///
  /// In en, this message translates to:
  /// **'{firstName}\'s guest {number}'**
  String bookingGuestName(String firstName, int number);

  /// Extra passenger name when the account has no name.
  ///
  /// In en, this message translates to:
  /// **'Guest {number}'**
  String bookingGuestFallback(int number);

  /// Title of Payment (P-07).
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// Subtitle under the Payment title (P-07).
  ///
  /// In en, this message translates to:
  /// **'Review and confirm your booking'**
  String get paymentSubtitle;

  /// Departure day on the Payment trip card.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get paymentToday;

  /// Departure day on the Payment trip card.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get paymentTomorrow;

  /// Label of the vehicle registration on the Payment trip card.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get paymentVehicle;

  /// Joins the last seat number to the others: "B3 & B4", "B3, B4 & B5".
  ///
  /// In en, this message translates to:
  /// **'{seats} & {last}'**
  String paymentSeatsAnd(String seats, String last);

  /// P-07, while the trip's driver hasn't answered the booking.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the driver to accept'**
  String get paymentWaitingTitle;

  /// P-07, under the waiting title.
  ///
  /// In en, this message translates to:
  /// **'Your seats are held. You\'ll pay only after the driver accepts.'**
  String get paymentWaitingBody;

  /// Under the countdown: how long a driver has to answer.
  ///
  /// In en, this message translates to:
  /// **'{minutes}-minute response window'**
  String paymentAnswerWindow(int minutes);

  /// What a screen reader says for the waiting countdown.
  ///
  /// In en, this message translates to:
  /// **'{time} left for the driver to answer'**
  String paymentAnswerTimeLeft(String time);

  /// Cancels the booking while the driver hasn't answered.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get paymentCancelRequest;

  /// Banner after the booking moved because its driver didn't answer in time.
  ///
  /// In en, this message translates to:
  /// **'The driver didn\'t respond, so we moved you to another vehicle.'**
  String get paymentMovedUnanswered;

  /// Banner after the booking moved because its driver declined it.
  ///
  /// In en, this message translates to:
  /// **'The driver couldn\'t take your booking, so we moved you to another vehicle.'**
  String get paymentMovedDeclined;

  /// Tag on the trip card after a move (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'New vehicle assigned'**
  String get paymentNewVehicle;

  /// P-07, after a move, while the new driver hasn't answered.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the new driver to accept'**
  String get paymentNewDriverTitle;

  /// P-07, under the new-driver title.
  ///
  /// In en, this message translates to:
  /// **'Your seats are held while the new driver reviews your booking.'**
  String get paymentNewDriverBody;

  /// Banner once the driver accepted the booking.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted your booking'**
  String get paymentAccepted;

  /// Before the time left to pay, once the driver accepted.
  ///
  /// In en, this message translates to:
  /// **'Pay within'**
  String get paymentPayWithin;

  /// P-07 when the booking ended without a driver accepting it.
  ///
  /// In en, this message translates to:
  /// **'No driver accepted your booking'**
  String get paymentNotAcceptedTitle;

  /// Under the not-accepted title.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t been charged. Your seats have been released.'**
  String get paymentNotAcceptedBody;

  /// Opens Search with the same stops, after no driver accepted.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get paymentSearchAgain;

  /// Goes to Home, after no driver accepted.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get paymentBackHome;

  /// On Payment when it can't reach the server while waiting for the driver.
  ///
  /// In en, this message translates to:
  /// **'No connection. We\'ll keep checking.'**
  String get paymentOffline;

  /// Row label on Payment.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get paymentSeats;

  /// Row label on Payment.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get paymentTotal;

  /// Note on Payment once the driver accepted, until paying in the app is built.
  ///
  /// In en, this message translates to:
  /// **'Paying in the app is coming soon. Your seats stay held until the timer ends.'**
  String get paymentComingSoon;

  /// Cancels the booking and frees the seats (P-07: moved, and accepted).
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get paymentCancel;

  /// After cancelling.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled. Your seats are free again.'**
  String get paymentCancelled;

  /// Title of the sheet shown when going back from Payment to Seat Selection.
  ///
  /// In en, this message translates to:
  /// **'Change your seats?'**
  String get paymentReleaseTitle;

  /// Body of the sheet shown when going back from Payment to Seat Selection.
  ///
  /// In en, this message translates to:
  /// **'Going back releases the seats held for you, so you can choose again.'**
  String get paymentReleaseBody;

  /// Stays on Payment with the seats still held.
  ///
  /// In en, this message translates to:
  /// **'Keep these seats'**
  String get paymentReleaseKeep;

  /// Cancels the held booking and goes back to Seat Selection.
  ///
  /// In en, this message translates to:
  /// **'Release seats'**
  String get paymentReleaseConfirm;

  /// After the held seats were released by going back.
  ///
  /// In en, this message translates to:
  /// **'Seats released. Choose again.'**
  String get paymentReleased;

  /// When the time to pay runs out.
  ///
  /// In en, this message translates to:
  /// **'Your seat hold has expired. Choose your seats again.'**
  String get paymentExpired;

  /// When a reopened booking's time to pay runs out.
  ///
  /// In en, this message translates to:
  /// **'Your seat hold has expired.'**
  String get paymentExpiredHome;
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
