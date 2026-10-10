import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/payment_screen.dart';
import '../../seats/application/seat_providers.dart';
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
    ref.listenManual(heldBookingProvider, (_, next) {
      if (next.value case final booking?) _reopen(booking);
    }, fireImmediately: true);
  }

  /// A booking held before the app closed is reopened on Payment, once.
  void _reopen(BookingResponse booking) {
    if (ref.read(shownBookingsProvider).contains(booking.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only over Home itself, not over a screen opened from it.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (ref.read(shownBookingsProvider).contains(booking.id)) return;
      ref.read(shownBookingsProvider.notifier).add(booking.id);
      context.pushNamed(
        AppRoute.payment.name,
        extra: PaymentArgs(booking: booking, restored: true),
      );
    });
  }

  Future<void> _askLocation() async {
    if (!mounted) return;
    final allow = await showLocationPrompt(context);
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
              child: Stack(
                children: const [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: HomeMap.height,
                    child: HomeMap(),
                  ),
                  Positioned(
                    top: HomeMap.height - HomeScreen.sheetOverlap,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: HomeSheet(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why Home wants location, before the phone's own dialog. True for "Allow
/// location"; false or null (dismissed) for not now.
Future<bool?> showLocationPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    // Over the tab bar too.
    useRootNavigator: true,
    backgroundColor: TroskyColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TroskyRadii.r24),
      ),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s24,
          TroskySpacing.s28,
          TroskySpacing.s24,
          TroskySpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.homeLocationPromptTitle,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              l10n.homeLocationPromptBody,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: l10n.homeLocationAllow,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: l10n.homeLocationNotNow,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}
