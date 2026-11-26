import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/location_prompt.dart';
import '../../../l10n/app_localizations.dart';
import '../application/home_providers.dart';
import 'widgets/home_header.dart';
import 'widgets/home_map.dart';
import 'widgets/home_sheet.dart';

/// Home (P-01, Figma P5): the navy header, the map, and the sheet with
/// favourite routes. The first tab of the passenger shell.
///
/// The first time it opens without location permission it explains why it
/// wants location, then lets the phone ask; that is the only time it asks
/// by itself.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// How far the sheet reaches up over the map (`marginTop: -8`).
  static const double sheetOverlap = 8;

  /// Resting height of the Home sheet as a fraction of the stack
  /// (map + sheet) — one line of favourites + the handle visible by
  /// default. The user can drag it up to [sheetMaxSize].
  static const double sheetMinSize = 0.32;

  /// Maximum height the sheet drags to — stops short of the header so
  /// the search bar + bell stay reachable.
  static const double sheetMaxSize = 0.86;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _prompted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(locationControllerProvider.select((s) => s.access), (
      _,
      access,
    ) {
      if (access == LocationAccess.notAsked && !_prompted) {
        _prompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _askLocation());
      }
    }, fireImmediately: true);
  }

  Future<void> _askLocation() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final allow = await showLocationPrompt(
      context,
      title: l10n.homeLocationPromptTitle,
      body: l10n.homeLocationPromptBody,
    );
    final controller = ref.read(locationControllerProvider.notifier);
    await (allow ?? false ? controller.allow() : controller.notNow());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Resting height = map height - 8 px overlap;
                  // DraggableScrollableSheet works in fractions of
                  // the stack, so derive both from constraints.
                  final stack = constraints.maxHeight;
                  final restFraction =
                      ((stack - HomeMap.height + HomeScreen.sheetOverlap) /
                              stack)
                          .clamp(0.25, 0.95);
                  final maxFraction = HomeScreen.sheetMaxSize.clamp(
                    restFraction,
                    0.95,
                  );
                  return Stack(
                    children: [
                      // Map pinned at the top (fixed height). The FAB
                      // (My location) + the SOS button inside the map
                      // stay above the sheet's resting height.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: HomeMap.height,
                        child: const HomeMap(),
                      ),
                      DraggableScrollableSheet(
                        initialChildSize: restFraction,
                        minChildSize: restFraction,
                        maxChildSize: maxFraction,
                        // Two snap points: the resting height and the
                        // fully-expanded one. Dragging between them
                        // moves freely; releasing snaps.
                        snap: true,
                        snapSizes: [restFraction, maxFraction],
                        builder: (context, scrollController) =>
                            HomeSheet(scrollController: scrollController),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
