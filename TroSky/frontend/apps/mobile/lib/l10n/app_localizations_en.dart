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
  String get detailsLocationTitle => 'Confirm you\'re in Ghana';

  @override
  String get detailsLocationBody =>
      'TroSky is only available in Ghana for now. To create your account, we check your location once. It isn\'t saved.';

  @override
  String get detailsLocationNeeded =>
      'TroSky needs your location once to confirm you\'re in Ghana.';

  @override
  String get detailsLocationBlocked =>
      'TroSky needs your location once to confirm you\'re in Ghana. Location is blocked for TroSky: allow it in Settings.';

  @override
  String get detailsLocationServiceOff =>
      'TroSky needs your location once to confirm you\'re in Ghana. Turn on your phone\'s location, then try again.';

  @override
  String get detailsLocationNotFound =>
      'TroSky couldn\'t find your location to confirm you\'re in Ghana. Try again in a moment.';

  @override
  String get detailsLocationNotServed =>
      'TroSky is only available in Ghana for now.';

  @override
  String get detailsTryAgain => 'Try again';

  @override
  String get detailsOpenSettings => 'Open settings';

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

  @override
  String get tabHome => 'Home';

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabWallet => 'Wallet';

  @override
  String get tabProfile => 'Profile';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String homeName(String name) {
    return '$name 👋';
  }

  @override
  String get homeNameFallback => 'Welcome 👋';

  @override
  String get homeLocationFallback => 'Accra';

  @override
  String homeLocationLabel(String place) {
    return 'Your area: $place';
  }

  @override
  String get homeLocationLoading => 'Finding your area';

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeSearchHint => 'Where are you going?';

  @override
  String get homeSearchNow => 'Now';

  @override
  String get homeMyLocation => 'My location';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeSosLabel => 'SOS, emergency help';

  @override
  String get homeYouAreHere => 'You are here';

  @override
  String homeVehicle(String route, int seats) {
    String _temp0 = intl.Intl.pluralLogic(
      seats,
      locale: localeName,
      other: '$seats seats free',
      one: '1 seat free',
    );
    return '$route, $_temp0';
  }

  @override
  String get homeVehiclesError => 'Couldn\'t load vehicles';

  @override
  String get homeMapLoading => 'Loading map';

  @override
  String get homeFavouriteRoutes => 'Favourite Routes';

  @override
  String get homeSeeAll => 'See all';

  @override
  String homeRoute(String origin, String destination) {
    return '$origin → $destination';
  }

  @override
  String get homeFavouritesEmpty => 'No favourite routes yet.';

  @override
  String get homeFavouritesError => 'Couldn\'t load your favourite routes.';

  @override
  String get homeFavouritesLoading => 'Loading favourite routes';

  @override
  String get homePromoEyebrow => 'NEW FEATURE';

  @override
  String get homePromoTitle => 'Subscribe your commute';

  @override
  String get homePromoBody => 'Save up to 40% with a monthly plan';

  @override
  String get homePromoAction => 'Try it';

  @override
  String get homeLocationPromptTitle => 'See rides near you';

  @override
  String get homeLocationPromptBody =>
      'TroSky uses your location to show the nearest stop and the vehicles around you. You can still search for trips without it.';

  @override
  String get homeLocationAllow => 'Allow location';

  @override
  String get homeLocationNotNow => 'Not now';

  @override
  String get homeLocationBlocked =>
      'Location is off for TroSky. Turn it on in Settings.';

  @override
  String get homeLocationServiceOff => 'Your phone\'s location is off.';

  @override
  String get homeLocationNotFound => 'Couldn\'t find your location.';

  @override
  String get homeOpenSettings => 'Settings';

  @override
  String get placeholderNotifications => 'Notifications';

  @override
  String get placeholderFavouriteRoutes => 'Favourite Routes';

  @override
  String get placeholderSubscribe => 'Subscribe';

  @override
  String get placeholderSos => 'SOS';

  @override
  String get placeholderSoon => 'This screen is coming soon.';

  @override
  String priceCedis(String amount) {
    return '₵$amount';
  }

  @override
  String distanceMetres(int metres) {
    return '$metres m';
  }

  @override
  String distanceKilometres(String kilometres) {
    return '$kilometres km';
  }

  @override
  String get vehicleBus => 'Bus';

  @override
  String get vehicleMinibus => 'Minibus';

  @override
  String get vehicleShuttle => 'Shuttle';

  @override
  String get vehicleSedan => 'Saloon Car';

  @override
  String get vehicleOther => 'Vehicle';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchTitle => 'Where are you going?';

  @override
  String get searchFromLabel => 'From';

  @override
  String get searchToLabel => 'To';

  @override
  String get searchCurrentLocation => 'Current location';

  @override
  String get searchCurrentLocationHint => 'Board at the nearest stop';

  @override
  String get searchFromHint => 'Choose a pickup stop';

  @override
  String get searchToHint => 'Where to?';

  @override
  String get searchLocationOff => 'Location is off. Choose a pickup stop.';

  @override
  String get searchWhenNow => 'Now';

  @override
  String get searchWhenSchedule => 'Schedule';

  @override
  String get searchStopsHeading => 'Stops';

  @override
  String searchNoStops(String query) {
    return 'No stops match \"$query\".';
  }

  @override
  String get searchStopsError => 'Couldn\'t search stops.';

  @override
  String get searchTypeMore => 'Type 2 letters or more to search stops.';

  @override
  String get searchNearbyHeading => 'Nearby stops';

  @override
  String get searchRecentHeading => 'Recent searches';

  @override
  String get searchFavouritesHeading => 'Favourite routes';

  @override
  String get searchCurrentLocationShort => 'Current location';

  @override
  String get searchButton => 'Search';

  @override
  String searchStopDistance(String distance) {
    return '$distance away';
  }

  @override
  String get resultsRouteLabel => 'Route';

  @override
  String resultsJourney(String origin, String destination) {
    return '$origin → $destination';
  }

  @override
  String get resultsApproaching =>
      'Showing vehicles still approaching your stop';

  @override
  String get resultsShowAll => 'Show all';

  @override
  String get resultsHidePassed => 'Hide passed';

  @override
  String get filterNow => 'Now';

  @override
  String get filterSchedule => 'Schedule';

  @override
  String get filterCheapest => 'Cheapest';

  @override
  String get filterFastest => 'Fastest';

  @override
  String get filterMinibus => 'Minibus';

  @override
  String get resultsBestMatch => 'BEST MATCH';

  @override
  String resultsTimes(String departs, String eta) {
    return 'Departs $departs · ETA $eta';
  }

  @override
  String resultsDeparts(String departs) {
    return 'Departs $departs';
  }

  @override
  String resultsSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String get resultsFull => 'Full';

  @override
  String get resultsPassed => 'Passed';

  @override
  String resultsApproachingBadge(int minutes) {
    return '~$minutes min away · approaching your stop';
  }

  @override
  String resultsBoardAt(String stop, String distance) {
    return 'Board at $stop · $distance away';
  }

  @override
  String resultsBoardAtStop(String stop) {
    return 'Board at $stop';
  }

  @override
  String resultsSave(int percent) {
    return 'Save $percent%';
  }

  @override
  String get resultsPassedNote => 'Already passed your stop — unavailable';

  @override
  String resultsShowPassed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count vehicles that already passed your stop',
      one: 'Show 1 vehicle that already passed your stop',
    );
    return '$_temp0';
  }

  @override
  String get resultsEmpty => 'No vehicles on this route right now';

  @override
  String get resultsTryAnotherTime => 'Try another time';

  @override
  String get resultsNoMinibus => 'No minibuses among these trips.';

  @override
  String get resultsShowAllVehicles => 'Show all vehicles';

  @override
  String get resultsLoadMoreError => 'Couldn\'t load more trips.';

  @override
  String get resultsNoPickup =>
      'No pickup stop is within walking distance of you.';

  @override
  String get resultsNoLocation => 'We couldn\'t find your location.';

  @override
  String get resultsChoosePickup => 'Choose a pickup stop';

  @override
  String get resultsSaveRoute => 'Save this route';

  @override
  String get resultsRouteSavedLabel => 'Saved to your favourite routes';

  @override
  String get resultsRouteSaved => 'Saved to your favourite routes.';

  @override
  String get resultsRouteExists => 'This route is already in your favourites.';

  @override
  String get resultsRouteLimit =>
      'You can save up to 20 routes. Remove one first.';

  @override
  String resultsTripLabel(
    String vehicle,
    String plate,
    String times,
    String seats,
  ) {
    return '$vehicle $plate. $times. $seats.';
  }

  @override
  String resultsWas(String price) {
    return 'was $price';
  }

  @override
  String get resultsLoading => 'Loading trips';

  @override
  String get seatsTitle => 'Choose Your Seat';

  @override
  String seatsSubtitle(
    String origin,
    String destination,
    String plate,
    String departs,
  ) {
    return '$origin → $destination · $plate · Departs $departs';
  }

  @override
  String seatsBookedSuffix(int total) {
    return '/$total booked';
  }

  @override
  String seatsBookedLabel(int booked, int total) {
    return '$booked of $total seats booked';
  }

  @override
  String get seatsLegendAvailable => 'Available';

  @override
  String get seatsLegendTaken => 'Taken';

  @override
  String get seatsLegendSelected => 'Selected';

  @override
  String seatLabel(String number) {
    return 'Seat $number';
  }

  @override
  String seatLabelTaken(String number) {
    return 'Seat $number, taken';
  }

  @override
  String seatLabelSelected(String number) {
    return 'Seat $number, selected';
  }

  @override
  String get seatsOneSelected => '1 seat selected';

  @override
  String seatsManySelected(int count) {
    return '$count seats selected (group booking)';
  }

  @override
  String seatsList(String seats) {
    return 'Seats: $seats';
  }

  @override
  String get seatsClear => 'Clear';

  @override
  String get seatsYouPayNow => 'You pay now';

  @override
  String seatsPriceTimes(String price, int count) {
    return '$price × $count seats';
  }

  @override
  String seatsDropsTo(String price) {
    return '↓ Drops to $price';
  }

  @override
  String get seatsAsMoreJoin => 'as more riders join';

  @override
  String seatsWas(String price) {
    return 'was $price';
  }

  @override
  String get seatsSelectToContinue => 'Select Seats to Continue';

  @override
  String seatsReserveOne(String number) {
    return 'Reserve Seat $number';
  }

  @override
  String seatsReserveMany(int count, String total) {
    return 'Reserve $count Seats · $total';
  }

  @override
  String seatsMax(int max) {
    return 'You can book up to $max seats at once.';
  }

  @override
  String seatsJustTaken(int count, String seats) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seats $seats were just taken. Choose other seats.',
      one: 'Seat $seats was just taken. Choose another seat.',
    );
    return '$_temp0';
  }

  @override
  String get seatsTripClosed =>
      'This trip can no longer be booked. Choose another one.';

  @override
  String get seatsPickupPassed =>
      'This vehicle has already passed your pickup. Choose another one.';

  @override
  String get seatsStopsChanged =>
      'This trip no longer stops where you chose. Choose another one.';

  @override
  String get seatsBackToResults => 'Back to results';

  @override
  String get seatsLoading => 'Loading seats';

  @override
  String get seatsLoadError => 'Couldn\'t load the seats.';

  @override
  String get seatsNoVehicle =>
      'This trip has no vehicle yet, so its seats can\'t be chosen.';

  @override
  String get bookingPassengerFallback => 'TroSky passenger';

  @override
  String bookingGuestName(String firstName, int number) {
    return '$firstName\'s guest $number';
  }

  @override
  String bookingGuestFallback(int number) {
    return 'Guest $number';
  }

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentSubtitle => 'Review and confirm your booking';

  @override
  String get paymentToday => 'Today';

  @override
  String get paymentTomorrow => 'Tomorrow';

  @override
  String get paymentVehicle => 'Vehicle';

  @override
  String paymentSeatsAnd(String seats, String last) {
    return '$seats & $last';
  }

  @override
  String get paymentWaitingTitle => 'Waiting for the driver to accept';

  @override
  String get paymentWaitingBody =>
      'Your seats are held. You\'ll pay only after the driver accepts.';

  @override
  String paymentAnswerWindow(int minutes) {
    return '$minutes-minute response window';
  }

  @override
  String paymentAnswerTimeLeft(String time) {
    return '$time left for the driver to answer';
  }

  @override
  String get paymentCancelRequest => 'Cancel request';

  @override
  String get paymentMovedUnanswered =>
      'The driver didn\'t respond, so we moved you to another vehicle.';

  @override
  String get paymentMovedDeclined =>
      'The driver couldn\'t take your booking, so we moved you to another vehicle.';

  @override
  String get paymentNewVehicle => 'New vehicle assigned';

  @override
  String get paymentNewDriverTitle => 'Waiting for the new driver to accept';

  @override
  String get paymentNewDriverBody =>
      'Your seats are held while the new driver reviews your booking.';

  @override
  String get paymentAccepted => 'Driver accepted your booking';

  @override
  String get paymentPayWithin => 'Pay within';

  @override
  String get paymentNotAcceptedTitle => 'No driver accepted your booking';

  @override
  String get paymentNotAcceptedBody =>
      'You haven\'t been charged. Your seats have been released.';

  @override
  String get paymentSearchAgain => 'Search again';

  @override
  String get paymentBackHome => 'Back to Home';

  @override
  String get paymentOffline => 'No connection. We\'ll keep checking.';

  @override
  String get paymentSeats => 'Seats';

  @override
  String get paymentTotal => 'Total';

  @override
  String get paymentComingSoon =>
      'Paying in the app is coming soon. Your seats stay held until the timer ends.';

  @override
  String get paymentCancel => 'Cancel booking';

  @override
  String get paymentCancelled =>
      'Booking cancelled. Your seats are free again.';

  @override
  String get paymentReleaseTitle => 'Change your seats?';

  @override
  String get paymentReleaseBody =>
      'Going back releases the seats held for you, so you can choose again.';

  @override
  String get paymentReleaseKeep => 'Keep these seats';

  @override
  String get paymentReleaseConfirm => 'Release seats';

  @override
  String get paymentReleased => 'Seats released. Choose again.';

  @override
  String get paymentExpired =>
      'Your seat hold has expired. Choose your seats again.';

  @override
  String get paymentExpiredHome => 'Your seat hold has expired.';
}
