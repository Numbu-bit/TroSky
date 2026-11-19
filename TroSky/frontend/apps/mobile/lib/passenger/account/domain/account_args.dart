/// Compile-time flag for the whole Account group (P-21/P-22/P-25 and
/// S-09). Staging + demo true (`env/staging.json`); prod false until
/// Maher-007 exercises change-password + delete on a throwaway account.
const bool accountEnabled = bool.fromEnvironment('ACCOUNT_ENABLED');

/// Which section the user tapped on P-21. Used in the
/// `profile_section_tapped` analytics event.
enum ProfileSection {
  personalInfo,
  changePassword,
  changeEmail,
  notifications,
  favourites,
  language,
  paymentMethods,
  transactions,
  helpCentre,
  reportProblem,
  about,
}

String profileSectionName(ProfileSection s) => switch (s) {
  ProfileSection.personalInfo => 'personal_info',
  ProfileSection.changePassword => 'change_password',
  ProfileSection.changeEmail => 'change_email',
  ProfileSection.notifications => 'notifications',
  ProfileSection.favourites => 'favourites',
  ProfileSection.language => 'language',
  ProfileSection.paymentMethods => 'payment_methods',
  ProfileSection.transactions => 'transactions',
  ProfileSection.helpCentre => 'help_centre',
  ProfileSection.reportProblem => 'report_problem',
  ProfileSection.about => 'about',
};

/// Where the user came from on S-09.
enum ResetPasswordEntry { signIn, deepLink }

/// Opens S-09b. [target] is the phone/email the code was sent to.
class ResetPasswordArgs {
  const ResetPasswordArgs({required this.target, this.code});
  final String target;
  final String? code;
}

/// Help centre URL. Hardcoded today — flagged as a placeholder in the
/// PR body. Replace with a Remote-Config-driven value once the team has
/// a real help page.
const String helpCentreUrl = 'https://trosky.africa/help';
