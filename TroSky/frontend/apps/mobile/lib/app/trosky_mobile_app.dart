import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';
import 'routes.dart';
import 'server_wake_bar.dart';

class TroskyMobileApp extends ConsumerWidget {
  const TroskyMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TroSky',
      debugShowCheckedModeBanner: false,
      theme: TroskyTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      // Dark status bar icons unless the screen on top declares its own
      // style; the innermost AnnotatedRegion wins. While the server wakes,
      // its bar is on top, under dark icons.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: TroskySystemUi.darkIcons,
        child: ServerWakeBar(child: child!),
      ),
    );
  }
}
