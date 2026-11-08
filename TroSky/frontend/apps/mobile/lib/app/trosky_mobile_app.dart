import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';
import 'routes.dart';
import 'server_wake_bar.dart';

class TroskyMobileApp extends ConsumerStatefulWidget {
  const TroskyMobileApp({super.key});

  @override
  ConsumerState<TroskyMobileApp> createState() => _TroskyMobileAppState();
}

class _TroskyMobileAppState extends ConsumerState<TroskyMobileApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Wake the server as soon as the app opens, and when it comes back
    // after a while (decision 33): it answers quicker when it's needed.
    _wake();
    _lifecycle = AppLifecycleListener(onResume: _wake);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _wake() => unawaited(ref.read(serverWakeProvider)?.ready());

  @override
  Widget build(BuildContext context) {
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
