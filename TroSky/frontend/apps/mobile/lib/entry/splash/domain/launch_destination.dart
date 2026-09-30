/// Where the app goes when the splash screen closes.
enum LaunchDestination {
  onboarding,
  signIn,
  home;

  /// Onboarding comes first. After that, a saved session skips sign-in.
  static LaunchDestination choose({
    required bool onboardingSeen,
    required bool hasSession,
  }) {
    if (!onboardingSeen) return LaunchDestination.onboarding;
    return hasSession ? LaunchDestination.home : LaunchDestination.signIn;
  }
}
