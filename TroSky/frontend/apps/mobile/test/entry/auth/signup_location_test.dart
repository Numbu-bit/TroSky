import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/entry/auth/presentation/details_screen.dart';
import 'package:mobile/entry/auth/presentation/verify_code_screen.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../helpers/fakes.dart';
import 'auth_helpers.dart';

/// Lagos, Nigeria: outside Ghana.
const LatLng _lagos = LatLng(6.5244, 3.3792);

const _sheetTitle = "Confirm you're in Ghana";

/// A link with no prompt ("Try again", "Open settings"), matched exactly:
/// some messages also say "try again".
Finder _link(String action) => find.text(action, findRichText: true);
const _needed = "TroSky needs your location once to confirm you're in Ghana.";

/// The mock auth repository, keeping every register request. With
/// [dropLocation] it forgets the position on the way, so the backend
/// answers LOCATION_REQUIRED.
class _RecordingAuth implements AuthRepository {
  late AuthRepository inner;
  final List<RegisterRequest> registered = [];
  bool dropLocation = false;

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest request) {
    registered.add(request);
    return inner.register(
      dropLocation
          ? request.copyWith(latitude: null, longitude: null)
          : request,
    );
  }

  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest r) =>
      inner.verifyOtp(r);
  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest r) =>
      inner.resendOtp(r);
  @override
  Future<Result<TokenPairResponse>> login(LoginRequest r) => inner.login(r);
  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest r) =>
      inner.otpLogin(r);
  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest r) =>
      inner.refresh(r);
  @override
  Future<Result<void>> logout() => inner.logout();
}

void main() {
  late TestWorld world;
  late _RecordingAuth auth;

  /// Your details, with [auth] in front of the mock backend.
  Future<void> open(WidgetTester tester, {AppMode? mode}) async {
    world = TestWorld(mode: mode);
    auth = _RecordingAuth();
    await openDetails(
      tester,
      world: world,
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => auth
            ..inner = MockAuthRepository(
              world.backend,
              tokens: () => ref.read(tokenManagerProvider),
            ),
        ),
      ],
    );
  }

  group('S-06 sign-up location', () {
    testWidgets('granted: the position goes to register, then S-07', (
      tester,
    ) async {
      await open(tester);
      await submitDetails(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(auth.registered.single.latitude, signUpPosition.latitude);
      expect(auth.registered.single.longitude, signUpPosition.longitude);
      expect(find.byType(VerifyCodeScreen), findsOneWidget);
    });

    testWidgets('not asked yet: the sheet, then the phone dialog', (
      tester,
    ) async {
      await open(tester);
      world.location.permission = LocationPermissionStatus.denied;
      await submitDetails(tester);

      expect(find.text(_sheetTitle), findsOneWidget);
      await tapVisible(tester, find.text('Allow location'));

      expect(world.location.dialogs, 1);
      expect(auth.registered.single.latitude, signUpPosition.latitude);
      expect(find.byType(VerifyCodeScreen), findsOneWidget);
    });

    testWidgets('denied: no request, the message and Try again', (
      tester,
    ) async {
      await open(tester);
      world.location
        ..permission = LocationPermissionStatus.denied
        ..dialogAnswer = LocationPermissionStatus.denied;
      await submitDetails(tester);
      await tapVisible(tester, find.text('Allow location'));

      expect(auth.registered, isEmpty);
      expect(find.byType(DetailsScreen), findsOneWidget);
      expect(find.text(_needed), findsOneWidget);
      expect(_link('Open settings'), findsNothing);

      // Allowed the second time: Try again goes all the way.
      world.location.dialogAnswer = LocationPermissionStatus.granted;
      await tapVisible(tester, _link('Try again'));
      await tapVisible(tester, find.text('Allow location'));

      expect(auth.registered.single.latitude, signUpPosition.latitude);
      expect(find.byType(VerifyCodeScreen), findsOneWidget);
    });

    testWidgets('"Not now" on the sheet: no phone dialog, no request', (
      tester,
    ) async {
      await open(tester);
      world.location.permission = LocationPermissionStatus.denied;
      await submitDetails(tester);
      await tapVisible(tester, find.text('Not now'));

      expect(world.location.dialogs, 0);
      expect(auth.registered, isEmpty);
      expect(find.text(_needed), findsOneWidget);
    });

    testWidgets('permanently denied: Open settings, no sheet, no request', (
      tester,
    ) async {
      await open(tester);
      world.location.permission = LocationPermissionStatus.deniedForever;
      await submitDetails(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(auth.registered, isEmpty);
      expect(
        find.text(
          "TroSky needs your location once to confirm you're in Ghana. "
          'Location is blocked for TroSky: allow it in Settings.',
        ),
        findsOneWidget,
      );
      expect(_link('Try again'), findsOneWidget);

      await tapVisible(tester, _link('Open settings'));
      expect(world.location.appSettingsOpened, 1);
    });

    testWidgets('timeout: no position in time, no request', (tester) async {
      await open(tester);
      world.location.position = null;
      await submitDetails(tester);

      expect(auth.registered, isEmpty);
      expect(
        find.text(
          "TroSky couldn't find your location to confirm you're in Ghana. "
          'Try again in a moment.',
        ),
        findsOneWidget,
      );
      expect(_link('Try again'), findsOneWidget);
    });

    testWidgets("the phone's location is off: no request", (tester) async {
      await open(tester);
      world.location.enabled = false;
      await submitDetails(tester);

      expect(auth.registered, isEmpty);
      expect(
        find.text(
          "TroSky needs your location once to confirm you're in Ghana. "
          "Turn on your phone's location, then try again.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('LOCATION_NOT_SERVED: only available in Ghana', (tester) async {
      await open(tester);
      world.location.position = _lagos;
      await submitDetails(tester);

      expect(auth.registered.single.latitude, _lagos.latitude);
      expect(find.byType(DetailsScreen), findsOneWidget);
      expect(
        find.text('TroSky is only available in Ghana for now.'),
        findsOneWidget,
      );
      expect(_link('Try again'), findsNothing);
    });

    testWidgets('LOCATION_REQUIRED from the server: as if refused', (
      tester,
    ) async {
      await open(tester);
      auth.dropLocation = true;
      await submitDetails(tester);

      expect(auth.registered, hasLength(1));
      expect(find.byType(DetailsScreen), findsOneWidget);
      expect(find.text(_needed), findsOneWidget);
      expect(_link('Try again'), findsOneWidget);
    });

    testWidgets('a driver signs up without location', (tester) async {
      await open(tester, mode: AppMode.driver);
      world.location.permission = LocationPermissionStatus.denied;
      await submitDetails(tester);

      expect(find.text(_sheetTitle), findsNothing);
      expect(world.location.dialogs, 0);
      expect(auth.registered.single.role, RegistrableRole.driver);
      expect(auth.registered.single.latitude, isNull);
      expect(find.byType(VerifyCodeScreen), findsOneWidget);
    });
  });
}
