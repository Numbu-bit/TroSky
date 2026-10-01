import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts under the family names the TroSky text styles ask
/// for, so golden images show real type instead of the test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFamily(
    'packages/trosky_ui/PlusJakartaSans',
    'assets/fonts/plus_jakarta_sans',
  );
  await _loadFamily('packages/trosky_ui/Inter', 'assets/fonts/inter');
  await testMain();
}

Future<void> _loadFamily(String family, String directory) async {
  final loader = FontLoader(family);
  final files = Directory(
    directory,
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.ttf'));
  for (final file in files) {
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}
