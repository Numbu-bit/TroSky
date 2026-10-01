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

  @override
  String get welcomeTitle => 'Welcome to TroSky';

  @override
  String get welcomeSubtitle => 'Your journey. On time. Every time.';

  @override
  String get phoneLabel => 'PHONE NUMBER';

  @override
  String get phoneHint => 'XX XXX XXXX';

  @override
  String get phoneCountry => 'Country: Ghana, +233';

  @override
  String get countrySheetTitle => 'Country';

  @override
  String get countryGhana => 'Ghana (+233)';

  @override
  String get countryOnlyGhana => 'TroSky is only in Ghana for now.';

  @override
  String get welcomeContinue => 'Continue';

  @override
  String get welcomeOrContinueWith => 'or continue with';

  @override
  String get welcomeContinueWithEmail => 'Continue with Email';

  @override
  String get welcomeGhanaCardBefore => 'Optionally verify your ';

  @override
  String get welcomeGhanaCardHighlight => 'Ghana Card';

  @override
  String get welcomeGhanaCardAfter =>
      ' for extra trust and higher wallet limits.';

  @override
  String get welcomeHaveAccount => 'Already have an account?';

  @override
  String get welcomeSignIn => 'Sign in';

  @override
  String get welcomeDriverPrompt => 'Driving for TroSky?';

  @override
  String get welcomeDriverAction => 'Sign up as a driver';

  @override
  String get welcomeDriverModePrompt => 'Signing up as a driver.';

  @override
  String get welcomeDriverModeAction => 'Sign up as a passenger instead';

  @override
  String get detailsTitle => 'Your details';

  @override
  String get detailsSubtitle => 'A few more details to create your account.';

  @override
  String get detailsSubtitleDriver =>
      'A few more details to create your driver account.';

  @override
  String get nameLabel => 'FULL NAME';

  @override
  String get nameHint => 'e.g. Ama Mensah';

  @override
  String get emailLabel => 'EMAIL';

  @override
  String get emailHint => 'you@gmail.com';

  @override
  String get emailHelper => 'Use your Gmail address';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get passwordShow => 'Show';

  @override
  String get passwordHide => 'Hide';

  @override
  String get passwordRuleLength => 'At least 8 characters';

  @override
  String get passwordRuleUpper => 'An upper-case letter';

  @override
  String get passwordRuleLower => 'A lower-case letter';

  @override
  String get passwordRuleDigit => 'A number';

  @override
  String get detailsCreateAccount => 'Create account';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeSentByText(String target) {
    return 'Code sent by text to $target';
  }

  @override
  String codeSentByEmail(String target) {
    return 'Code sent by email to $target';
  }

  @override
  String get codeFieldLabel => '6-digit code';

  @override
  String get codeVerify => 'Verify';

  @override
  String get codeResend => 'Resend code';

  @override
  String get codeResendPrompt => 'Didn\'t get it?';

  @override
  String codeResendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get codeResent => 'A new code is on its way.';

  @override
  String get codeNoAccountHint =>
      'No code? Check this number has a TroSky account.';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue your journey.';

  @override
  String get signInUseEmail => 'Use email instead';

  @override
  String get signInUsePhone => 'Use phone instead';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInForgotPrompt => 'Forgot password?';

  @override
  String get signInWithCode => 'Sign in with a code';

  @override
  String get signInNewPrompt => 'New to TroSky?';

  @override
  String get signInCreateAccount => 'Create account';

  @override
  String get signInCodeTitle => 'Sign in with a code';

  @override
  String get signInCodeSubtitle => 'We\'ll text a code to your phone.';

  @override
  String get signInSendCode => 'Send code';

  @override
  String get signInUsePassword => 'Use my password instead';

  @override
  String get backLabel => 'Back';

  @override
  String get errorPhoneInvalid => 'Enter a valid Ghana phone number.';

  @override
  String get errorNameRequired => 'Enter your full name.';

  @override
  String get errorEmailInvalid => 'Enter a valid email address.';

  @override
  String errorEmailDomain(String domains) {
    return 'Use your Gmail address ($domains).';
  }

  @override
  String get errorEmailTaken => 'This email already has a TroSky account.';

  @override
  String get errorPhoneTaken => 'This number already has a TroSky account.';

  @override
  String get errorPasswordRules => 'Your password needs all four of these.';

  @override
  String get errorPasswordRequired => 'Enter your password.';

  @override
  String get errorInvalidCredentials =>
      'That phone number, email or password isn\'t right.';

  @override
  String errorAccountLocked(String time) {
    return 'Too many wrong passwords. Try again after $time.';
  }

  @override
  String get errorAccountSuspended =>
      'This account is suspended. Contact TroSky support.';

  @override
  String errorRateLimited(int seconds) {
    return 'Too many tries. Wait $seconds s and try again.';
  }

  @override
  String get errorRateLimitedNoTime =>
      'Too many tries. Wait a moment and try again.';

  @override
  String get errorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get errorTimeout => 'The network is slow right now. Try again.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get errorCodeInvalid =>
      'That code isn\'t right. Check it and try again.';

  @override
  String get errorCodeExpired => 'Code expired — resend';

  @override
  String get errorCodeAttempts => 'Too many wrong codes. Resend a new code.';

  @override
  String get errorCodeMissing =>
      'This code is no longer valid. Resend a new one.';

  @override
  String get errorNoAccount => 'No account for this number';

  @override
  String get roleNotDriverTitle => 'This account isn\'t a driver account yet';

  @override
  String get roleNotDriverBody =>
      'Become a driver to start driving with TroSky, or carry on as a passenger.';

  @override
  String get roleBecomeDriver => 'Become a driver';

  @override
  String get roleContinuePassenger => 'Continue as passenger';

  @override
  String get roleDriverAccountTitle => 'This is a driver account';

  @override
  String get roleDriverAccountBody => 'Switch to driver mode to continue.';

  @override
  String get roleSwitchToDriver => 'Switch to driver mode';

  @override
  String get roleUseAnotherAccount => 'Use another account';

  @override
  String get offlineBanner =>
      'You\'re offline. Showing your last saved details.';

  @override
  String get offlineRetry => 'Retry';

  @override
  String get signOut => 'Sign out';
}
