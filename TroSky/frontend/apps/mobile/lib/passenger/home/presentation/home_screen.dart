import 'dart:async';

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

  /// Smallest fraction of the stack the sheet collapses to. Set to show
  /// just the handle + "Favourite Routes" header + one line of chips
  /// (or the empty-state text) without any trailing white space.
  static const double sheetCollapsedSize = 0.17;

  /// Maximum height the sheet drags to — stops short of the header so
  /// the search bar + bell stay reachable.
  static const double sheetMaxSize = 0.86;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _prompted = false;
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final ValueNotifier<double> _sheetFraction = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _sheet.addListener(() {
      if (!_sheet.isAttached) return;
      // DraggableScrollableController fires inside performLayout. If
      // we published the new value synchronously the map's
      // ValueListenableBuilder would mark its subtree dirty mid-
      // layout and LayoutBuilder would refuse the rebuild
      // (`slot == null`). Microtask-queue the publish so the listener
      // settles after layout finishes.
      final size = _sheet.size;
      scheduleMicrotask(() {
        if (mounted && _sheetFraction.value != size) {
          _sheetFraction.value = size;
        }
      });
    });
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

  @override
  void dispose() {
    _sheet.dispose();
    _sheetFraction.dispose();
    super.dispose();
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
              child: _HomeStack(sheet: _sheet, sheetFraction: _sheetFraction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolates the draggable-sheet subtree so its rebuilds don't race the
/// ancestor layout. Uses `MediaQuery.sizeOf(context)` (which doesn't
/// depend on an enclosing LayoutBuilder) to derive the resting
/// fraction from the design-system 220 px map.
class _HomeStack extends StatelessWidget {
  const _HomeStack({required this.sheet, required this.sheetFraction});

  final DraggableScrollableController sheet;
  final ValueNotifier<double> sheetFraction;

  @override
  Widget build(BuildContext context) {
    // Approximate stack height: full window minus system insets and
    // the navy Home header (~148 px) and the bottom tab bar (60 +
    // viewPadding.bottom). Close enough for computing the resting
    // fraction; exact map growth comes from the ValueListenableBuilder
    // below using the published sheet.size directly.
    final media = MediaQuery.of(context);
    final stack =
        (media.size.height -
                media.padding.top -
                148 -
                60 -
                media.viewPadding.bottom)
            .clamp(400.0, media.size.height);
    final restFraction =
        ((stack - HomeMap.height + HomeScreen.sheetOverlap) / stack).clamp(
          HomeScreen.sheetCollapsedSize,
          0.95,
        );
    final maxFraction = HomeScreen.sheetMaxSize.clamp(restFraction, 0.95);
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: sheetFraction,
              builder: (context, fraction, _) {
                final effective = fraction == 0 ? restFraction : fraction;
                final mapHeight =
                    (stack - (stack * effective) + HomeScreen.sheetOverlap)
                        .clamp(HomeMap.height, stack);
                return SizedBox(
                  width: double.infinity,
                  height: mapHeight,
                  child: const HomeMap(),
                );
              },
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: sheet,
          initialChildSize: restFraction,
          minChildSize: HomeScreen.sheetCollapsedSize,
          maxChildSize: maxFraction,
          // Three snap points — collapsed (handle + header + 1 line,
          // no white space), resting (initial), expanded (max).
          snap: true,
          snapSizes: [HomeScreen.sheetCollapsedSize, restFraction, maxFraction],
          builder: (context, scrollController) =>
              HomeSheet(scrollController: scrollController),
        ),
      ],
    );
  }
}
