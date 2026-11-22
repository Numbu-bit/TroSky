// Screen-capture protection for sensitive content (H1).
//
// Android: FLAG_SECURE on the window blocks screenshots, screen
// recordings and app-switcher thumbnails. Set/cleared per-route via a
// method channel to MainActivity, reference-counted so a nested
// sensitive route popping does not strip the flag from a sensitive
// parent still on screen.
//
// iOS: there is no screenshot-prevention API. Apple's recommendation
// for app-switcher thumbnails is to cover the UI with a privacy view
// before the system takes the snapshot. We render an opaque overlay
// via a global [ValueNotifier] the shell listens to, and switch it on
// whenever a [TroskySecureScreen] is mounted AND the app is
// backgrounding (`AppLifecycleState.inactive` or `paused`). Capture
// detection is not prevention; this is the OS-blessed mitigation only.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const MethodChannel _channel = MethodChannel('com.trosky.app/secure_window');

/// Reference-counted secure-window controller. Call sites must pair
/// [acquire] with exactly one [release]; the [TroskySecureScreen]
/// widget does this automatically.
class SecureWindowController extends Notifier<int> {
  @override
  int build() => 0;

  /// True while any [TroskySecureScreen] is mounted. The shell watches
  /// this to cover the UI with a privacy overlay on background.
  bool get isActive => state > 0;

  Future<void> acquire() async {
    final previous = state;
    state = previous + 1;
    if (previous == 0) {
      await _invoke('on');
    }
  }

  Future<void> release() async {
    if (state <= 0) return;
    final next = state - 1;
    state = next;
    if (next == 0) {
      await _invoke('off');
    }
  }

  Future<void> _invoke(String method) async {
    // Only Android implements the FLAG_SECURE channel. The iOS method
    // call is a no-op on the native side (handled with
    // notImplemented()), so swallow a MissingPluginException on other
    // platforms silently rather than surface it.
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // iOS / web / desktop: secure flag not available.
    } on PlatformException {
      // Native side refused — treat as best-effort; the iOS privacy
      // overlay still fires via [isActive].
    }
  }
}

final secureWindowControllerProvider =
    NotifierProvider<SecureWindowController, int>(SecureWindowController.new);

/// Wrap any content that must not be screenshotted or recorded (QR
/// tickets, OTP entry, password fields, PII edit, MoMo add/pay flows).
/// Idempotent: mounting two SecureScreens at once keeps the window
/// flagged; unmounting one of them does not drop the flag until the
/// other also unmounts.
class TroskySecureScreen extends ConsumerStatefulWidget {
  const TroskySecureScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TroskySecureScreen> createState() => _TroskySecureScreenState();
}

class _TroskySecureScreenState extends ConsumerState<TroskySecureScreen> {
  bool _acquired = false;

  @override
  void initState() {
    super.initState();
    // Delay the acquire to after the first frame so the method channel
    // call does not race with the route transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _acquired = true;
      unawaited(ref.read(secureWindowControllerProvider.notifier).acquire());
    });
  }

  @override
  void dispose() {
    if (_acquired) {
      unawaited(ref.read(secureWindowControllerProvider.notifier).release());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shell-level privacy cover. Mount this at the app root inside the
/// Navigator so it paints on top of every route when the app is
/// backgrounding AND at least one [TroskySecureScreen] is mounted. On
/// iOS this hides sensitive content in the app-switcher snapshot. On
/// Android the FLAG_SECURE blackout already covers it; the overlay is
/// a harmless second belt.
class TroskyPrivacyCover extends ConsumerStatefulWidget {
  const TroskyPrivacyCover({
    super.key,
    required this.child,
    this.coverColor = const Color(0xFF0A1A2B),
  });

  final Widget child;
  final Color coverColor;

  @override
  ConsumerState<TroskyPrivacyCover> createState() => _TroskyPrivacyCoverState();
}

class _TroskyPrivacyCoverState extends ConsumerState<TroskyPrivacyCover>
    with WidgetsBindingObserver {
  AppLifecycleState? _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _lifecycle = state);
  }

  bool get _backgrounding =>
      _lifecycle == AppLifecycleState.inactive ||
      _lifecycle == AppLifecycleState.paused ||
      _lifecycle == AppLifecycleState.hidden;

  @override
  Widget build(BuildContext context) {
    final sensitive = ref.watch(secureWindowControllerProvider) > 0;
    return Stack(
      children: [
        widget.child,
        if (sensitive && _backgrounding)
          Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: widget.coverColor)),
          ),
      ],
    );
  }
}

@visibleForTesting
MethodChannel get secureWindowChannelForTest => _channel;
