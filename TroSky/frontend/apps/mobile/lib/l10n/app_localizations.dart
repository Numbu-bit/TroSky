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

  /// Instead of offlineBanner when the phone has internet but the server didn't answer within 2 minutes (decision 29).
  ///
  /// In en, this message translates to:
  /// **'The server isn\'t answering. Showing your last saved details.'**
  String get serverUnreachableBanner;

  /// Bar across the top of every screen while the app waits for the server to answer: the test server sleeps when unused (decision 29).
  ///
  /// In en, this message translates to:
  /// **'Waking up the server… usually under a minute'**
  String get serverWaking;

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

  /// Search Results late in the day: today's trips are all past, tomorrow's load underneath.
  ///
  /// In en, this message translates to:
  /// **'No more trips today'**
  String get resultsNoMoreToday;

  /// Subline under the 'No more trips today' headline.
  ///
  /// In en, this message translates to:
  /// **'Showing tomorrow\'s first trips instead'**
  String get resultsNoMoreTodaySubline;

  /// Chip above tomorrow's first trips when today has none left. 'date' is a short weekday + day + month in the device locale.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow · {date}'**
  String resultsTomorrowChip(String date);

  /// Screen-reader label for the Tomorrow date chip.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s trips, {date}'**
  String resultsTomorrowSemantics(String date);

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

  /// Leave-payment sheet: releases the held seats and goes back to choose again.
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

  /// Trip History header (P-15, Figma P13).
  ///
  /// In en, this message translates to:
  /// **'Trip History'**
  String get tripsTitle;

  /// Trip History summary card title, as designed (P13).
  ///
  /// In en, this message translates to:
  /// **'Total Spent This Month'**
  String get tripsSpentThisMonth;

  /// Trip History summary card: paid trips this month.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsStatTrips;

  /// Trip History summary card: average fare this month.
  ///
  /// In en, this message translates to:
  /// **'Avg Fare'**
  String get tripsStatAvgFare;

  /// Trip History summary card: what sharing saved this month.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get tripsStatSaved;

  /// Trip History tab: bookings still to ride (instead of the design's All / This Month / Last Month).
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tripsTabUpcoming;

  /// Trip History tab: bookings that ended.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tripsTabPast;

  /// Day of a past booking on a Trip History row.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get tripsYesterday;

  /// When a Trip History row's trip departs: "Today, 08:30", "Mon, 07:45".
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String tripsWhen(String day, String time);

  /// Screen reader label for Trip History while it loads.
  ///
  /// In en, this message translates to:
  /// **'Loading your trips'**
  String get tripsLoading;

  /// Trip History, Upcoming tab, with no bookings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming trips. Book a seat and it shows up here.'**
  String get tripsEmptyUpcoming;

  /// Trip History, Past tab, with no bookings.
  ///
  /// In en, this message translates to:
  /// **'No past trips yet.'**
  String get tripsEmptyPast;

  /// Button under an empty Trip History tab: opens Search.
  ///
  /// In en, this message translates to:
  /// **'Find a ride'**
  String get tripsFindRide;

  /// Under the Trip History list when the next page fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more trips.'**
  String get tripsLoadMoreError;

  /// Screen reader hint on a Trip History row.
  ///
  /// In en, this message translates to:
  /// **'Opens the booking details'**
  String get tripsOpenLabel;

  /// Booking status: awaiting_acceptance.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get bookingStatusWaiting;

  /// Booking status: pending or payment_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending payment'**
  String get bookingStatusPendingPayment;

  /// Booking status: confirmed, the trip not started.
  ///
  /// In en, this message translates to:
  /// **'Paid · Upcoming'**
  String get bookingStatusPaidUpcoming;

  /// Booking status: confirmed, the trip boarding or under way (not in the design).
  ///
  /// In en, this message translates to:
  /// **'Paid · On the way'**
  String get bookingStatusPaidUnderWay;

  /// Booking status: completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStatusCompleted;

  /// Booking status: cancelled, refund_pending or refunded.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingStatusCancelled;

  /// Booking status: expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bookingStatusExpired;

  /// Booking details header (P-16).
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get bookingDetailsTitle;

  /// Screen reader label for the copy button by the booking reference.
  ///
  /// In en, this message translates to:
  /// **'Copy booking reference'**
  String get bookingCopyReference;

  /// After the booking reference was copied.
  ///
  /// In en, this message translates to:
  /// **'Booking reference copied'**
  String get bookingReferenceCopied;

  /// How long the ride takes, on the trip card.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String bookingAboutMinutes(int minutes);

  /// Estimated arrival time on the trip card.
  ///
  /// In en, this message translates to:
  /// **'~{time}'**
  String bookingArrival(String time);

  /// Booking details card title.
  ///
  /// In en, this message translates to:
  /// **'Vehicle & driver'**
  String get bookingVehicleDriver;

  /// Booking details: the booked seats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get bookingSeats;

  /// Booking details: how many seats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 passenger} other{{count} passengers}}'**
  String bookingPassengers(int count);

  /// Screen reader label for the driver's rating.
  ///
  /// In en, this message translates to:
  /// **'Rated {rating} out of 5'**
  String bookingDriverRated(String rating);

  /// Booking details card title.
  ///
  /// In en, this message translates to:
  /// **'Fare breakdown'**
  String get bookingFareBreakdown;

  /// Fare breakdown: seats times the fare of one.
  ///
  /// In en, this message translates to:
  /// **'{count} × {fare}'**
  String bookingFareLine(int count, String fare);

  /// Fare breakdown: the platform fee (not in the design; the backend charges it).
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get bookingServiceFee;

  /// Booking details action for a booking to pay: opens Payment.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get bookingPayNow;

  /// Booking details action while the driver hasn't answered: opens Payment.
  ///
  /// In en, this message translates to:
  /// **'View status'**
  String get bookingViewStatus;

  /// Booking details: a refund paid out (back the way it was paid).
  ///
  /// In en, this message translates to:
  /// **'{amount} refunded'**
  String bookingRefunded(String amount);

  /// Booking details: a refund waiting for TroSky's approval.
  ///
  /// In en, this message translates to:
  /// **'Refund of {amount} requested'**
  String bookingRefundRequested(String amount);

  /// Booking details when it fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this booking.'**
  String get bookingLoadError;

  /// Cancel sheet title.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get cancelSheetTitle;

  /// Cancel sheet subtitle.
  ///
  /// In en, this message translates to:
  /// **'Please tell us why you\'re cancelling.'**
  String get cancelSheetSubtitle;

  /// Cancel reason.
  ///
  /// In en, this message translates to:
  /// **'Change of plans'**
  String get cancelReasonPlans;

  /// Cancel reason.
  ///
  /// In en, this message translates to:
  /// **'Found another ride'**
  String get cancelReasonAnotherRide;

  /// Cancel reason.
  ///
  /// In en, this message translates to:
  /// **'Departure time doesn\'t suit me'**
  String get cancelReasonTime;

  /// Cancel reason.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancelReasonOther;

  /// Booking details, status line before the reason.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get bookingCancelledByYou;

  /// Booking details, status line before the reason when TroSky cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by TroSky'**
  String get bookingCancelledByTroSky;

  /// Booking details status line with a reason, e.g. 'Cancelled by you · Change of plans'.
  ///
  /// In en, this message translates to:
  /// **'{by} · {reason}'**
  String bookingCancelledLine(String by, String reason);

  /// Booking details line for an expired (unpaid) booking.
  ///
  /// In en, this message translates to:
  /// **'Expired · Not paid in time'**
  String get bookingExpiredLine;

  /// Cancel sheet refund box for a paid booking (the design names the wallet; the backend refunds the way it was paid).
  ///
  /// In en, this message translates to:
  /// **'Refund: {amount}'**
  String cancelRefundTitle(String amount);

  /// Cancel sheet refund box: how refunds work.
  ///
  /// In en, this message translates to:
  /// **'TroSky approves the refund, then it goes back the way you paid.'**
  String get cancelRefundBody;

  /// Cancel sheet note when the trip is under way.
  ///
  /// In en, this message translates to:
  /// **'Your trip has started'**
  String get cancelReviewTitle;

  /// Cancel sheet note when the trip is under way.
  ///
  /// In en, this message translates to:
  /// **'TroSky reviews cancellations once a trip is under way.'**
  String get cancelReviewBody;

  /// Cancel sheet: the red button.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelConfirm;

  /// Cancel sheet: closes it.
  ///
  /// In en, this message translates to:
  /// **'Keep booking'**
  String get cancelKeep;

  /// Title after cancelling.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get cancelledTitle;

  /// Line after cancelling.
  ///
  /// In en, this message translates to:
  /// **'Your seats have been released.'**
  String get cancelledBody;

  /// Button after cancelling: back to Trip History.
  ///
  /// In en, this message translates to:
  /// **'Back to trips'**
  String get cancelledBackToTrips;

  /// Title when the cancel waits for TroSky (the trip had started; not in the design).
  ///
  /// In en, this message translates to:
  /// **'Cancellation requested'**
  String get cancelRequestedTitle;

  /// Line when the cancel waits for TroSky.
  ///
  /// In en, this message translates to:
  /// **'Your trip has already started, so TroSky reviews it. Your booking stays as it is until then.'**
  String get cancelRequestedBody;

  /// Sheet when leaving Payment while seats are held (decision 31).
  ///
  /// In en, this message translates to:
  /// **'Leave payment?'**
  String get paymentLeaveTitle;

  /// Leave-payment sheet: how long the seats stay held (minutes:seconds).
  ///
  /// In en, this message translates to:
  /// **'Your seats stay held for {time}. You can pay from Trips.'**
  String paymentLeaveBody(String time);

  /// Leave-payment sheet: goes to Home; the seats stay held.
  ///
  /// In en, this message translates to:
  /// **'Keep seats & leave'**
  String get paymentLeaveKeep;

  /// Home card for a booking to pay: the time left to pay (minutes:seconds).
  ///
  /// In en, this message translates to:
  /// **'Seats held · {time} left'**
  String homeHeldSeats(String time);

  /// Payment (P-07): label over the chosen payment method; shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payWithLabel;

  /// The TroSky Wallet as a way to pay.
  ///
  /// In en, this message translates to:
  /// **'TroSky Wallet'**
  String get payWallet;

  /// The wallet's balance under its name.
  ///
  /// In en, this message translates to:
  /// **'Balance {amount}'**
  String payWalletBalance(String amount);

  /// The wallet's balance couldn't be read (the server still checks it when paying).
  ///
  /// In en, this message translates to:
  /// **'Balance unavailable'**
  String get payWalletBalanceUnknown;

  /// Payment card: the chosen wallet holds less than the booking's total.
  ///
  /// In en, this message translates to:
  /// **'Balance {amount} · not enough'**
  String payWalletNotEnough(String amount);

  /// MTN Mobile Money as a way to pay.
  ///
  /// In en, this message translates to:
  /// **'MTN MoMo'**
  String get payMomo;

  /// Payment card: opens the list of ways to pay.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get payChange;

  /// Payment's main button.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payButton(String amount);

  /// Title of the sheet for choosing how to pay.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payMethodSheetTitle;

  /// Under the title of the payment method sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose how to pay {amount}.'**
  String payMethodSheetSubtitle(String amount);

  /// Payment method sheet: why the wallet can't be chosen.
  ///
  /// In en, this message translates to:
  /// **'Not enough for {amount}'**
  String payMethodNotEnough(String amount);

  /// Payment method sheet: shows the field for a new mobile money number.
  ///
  /// In en, this message translates to:
  /// **'+ Add an MTN MoMo number'**
  String get payAddNumber;

  /// Payment method sheet: saves the number typed and pays with it.
  ///
  /// In en, this message translates to:
  /// **'Use this number'**
  String get payAddNumberSave;

  /// Payment method sheet: the number typed isn't a valid Ghana mobile number.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid MTN MoMo number, like 024 123 4567.'**
  String get payNumberInvalid;

  /// Approve on your phone (P-08): title while MTN MoMo waits for the payer.
  ///
  /// In en, this message translates to:
  /// **'Approve on your phone'**
  String get payApproveTitle;

  /// Approve on your phone (P-08).
  ///
  /// In en, this message translates to:
  /// **'We sent a request for {amount} to {number}. Enter your MoMo PIN in the prompt to pay.'**
  String payApproveBody(String amount, String number);

  /// Approve on your phone (P-08), reopened later: the number isn't known.
  ///
  /// In en, this message translates to:
  /// **'We sent a request for {amount} to your MTN MoMo number. Enter your MoMo PIN in the prompt to pay.'**
  String payApproveBodyNoNumber(String amount);

  /// Approve on your phone (P-08): under the countdown to the end of the seat hold.
  ///
  /// In en, this message translates to:
  /// **'left to approve'**
  String get payApproveCaption;

  /// Approve on your phone (P-08): the countdown for screen readers.
  ///
  /// In en, this message translates to:
  /// **'{time} left to approve the payment'**
  String payApproveTimeLeft(String time);

  /// Approve on your phone (P-08): opens help when no MoMo prompt came.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t get a prompt'**
  String get payNoPrompt;

  /// Sheet from "I didn't get a prompt".
  ///
  /// In en, this message translates to:
  /// **'No prompt yet?'**
  String get payNoPromptTitle;

  /// Sheet from "I didn't get a prompt". The payment can't be stopped while MTN waits (backend gap G36).
  ///
  /// In en, this message translates to:
  /// **'MTN can take a minute to send it. Check that your phone is on and has signal. You can also dial *170#, then My Wallet, then My Approvals. If no prompt comes, the payment fails on its own, and then you can try again or pay another way.'**
  String get payNoPromptBody;

  /// Asks now whether the MoMo payment went through.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get payCheckAgain;

  /// Closes the no-prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get payKeepWaiting;

  /// Payment result (P-09): paid.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paySuccessTitle;

  /// Payment result (P-09): paid from the wallet.
  ///
  /// In en, this message translates to:
  /// **'{amount} paid from your TroSky Wallet. Your seats are booked.'**
  String paySuccessWallet(String amount);

  /// Payment result (P-09): paid by mobile money.
  ///
  /// In en, this message translates to:
  /// **'{amount} paid with MTN MoMo. Your seats are booked.'**
  String paySuccessMomo(String amount);

  /// Payment result (P-09): label over the booking reference.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get payReferenceLabel;

  /// Payment result (P-09): opens the Trips tab.
  ///
  /// In en, this message translates to:
  /// **'Go to Trips'**
  String get payGoToTrips;

  /// Payment result (P-09): not paid.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get payFailedTitle;

  /// Payment result (P-09): MTN reports the payer declined.
  ///
  /// In en, this message translates to:
  /// **'The payment was declined on your phone.'**
  String get payFailedDeclined;

  /// Payment result (P-09): the wallet balance was too low.
  ///
  /// In en, this message translates to:
  /// **'Your TroSky Wallet doesn\'t hold {amount}.'**
  String payFailedWallet(String amount);

  /// Payment result (P-09): any other failure.
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through.'**
  String get payFailedGeneric;

  /// Payment result (P-09): after a failure, while the hold lasts.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t been charged. Your seats are held for {time}.'**
  String payFailedHeld(String time);

  /// Payment result (P-09): pays again the same way.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get payTryAgain;

  /// Payment result (P-09): back to Payment to choose another way to pay.
  ///
  /// In en, this message translates to:
  /// **'Change method'**
  String get payChangeMethod;

  /// Payment result (P-09): the seat hold ended before the payment was approved.
  ///
  /// In en, this message translates to:
  /// **'Time ran out'**
  String get payTimedOutTitle;

  /// Payment result (P-09): hold over, payment unanswered.
  ///
  /// In en, this message translates to:
  /// **'Your seats were released because the payment wasn\'t approved in time. If it still goes through, TroSky refunds it.'**
  String get payTimedOutBody;

  /// Payment result (P-09): approved after the hold ended.
  ///
  /// In en, this message translates to:
  /// **'The payment came through after your seats were released, so TroSky refunds {amount}.'**
  String payLateBody(String amount);

  /// Cancel sheet (P-16): refund of a booking paid from the wallet.
  ///
  /// In en, this message translates to:
  /// **'Once TroSky approves the refund, it goes back to your TroSky Wallet.'**
  String get cancelRefundBodyWallet;

  /// Cancel sheet (P-16): refund of a booking paid by MTN MoMo (MTN has no refund API; the team pays it out).
  ///
  /// In en, this message translates to:
  /// **'Once TroSky approves the refund, our team sends it back to your MTN MoMo number or your TroSky Wallet.'**
  String get cancelRefundBodyMomo;

  /// Payment result (P-09): MTN reports the prompt expired unanswered.
  ///
  /// In en, this message translates to:
  /// **'The prompt on your phone timed out.'**
  String get payFailedExpired;

  /// Payment result (P-09): MTN reports not enough funds.
  ///
  /// In en, this message translates to:
  /// **'Your MTN MoMo balance was too low.'**
  String get payFailedMomoFunds;

  /// Hidden tester menu title (staging and demo builds).
  ///
  /// In en, this message translates to:
  /// **'Tester menu'**
  String get testerMenuTitle;

  /// Subline in the tester menu header, describing where the 7-tap trigger lives.
  ///
  /// In en, this message translates to:
  /// **'Triggered from Home · tap greeting 7×'**
  String get testerMenuTriggerNote;

  /// Tester menu section header for the read-only build info block.
  ///
  /// In en, this message translates to:
  /// **'Build info'**
  String get testerMenuBuildInfo;

  /// Tester menu build-info row label.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get testerMenuCommit;

  /// Tester menu build-info row label.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get testerMenuBuilt;

  /// Tester menu build-info row label.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get testerMenuApiBase;

  /// Tester menu build-info row label.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get testerMenuMode;

  /// Tester menu build-info row label.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get testerMenuAppVersion;

  /// Tester menu build-info mode value.
  ///
  /// In en, this message translates to:
  /// **'mock'**
  String get testerMenuModeMock;

  /// Tester menu build-info mode value for live API (always staging in the hidden menu).
  ///
  /// In en, this message translates to:
  /// **'staging'**
  String get testerMenuModeLive;

  /// Tester menu build-info value when GIT_COMMIT or BUILD_DATE weren't passed at build time.
  ///
  /// In en, this message translates to:
  /// **'unset'**
  String get testerMenuNotSet;

  /// Tester menu action button.
  ///
  /// In en, this message translates to:
  /// **'Wake server'**
  String get testerMenuWakeServer;

  /// Toast after a successful Wake server tap.
  ///
  /// In en, this message translates to:
  /// **'Server is awake'**
  String get testerMenuWakeOk;

  /// Toast after a failed Wake server tap.
  ///
  /// In en, this message translates to:
  /// **'Server didn\'t answer'**
  String get testerMenuWakeFail;

  /// Toast when Wake server runs in a mock-mode build.
  ///
  /// In en, this message translates to:
  /// **'This is a mock build; no server to wake'**
  String get testerMenuWakeMockMode;

  /// Tester menu action button.
  ///
  /// In en, this message translates to:
  /// **'Top up my wallet ₵100'**
  String get testerMenuTopUp;

  /// Toast after a successful wallet top-up.
  ///
  /// In en, this message translates to:
  /// **'Wallet topped up. New balance: ₵{balance}'**
  String testerMenuTopUpOk(String balance);

  /// Toast when the wallet-top-up endpoint returns 404.
  ///
  /// In en, this message translates to:
  /// **'Wallet top-up not supported by this backend (PR #53 not deployed).'**
  String get testerMenuTopUpMissing;

  /// Toast when the wallet-top-up endpoint errored.
  ///
  /// In en, this message translates to:
  /// **'Top-up failed: {message}'**
  String testerMenuTopUpError(String message);

  /// Toast when Top up is tapped without a signed-in session.
  ///
  /// In en, this message translates to:
  /// **'Sign in first to top up your wallet'**
  String get testerMenuTopUpSignIn;

  /// Tester menu action button.
  ///
  /// In en, this message translates to:
  /// **'Show onboarding again'**
  String get testerMenuShowOnboarding;

  /// Tester menu action button (destructive).
  ///
  /// In en, this message translates to:
  /// **'Sign out & clear data'**
  String get testerMenuSignOut;

  /// Overline above the route headline on the Ticket screen.
  ///
  /// In en, this message translates to:
  /// **'BOARDING PASS'**
  String get ticketBoardingPass;

  /// Route headline on the Ticket screen (P-10).
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String ticketRouteHeadline(String from, String to);

  /// Subline under the QR.
  ///
  /// In en, this message translates to:
  /// **'Scan this code when boarding'**
  String get ticketScanSubline;

  /// Ticket status pill label.
  ///
  /// In en, this message translates to:
  /// **'Not yet valid'**
  String get ticketPillNotYetValid;

  /// Ticket status pill label.
  ///
  /// In en, this message translates to:
  /// **'Ready to Board'**
  String get ticketPillReadyToBoard;

  /// Ticket status pill once validated.
  ///
  /// In en, this message translates to:
  /// **'Used · {time}'**
  String ticketPillUsed(String time);

  /// Ticket status pill label.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get ticketPillExpired;

  /// Ticket status pill label for revoked tickets.
  ///
  /// In en, this message translates to:
  /// **'Not valid'**
  String get ticketPillNotValid;

  /// Three-column strip label.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get ticketSeat;

  /// Three-column strip label.
  ///
  /// In en, this message translates to:
  /// **'Departs'**
  String get ticketDeparts;

  /// Three-column strip label.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get ticketFare;

  /// Payment pill on the passenger card.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get ticketPaid;

  /// Passenger verification sub-line (P-10).
  ///
  /// In en, this message translates to:
  /// **'Verified · Ghana Card'**
  String get ticketVerifiedGhanaCard;

  /// Expander button under the QR.
  ///
  /// In en, this message translates to:
  /// **'Can\'t scan? Show code'**
  String get ticketCantScan;

  /// Ticket page indicator for bookings with more than 3 seats.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String ticketCountOf(int current, int total);

  /// Semantics label on the QR image.
  ///
  /// In en, this message translates to:
  /// **'Boarding QR for {route} at {time}, seat {seat}'**
  String ticketSemanticLabel(String route, String time, String seat);

  /// Semantics label on the ticket page dots.
  ///
  /// In en, this message translates to:
  /// **'Ticket {current} of {total}'**
  String ticketPageDotsLabel(int current, int total);

  /// Retry button on the ticket error state.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ticketRetry;

  /// Save-to-photos button on the Ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get ticketSave;

  /// Share button on the Ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get ticketShare;

  /// Full-screen offline state title: no cache, no network.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load ticket'**
  String get ticketOfflineTitle;

  /// Full-screen offline state subline.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to sync'**
  String get ticketOfflineSubline;

  /// Top banner when the ticket is loaded from cache after a failed refresh.
  ///
  /// In en, this message translates to:
  /// **'Showing last synced ticket'**
  String get ticketOfflineBanner;

  /// Error state when the tickets fetch failed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load your ticket. Pull down to retry.'**
  String get ticketError;

  /// State for bookings with no tickets issued yet (e.g. awaiting acceptance).
  ///
  /// In en, this message translates to:
  /// **'No ticket yet. It appears after the booking is confirmed.'**
  String get ticketEmpty;

  /// Primary action on booking details that opens the Ticket screen.
  ///
  /// In en, this message translates to:
  /// **'Show ticket'**
  String get bookingShowTicket;

  /// Link on booking details that opens the P-04 Trip Details screen.
  ///
  /// In en, this message translates to:
  /// **'View trip details'**
  String get bookingViewTripDetails;

  /// App-bar title on P-04.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetailsTitle;

  /// Trip status pill.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tripDetailsStatusUpcoming;

  /// Trip status pill.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get tripDetailsStatusOnTheWay;

  /// Trip status pill.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get tripDetailsStatusArrived;

  /// Trip status pill.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripDetailsStatusCancelled;

  /// Section header on P-04.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tripDetailsSchedule;

  /// Section header on P-04.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get tripDetailsStops;

  /// Section header on P-04.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get tripDetailsVehicle;

  /// Section header on P-04.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get tripDetailsDriver;

  /// Section header on P-04.
  ///
  /// In en, this message translates to:
  /// **'Your seats'**
  String get tripDetailsYourSeats;

  /// Schedule row label.
  ///
  /// In en, this message translates to:
  /// **'Departs'**
  String get tripDetailsDeparts;

  /// Schedule row label.
  ///
  /// In en, this message translates to:
  /// **'Arrives'**
  String get tripDetailsArrives;

  /// Schedule row label.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get tripDetailsDuration;

  /// Vehicle row label.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get tripDetailsPlate;

  /// Driver rating with count, e.g. '4.8 (112)'.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count})'**
  String tripDetailsDriverRating(String rating, int count);

  /// Driver row when average_rating is null.
  ///
  /// In en, this message translates to:
  /// **'Not rated yet'**
  String get tripDetailsDriverUnrated;

  /// Shown in place of Call/Message when driver_phone is missing.
  ///
  /// In en, this message translates to:
  /// **'Driver contact unavailable'**
  String get tripDetailsDriverContactUnavailable;

  /// Semantics label on the call icon button.
  ///
  /// In en, this message translates to:
  /// **'Call driver'**
  String get tripDetailsCallDriver;

  /// Semantics label on the message icon button.
  ///
  /// In en, this message translates to:
  /// **'Message driver'**
  String get tripDetailsMessageDriver;

  /// Primary CTA; step17/B wires the real screen.
  ///
  /// In en, this message translates to:
  /// **'Track trip'**
  String get tripDetailsTrackTrip;

  /// Snackbar for the Track trip stub.
  ///
  /// In en, this message translates to:
  /// **'Live tracking coming in the next release'**
  String get tripDetailsTrackComingSoon;

  /// Secondary ghost CTA on P-04.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get tripDetailsCancelBooking;

  /// Shown when the trip id 404s.
  ///
  /// In en, this message translates to:
  /// **'This booking wasn\'t found.'**
  String get tripDetailsNotFound;

  /// Shown when offline with no cached booking to fall back on.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load trip details — reconnect'**
  String get tripDetailsOffline;

  /// Generic error state.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get tripDetailsServerError;

  /// One row of the Your seats card.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat} · {name}'**
  String tripDetailsSeatRow(String seat, String name);

  /// Chip next to the passenger's boarding stop in the Stops card.
  ///
  /// In en, this message translates to:
  /// **'Boarding here'**
  String get tripDetailsStopBoardingTag;

  /// Chip next to the passenger's alighting stop in the Stops card.
  ///
  /// In en, this message translates to:
  /// **'Getting off'**
  String get tripDetailsStopAlightingTag;

  /// Pill under the driver's name when verification_status == verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get tripDetailsDriverVerified;

  /// Pill under the driver's name when verification_status == pending.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get tripDetailsDriverVerificationPending;

  /// Screen-reader label for the Verified pill.
  ///
  /// In en, this message translates to:
  /// **'Driver verification status: Verified'**
  String get tripDetailsDriverVerifiedSemantics;

  /// Screen-reader label for the Verification-pending pill.
  ///
  /// In en, this message translates to:
  /// **'Driver verification pending'**
  String get tripDetailsDriverVerificationPendingSemantics;

  /// Screen-reader label on each stop row of the Stops card.
  ///
  /// In en, this message translates to:
  /// **'Stop {current} of {total}, {name}, {kind}'**
  String tripDetailsStopSemantics(
    int current,
    int total,
    String name,
    String kind,
  );

  /// Stop kind announced by the screen reader.
  ///
  /// In en, this message translates to:
  /// **'boarding'**
  String get tripDetailsStopBoardingSemantic;

  /// Stop kind announced by the screen reader.
  ///
  /// In en, this message translates to:
  /// **'regular'**
  String get tripDetailsStopRegularSemantic;

  /// P-11 amber chip when the trip hasn't started.
  ///
  /// In en, this message translates to:
  /// **'Boarding at origin'**
  String get trackTripStatusBoardingAtOrigin;

  /// P-11 amber chip when the trip is on the way.
  ///
  /// In en, this message translates to:
  /// **'Arriving in ~{minutes} min'**
  String trackTripStatusArrivingIn(int minutes);

  /// P-11 amber chip when within 100 m.
  ///
  /// In en, this message translates to:
  /// **'At your stop'**
  String get trackTripStatusAtYourStop;

  /// P-11 amber chip once the trip finishes.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get trackTripStatusCompleted;

  /// Clock-time half of the amber chip.
  ///
  /// In en, this message translates to:
  /// **'ETA {time}'**
  String trackTripEta(String time);

  /// Pin label on the destination stop.
  ///
  /// In en, this message translates to:
  /// **'DESTINATION'**
  String get trackTripDestination;

  /// P-11 info tile label.
  ///
  /// In en, this message translates to:
  /// **'Live fare'**
  String get trackTripLiveFare;

  /// P-11 info tile label.
  ///
  /// In en, this message translates to:
  /// **'Riders'**
  String get trackTripRiders;

  /// P-11 info tile label.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get trackTripSeat;

  /// Ghost CTA at the bottom of P-11.
  ///
  /// In en, this message translates to:
  /// **'Share Trip'**
  String get trackTripShare;

  /// Red CTA at the bottom of P-11.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get trackTripSos;

  /// Semantics label on the recentre FAB.
  ///
  /// In en, this message translates to:
  /// **'Recentre map'**
  String get trackTripRecenter;

  /// Riders tile value.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String trackTripRidersOf(int current, int total);

  /// Seat tile value.
  ///
  /// In en, this message translates to:
  /// **'#{seat}'**
  String trackTripSeatValue(String seat);

  /// Text template for Share Trip (no coords, no token).
  ///
  /// In en, this message translates to:
  /// **'Tracking my trotro: {route} · ETA {time} · Seat {seat} · {plate}'**
  String trackTripShareText(
    String route,
    String time,
    String seat,
    String plate,
  );

  /// Thin banner when the WS dropped and the service fell back to polling.
  ///
  /// In en, this message translates to:
  /// **'Realtime offline, polling every 5 s'**
  String get trackTripFallbackBanner;

  /// Title of the SOS placeholder sheet.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get trackTripSosTitle;

  /// Body copy of the SOS placeholder sheet.
  ///
  /// In en, this message translates to:
  /// **'Full emergency features land in Step 19. If you are in danger, call 191 (Ghana Police).'**
  String get trackTripSosBody;

  /// Call-191 tertiary button in the SOS sheet.
  ///
  /// In en, this message translates to:
  /// **'Call 191'**
  String get trackTripSosCall;

  /// Semantics summary for the map.
  ///
  /// In en, this message translates to:
  /// **'Live tracking map, bus is {minutes} minutes away'**
  String trackTripSemanticsMap(int minutes);

  /// P-17 header.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// P-17 card title.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get walletPaymentMethodsTitle;

  /// P-17 card title.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get walletRecentTransactions;

  /// P-17 expand link.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get walletSeeAll;

  /// P-17 collapse link.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get walletSeeLess;

  /// P-17 add link.
  ///
  /// In en, this message translates to:
  /// **'+ Add method'**
  String get walletAddMethod;

  /// Add-method sheet title.
  ///
  /// In en, this message translates to:
  /// **'Add a payment method'**
  String get walletAddMethodTitle;

  /// Default-method pill.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get walletDefault;

  /// Method sheet action.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get walletSetAsDefault;

  /// Method sheet destructive action.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get walletRemoveMethod;

  /// Disabled picker row hint.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get walletComingSoon;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'MTN MoMo'**
  String get walletBrandMtnMomo;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'Telecel Cash'**
  String get walletBrandTelecelCash;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'AirtelTigo Money'**
  String get walletBrandAirteltigo;

  /// Brand name.
  ///
  /// In en, this message translates to:
  /// **'Visa Debit'**
  String get walletBrandVisa;

  /// Brand name (in-app wallet).
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletBrandWallet;

  /// Empty methods state.
  ///
  /// In en, this message translates to:
  /// **'You have no saved payment methods.'**
  String get walletNoPaymentMethods;

  /// First-time user transactions empty state.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Top up to get started.'**
  String get walletTransactionsEmpty;

  /// Filter chip.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletFilterAll;

  /// Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Top-ups'**
  String get walletFilterTopUps;

  /// Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get walletFilterTrips;

  /// Filter chip.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get walletFilterRefunds;

  /// Filter empty state.
  ///
  /// In en, this message translates to:
  /// **'No transactions match this filter.'**
  String get walletNoMatches;

  /// Card error message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load.'**
  String get walletErrorLoad;

  /// Retry action.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get walletRetry;

  /// Accessibility fragment for a payment method.
  ///
  /// In en, this message translates to:
  /// **'ending in {last4}'**
  String walletEndingIn(String last4);

  /// Add MoMo form title.
  ///
  /// In en, this message translates to:
  /// **'Enter your MoMo number'**
  String get walletMomoFormTitle;

  /// Phone field label.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get walletMomoFormPhoneLabel;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletKindTopUp;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get walletKindTrip;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get walletKindRefund;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Earning'**
  String get walletKindEarning;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get walletKindWithdrawal;

  /// Transaction kind label.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get walletKindAdjustment;

  /// Reference id label on the detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get walletTxnReference;

  /// Link into trip details.
  ///
  /// In en, this message translates to:
  /// **'View trip'**
  String get walletViewTrip;

  /// P-18 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletTopUpTitle;

  /// P-18 section title.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get walletTopUpAmount;

  /// P-18 custom amount field label.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get walletTopUpCustomAmount;

  /// Invalid amount error.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount between ₵1 and ₵1,000.'**
  String get walletTopUpAmountError;

  /// Fallback amount text on the CTA label while the input is empty.
  ///
  /// In en, this message translates to:
  /// **'₵0.00'**
  String get walletTopUpAmountFallback;

  /// P-18 primary button.
  ///
  /// In en, this message translates to:
  /// **'Top up {amount}'**
  String walletTopUpCta(String amount);

  /// P-18 pending status row.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MoMo confirmation…'**
  String get walletTopUpWaiting;

  /// P-18 success snackbar.
  ///
  /// In en, this message translates to:
  /// **'Top up of {amount} succeeded.'**
  String walletTopUpSuccess(String amount);

  /// P-18 inline failure message.
  ///
  /// In en, this message translates to:
  /// **'Top up failed. Try again.'**
  String get walletTopUpFailure;

  /// P-18 retry CTA.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get walletTopUpRetry;

  /// P-12 header.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get sosTitle;

  /// Semantics label on the close (X) button in the SOS screen header.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sosClose;

  /// Semantics label on the SOS hold button.
  ///
  /// In en, this message translates to:
  /// **'Hold to send SOS, 3 second hold'**
  String get sosHoldSemantics;

  /// Instruction under the hold button.
  ///
  /// In en, this message translates to:
  /// **'Hold for 3 seconds'**
  String get sosHoldInstruction;

  /// Status while the SOS request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Sending alert…'**
  String get sosSending;

  /// Failure line on the SOS screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the alert.'**
  String get sosSendFailed;

  /// Retry action after a failed SOS send.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sosRetry;

  /// Label above the reason chips.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get sosReasonLabel;

  /// SOS reason chip.
  ///
  /// In en, this message translates to:
  /// **'Driver danger'**
  String get sosReasonDriverDanger;

  /// SOS reason chip.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get sosReasonAccident;

  /// SOS reason chip.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get sosReasonMedical;

  /// SOS reason chip; default.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sosReasonOther;

  /// Tertiary button to dial Ghana Police emergency line.
  ///
  /// In en, this message translates to:
  /// **'Call 191'**
  String get sosCall191;

  /// P-12 confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Help is on the way'**
  String get sosConfirmationTitle;

  /// P-12 confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contacts have been notified.'**
  String get sosConfirmationBody;

  /// Note on confirmation when coords weren't attached.
  ///
  /// In en, this message translates to:
  /// **'Location not shared'**
  String get sosLocationNotShared;

  /// Ghost button to close the SOS confirmation.
  ///
  /// In en, this message translates to:
  /// **'I\'m safe now'**
  String get sosMarkSafe;

  /// P-13 header.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get reportTitle;

  /// Small label above the category list, showing which booking.
  ///
  /// In en, this message translates to:
  /// **'About booking {reference}'**
  String reportBookingContext(String reference);

  /// Label above the category chips.
  ///
  /// In en, this message translates to:
  /// **'What\'s the issue?'**
  String get reportCategoryLabel;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get reportCategoryAccident;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get reportCategoryBreakdown;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get reportCategoryDelay;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get reportCategorySafety;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Passenger issue'**
  String get reportCategoryPassenger;

  /// Report category chip.
  ///
  /// In en, this message translates to:
  /// **'Road hazard'**
  String get reportCategoryRoadHazard;

  /// Report category chip; default.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportCategoryOther;

  /// Label above the description text field.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened'**
  String get reportDescriptionLabel;

  /// Hint in the description field.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened (at least 10 characters).'**
  String get reportDescriptionHint;

  /// P-13 primary button.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// P-13 inline failure line.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit. Please try again.'**
  String get reportSubmitFailure;

  /// Snackbar after a successful report.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. We\'ll review within 48 hours.'**
  String get reportSuccess;

  /// P-14 header.
  ///
  /// In en, this message translates to:
  /// **'Rate your trip'**
  String get rateTitle;

  /// Fallback when the driver's name isn't known.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get rateDriverFallback;

  /// Fallback for the route line.
  ///
  /// In en, this message translates to:
  /// **'Your trip'**
  String get rateRouteFallback;

  /// Accessibility label for the current star count.
  ///
  /// In en, this message translates to:
  /// **'{stars} of 5 stars'**
  String rateStarsSemantic(int stars);

  /// Tooltip on each star in the picker.
  ///
  /// In en, this message translates to:
  /// **'{star} stars'**
  String rateStarTooltip(int star);

  /// P-14 comment field hint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get rateCommentHint;

  /// P-14 primary button.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get rateSubmit;

  /// P-14 inline failure line.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit. Please try again.'**
  String get rateSubmitFailure;

  /// Snackbar after a successful rating.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating your trip.'**
  String get rateThanks;

  /// Trips tab banner title for an unrated completed booking.
  ///
  /// In en, this message translates to:
  /// **'Rate your last trip'**
  String get rateBannerTitle;

  /// Trips tab banner CTA.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateBannerAction;

  /// Tester menu action to open the SOS screen off-trip.
  ///
  /// In en, this message translates to:
  /// **'Open P-12 Emergency'**
  String get testerMenuEmergency;

  /// P-21 header fallback when the user has no name.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get profileAnonymousName;

  /// Pill on a verified email or phone.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get profileVerified;

  /// Pill on an unverified email or phone.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get profileUnverified;

  /// P-21 section header.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileSectionAccount;

  /// P-21 section header.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get profileSectionPreferences;

  /// P-21 section header.
  ///
  /// In en, this message translates to:
  /// **'PAYMENTS'**
  String get profileSectionPayments;

  /// P-21 section header.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get profileSectionSupport;

  /// P-21 row to P-22.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get profileRowPersonalInfo;

  /// P-21 row to P-23 (coming soon).
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileRowChangePassword;

  /// P-21 row to P-24 (coming soon).
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get profileRowChangeEmail;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileRowNotifications;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'Favourite routes'**
  String get profileRowFavourites;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileRowLanguage;

  /// P-21 row (deep-links to Wallet).
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get profileRowPaymentMethods;

  /// P-21 row (deep-links to Wallet).
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get profileRowTransactions;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'Help centre'**
  String get profileRowHelpCentre;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get profileRowReportProblem;

  /// P-21 row.
  ///
  /// In en, this message translates to:
  /// **'About TroSky'**
  String get profileRowAbout;

  /// Subtitle on unwired P-21 rows (retained for compatibility; all passenger-side uses retired in step 21/B2).
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get profileComingSoon;

  /// Subtitle on P-21 rows whose backend endpoint isn't shipped yet. Retained for compatibility; passenger-side uses removed in step 21/B4 when change-password + change-email went live.
  ///
  /// In en, this message translates to:
  /// **'Coming with the next backend release'**
  String get profileNextBackendRelease;

  /// P-23 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// P-23 lead.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password, then choose a new one.'**
  String get changePasswordIntro;

  /// P-23 field label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// P-23 field label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNewLabel;

  /// P-23 field label.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirmLabel;

  /// P-23 — label on the obscured/show-password toggle.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get changePasswordRevealShow;

  /// P-23 — label on the revealed/hide-password toggle.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get changePasswordRevealHide;

  /// P-23 — Semantics label announced for an obscured password field.
  ///
  /// In en, this message translates to:
  /// **'Password, hidden'**
  String get changePasswordObscuredSemantics;

  /// P-23 strength label.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get changePasswordStrengthWeak;

  /// P-23 strength label.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get changePasswordStrengthFair;

  /// P-23 strength label.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get changePasswordStrengthGood;

  /// P-23 strength label.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get changePasswordStrengthStrong;

  /// P-23 helper under the New field.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with letters and digits.'**
  String get changePasswordRule;

  /// P-23 inline error when Confirm != New.
  ///
  /// In en, this message translates to:
  /// **'The two passwords don\'t match.'**
  String get changePasswordMismatch;

  /// P-23 inline error on Current for 401 INVALID_CREDENTIALS.
  ///
  /// In en, this message translates to:
  /// **'That password doesn\'t match our records.'**
  String get changePasswordWrongCurrent;

  /// P-23 inline error on New for 409 PASSWORD_UNCHANGED (and client pre-check).
  ///
  /// In en, this message translates to:
  /// **'New password must differ from your current one.'**
  String get changePasswordSameAsCurrent;

  /// P-23 inline error for 409 PASSWORD_POLICY_VIOLATION.
  ///
  /// In en, this message translates to:
  /// **'That password doesn\'t meet the policy. Try a longer one with letters and digits.'**
  String get changePasswordTooWeak;

  /// P-23 banner for 429.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a minute.'**
  String get changePasswordRateLimited;

  /// P-23 banner for 429 when Retry-After was given.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds}s.'**
  String changePasswordRateLimitedWithSeconds(int seconds);

  /// P-23 banner for 5xx / unexpected.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t change your password. Please try again.'**
  String get changePasswordServerError;

  /// P-23 banner for network failure.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Reconnect to change your password.'**
  String get changePasswordOffline;

  /// P-23 primary button.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordCta;

  /// P-23 success toast.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get changePasswordSuccess;

  /// P-24a AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmailRequestTitle;

  /// P-24a read-only current email label.
  ///
  /// In en, this message translates to:
  /// **'Current email'**
  String get changeEmailCurrentLabel;

  /// P-24a — shown when the account has no email yet.
  ///
  /// In en, this message translates to:
  /// **'No email on file'**
  String get changeEmailCurrentNone;

  /// P-24a new email field label.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get changeEmailNewLabel;

  /// P-24a confirm-with-password field label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changeEmailPasswordLabel;

  /// P-24a inline error for invalid email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get changeEmailInvalid;

  /// P-24a inline error for 409 EMAIL_UNCHANGED (and client pre-check).
  ///
  /// In en, this message translates to:
  /// **'New email must differ from your current one.'**
  String get changeEmailSameAsCurrent;

  /// P-24a inline error for 409 EMAIL_ALREADY_REGISTERED.
  ///
  /// In en, this message translates to:
  /// **'This email is already linked to another TroSky account.'**
  String get changeEmailAlreadyInUse;

  /// P-24a inline error for 422 EMAIL_DOMAIN_NOT_ALLOWED.
  ///
  /// In en, this message translates to:
  /// **'Emails from that provider aren\'t supported yet.'**
  String get changeEmailDomainNotAllowed;

  /// P-24a inline error for 401 INVALID_CREDENTIALS.
  ///
  /// In en, this message translates to:
  /// **'That password doesn\'t match our records.'**
  String get changeEmailWrongPassword;

  /// P-24a/b banner for 429.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a minute.'**
  String get changeEmailRateLimited;

  /// P-24a/b banner for 429 with Retry-After.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds}s.'**
  String changeEmailRateLimitedWithSeconds(int seconds);

  /// P-24a banner for 5xx / unexpected.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t start the email change. Please try again.'**
  String get changeEmailServerError;

  /// P-24a banner for network failure.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Reconnect to change your email.'**
  String get changeEmailOffline;

  /// P-24a primary button.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get changeEmailRequestCta;

  /// P-24a lead.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email a 6-digit code to your new address to confirm it\'s yours.'**
  String get changeEmailRequestIntro;

  /// P-24b AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Verify your new email'**
  String get changeEmailVerifyTitle;

  /// P-24b sub-head, with the masked new email.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {masked}.'**
  String changeEmailVerifySentTo(String masked);

  /// P-24b helper under the code field.
  ///
  /// In en, this message translates to:
  /// **'You can paste the code from your email.'**
  String get changeEmailVerifyPasteHint;

  /// P-24b code field label.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get changeEmailVerifyCodeLabel;

  /// P-24b — Semantics label for one digit slot in the code field.
  ///
  /// In en, this message translates to:
  /// **'6 digit code, digit {position} of 6'**
  String changeEmailVerifyCodeSemantics(int position);

  /// P-24b resend button.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get changeEmailVerifyResend;

  /// P-24b resend cooldown label.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String changeEmailVerifyResendIn(int seconds);

  /// P-24b primary button.
  ///
  /// In en, this message translates to:
  /// **'Confirm new email'**
  String get changeEmailVerifyCta;

  /// P-24b inline error for 400/401 wrong code.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match. Check your email and try again.'**
  String get changeEmailVerifyWrongCode;

  /// P-24b inline error for 410 / expired-OTP.
  ///
  /// In en, this message translates to:
  /// **'That code expired. Tap Resend.'**
  String get changeEmailVerifyExpired;

  /// P-24b banner for OTP_ATTEMPTS_EXCEEDED.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Resend a new one in a minute.'**
  String get changeEmailVerifyTooManyAttempts;

  /// P-24b banner for 5xx / unexpected.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the change. Please try again.'**
  String get changeEmailVerifyServerError;

  /// P-24b banner for network failure.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Reconnect to confirm your email.'**
  String get changeEmailVerifyOffline;

  /// P-24b success toast (shown on P-22).
  ///
  /// In en, this message translates to:
  /// **'Email updated'**
  String get changeEmailVerifySuccess;

  /// P-22 — muted sub-line under the current email when a change is awaiting confirmation on THIS device. Server-side pending state isn't surfaced yet (no pending_email on /users/me), so this only reflects a change started here.
  ///
  /// In en, this message translates to:
  /// **'Change to {masked} is pending verification.'**
  String piiEmailPending(String masked);

  /// P-22 — overflow menu header on the email pending sub-line.
  ///
  /// In en, this message translates to:
  /// **'Pending email change'**
  String get piiEmailPendingMenu;

  /// P-22 — overflow option to jump back to P-24b.
  ///
  /// In en, this message translates to:
  /// **'Continue verification'**
  String get piiEmailPendingContinue;

  /// P-22 — overflow option to drop the pending state.
  ///
  /// In en, this message translates to:
  /// **'Cancel email change'**
  String get piiEmailPendingCancel;

  /// P-22 — snackbar after cancelling a pending change locally.
  ///
  /// In en, this message translates to:
  /// **'Pending change cleared from this device. You can start a new change at any time.'**
  String get piiEmailPendingCleared;

  /// P-28 Language screen app-bar title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// P-28 — current locale name.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishName;

  /// P-28 — current locale code.
  ///
  /// In en, this message translates to:
  /// **'en_GH'**
  String get languageEnglishCode;

  /// P-28 — pill on the active row.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get languageCurrentPill;

  /// P-28 — muted line under the current-language row.
  ///
  /// In en, this message translates to:
  /// **'More languages coming soon.'**
  String get languageMoreComingSoon;

  /// P-28 — Semantics label on the active-language row.
  ///
  /// In en, this message translates to:
  /// **'Current language: English'**
  String get languageCurrentSemantics;

  /// P-29 About screen app-bar title.
  ///
  /// In en, this message translates to:
  /// **'About TroSky'**
  String get aboutTitle;

  /// P-29 — short tagline.
  ///
  /// In en, this message translates to:
  /// **'Ghanaian shared transport, one tap away.'**
  String get aboutTagline;

  /// P-29 — label next to the version number.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get aboutVersionLabel;

  /// P-29 — row label.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get aboutTerms;

  /// P-29 — row label.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// P-29 — row label.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// P-26 empty-state primary button; opens Search.
  ///
  /// In en, this message translates to:
  /// **'Add a favourite route'**
  String get favouritesEmptyAddCta;

  /// P-21 danger-zone sign-out button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// Sign-out confirmation cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileSignOutCancel;

  /// Sign-out confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Sign out of TroSky?'**
  String get profileSignOutConfirmTitle;

  /// Sign-out confirmation body.
  ///
  /// In en, this message translates to:
  /// **'You can sign back in any time with your phone or email.'**
  String get profileSignOutConfirmBody;

  /// P-21 danger-zone delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// P-22 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get piiTitle;

  /// P-22 name field label.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get piiNameLabel;

  /// P-22 email read-only label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get piiEmailLabel;

  /// P-22 phone read-only label.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get piiPhoneLabel;

  /// P-22 avatar read-only label.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get piiAvatarLabel;

  /// P-22 empty-field value.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get piiNotSet;

  /// P-22 note on read-only email/phone.
  ///
  /// In en, this message translates to:
  /// **'Contact support to change this.'**
  String get piiChangeViaSupport;

  /// P-22 primary button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get piiSave;

  /// P-22 success snackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get piiEditSaved;

  /// P-22 inline failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again.'**
  String get piiEditFailure;

  /// P-25 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// P-25 big red headline.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account is permanent.'**
  String get deleteAccountWarning;

  /// P-25 explainer.
  ///
  /// In en, this message translates to:
  /// **'This signs you out everywhere and removes your profile from TroSky. Data-retention rules may keep anonymised trip records for accounting.'**
  String get deleteAccountBody;

  /// P-25 scope section title.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted:'**
  String get deleteAccountScopeTitle;

  /// P-25 bullet list of deleted data.
  ///
  /// In en, this message translates to:
  /// **'• Your profile, name and contact details.\n• Saved payment methods.\n• Favourite routes and preferences.\n• Local tickets and cached data.'**
  String get deleteAccountScopeBullets;

  /// P-25 instruction.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type DELETE below and enter your password.'**
  String get deleteAccountConfirmInstruction;

  /// P-25 type-to-confirm label.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get deleteAccountConfirmLabel;

  /// P-25 password label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get deleteAccountPasswordLabel;

  /// P-25 destructive CTA.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountCta;

  /// P-25 inline failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again.'**
  String get deleteAccountFailure;

  /// S-09a title.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetRequestTitle;

  /// S-09a instruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number or email. If an account exists, we\'ll send a 6-digit code.'**
  String get resetRequestInstruction;

  /// S-09a identifier field label.
  ///
  /// In en, this message translates to:
  /// **'Phone or email'**
  String get resetIdentifierLabel;

  /// S-09a primary button.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get resetRequestCta;

  /// S-09a neutral confirmation (same text for known + unknown).
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this, we\'ve sent a code with instructions.'**
  String get resetRequestNeutralConfirmation;

  /// S-09a link to S-09b.
  ///
  /// In en, this message translates to:
  /// **'I have a code →'**
  String get resetIHaveACode;

  /// S-09b title.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewTitle;

  /// S-09b code field label.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get resetCodeLabel;

  /// S-09b new password field label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewPasswordLabel;

  /// S-09b confirm password field label.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get resetConfirmPasswordLabel;

  /// S-09b primary button.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get resetNewCta;

  /// S-09b inline failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset. Check the code and try again.'**
  String get resetFailure;

  /// S-09b success snackbar.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Please sign in again.'**
  String get resetSuccess;

  /// Sign-in link to S-09a.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get signInResetPassword;

  /// P-20 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// P-20 tab.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notifTabInbox;

  /// P-20 tab.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get notifTabPrefs;

  /// P-20 empty state.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notifEmpty;

  /// P-20 AppBar action.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifMarkAllRead;

  /// Toast when a notification has no matching route.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get notifOpeningToast;

  /// Notification category label.
  ///
  /// In en, this message translates to:
  /// **'Bookings & payments'**
  String get notifCategoryTransactional;

  /// Notification category label.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get notifCategorySafety;

  /// Notification category label.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get notifCategoryPromotional;

  /// Preferences banner explaining the channel-level shape.
  ///
  /// In en, this message translates to:
  /// **'Per-category toggles are coming. For now, choose which channels we use.'**
  String get notifPrefsBannerChannelOnly;

  /// Preference toggle.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPrefsPushEnabled;

  /// Preference toggle.
  ///
  /// In en, this message translates to:
  /// **'SMS notifications'**
  String get notifPrefsSmsEnabled;

  /// Preference toggle.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get notifPrefsEmailEnabled;

  /// Preference toggle.
  ///
  /// In en, this message translates to:
  /// **'Promotional messages'**
  String get notifPrefsPromotionalOptIn;

  /// Toast when the toggle revert fires.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Reverted.'**
  String get notifPrefsSaveFailed;

  /// Relative time: < 1 minute.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notifTimeJustNow;

  /// Relative time: minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String notifTimeMinutes(int minutes);

  /// Relative time: hours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String notifTimeHours(int hours);

  /// Relative time: yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notifTimeYesterday;

  /// P-26 AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favouritesTitle;

  /// P-26 empty state.
  ///
  /// In en, this message translates to:
  /// **'Save routes you take often. Add one from Search.'**
  String get favouritesEmpty;

  /// P-26 helper line when empty.
  ///
  /// In en, this message translates to:
  /// **'To add: open Search → pick a route → tap the heart.'**
  String get favouritesHowToAdd;

  /// Each favourite-route row's main text.
  ///
  /// In en, this message translates to:
  /// **'{origin} → {destination}'**
  String favouriteRow(String origin, String destination);

  /// P-26 delete action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get favouriteDelete;

  /// P-26 confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'Remove this favourite?'**
  String get favouriteDeleteConfirmTitle;

  /// P-26 confirm sheet body.
  ///
  /// In en, this message translates to:
  /// **'You can add it again from Search.'**
  String get favouriteDeleteConfirmBody;

  /// P-26 failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove.'**
  String get favouriteDeleteFailed;

  /// Semantics label on the Home bell button.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {unread} unread'**
  String homeBellSemantics(int unread);

  /// Trips tab banner for an unrated completed booking.
  ///
  /// In en, this message translates to:
  /// **'Rate your trip with {driver}'**
  String rateBannerTitleWithDriver(String driver);

  /// Trips banner dismiss button semantics.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get rateBannerDismiss;

  /// Semantics for a favourite chip on Search.
  ///
  /// In en, this message translates to:
  /// **'Favourite, {label}'**
  String searchFavouriteChipSemantics(String label);
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
