import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../l10n/app_localizations.dart';

/// The passenger app's frame: the tabs Home, Trips, Wallet and Profile
/// (decision 12), each keeping its own screen and history.
///
/// Android back on another tab returns to Home; on Home it leaves the app.
class PassengerShell extends StatelessWidget {
  const PassengerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const int homeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onHome = shell.currentIndex == homeIndex;
    return PopScope(
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(homeIndex);
      },
      child: Scaffold(
        body: shell,
        // The white bar sits on the phone's navigation bar: dark icons
        // there, whatever the screen above uses for the status bar.
        bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
          value: TroskySystemUi.darkIcons,
          child: TroskyTabBar(
            items: [
              TroskyTabItem(emoji: '🏠', label: l10n.tabHome),
              TroskyTabItem(emoji: '🗺️', label: l10n.tabTrips),
              TroskyTabItem(emoji: '💰', label: l10n.tabWallet),
              TroskyTabItem(emoji: '👤', label: l10n.tabProfile),
            ],
            currentIndex: shell.currentIndex,
            // Tapping the open tab again goes back to its first screen.
            onSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
