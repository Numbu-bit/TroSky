import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_ui/trosky_ui.dart';

import 'debug/design_gallery.dart';

void main() {
  runApp(const TroskyMobileApp());
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _SetupPlaceholder()),
    // Debug builds only: every trosky_ui token and component.
    if (kDebugMode)
      GoRoute(
        path: '/_gallery',
        builder: (context, state) => const DesignGallery(),
      ),
  ],
);

class TroskyMobileApp extends StatelessWidget {
  const TroskyMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TroSky',
      theme: TroskyTheme.light(),
      routerConfig: _router,
    );
  }
}

/// Placeholder until the first screens land.
class _SetupPlaceholder extends StatelessWidget {
  const _SetupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('TroSky Mobile — setup OK'),
            if (kDebugMode)
              TextButton(
                onPressed: () => context.go('/_gallery'),
                child: const Text('Design gallery'),
              ),
          ],
        ),
      ),
    );
  }
}
