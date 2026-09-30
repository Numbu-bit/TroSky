import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_ui/trosky_ui.dart';

import 'app/trosky_mobile_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars; each screen picks the
  // icon colour.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  // Decode the splash logo while the native launch screen is still up, so
  // the logo card never draws empty.
  await _precache(
    const AssetImage(TroskyLogo.brightAsset, package: TroskyLogo.package),
  );
  runApp(const ProviderScope(child: TroskyMobileApp()));
}

/// Loads [image] into the image cache. A failure is ignored: the image then
/// loads when it is first shown.
Future<void> _precache(ImageProvider image) {
  final loaded = Completer<void>();
  final stream = image.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void done() {
    if (loaded.isCompleted) return;
    loaded.complete();
    // The image cache keeps the decoded image after the listener goes.
    stream.removeListener(listener);
  }

  listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
  stream.addListener(listener);
  return loaded.future;
}
