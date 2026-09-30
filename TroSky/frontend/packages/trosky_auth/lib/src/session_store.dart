/// Where the signed-in session is kept on this device.
///
/// A session is the token pair returned by `POST /auth/login` and
/// `POST /auth/otp-login` (`TokenPairResponse` in
/// backend/app/schemas/auth.py). The refresh token is the part that survives
/// an app restart.
abstract interface class SessionStore {
  /// Whether a session is saved on this device. Only reads local storage; it
  /// doesn't check the session with the backend.
  Future<bool> hasSavedSession();
}

/// Stand-in until Sign In (S-06) saves sessions: there is never a saved
/// session, so the app always goes to sign-in after onboarding.
///
/// TODO(auth): replace with a secure-storage store when sign-in lands.
class StubSessionStore implements SessionStore {
  const StubSessionStore();

  @override
  Future<bool> hasSavedSession() async => false;
}
