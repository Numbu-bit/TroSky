import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_auth/trosky_auth.dart';

part 'session_store_provider.g.dart';

/// The session saved on this device. A stub until Sign In (S-06) lands.
@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => const StubSessionStore();
