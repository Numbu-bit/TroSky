// P-26 Favourites. Adapted to the backend's `favourite-routes` shape:
// each entry is an origin → destination pair with an optional label.
// Add lives in Search (tap the heart on a result); P-26 here is list +
// delete only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/favourites_providers.dart';

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  bool _openedTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedTracked) return;
    _openedTracked = true;
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('favourites_opened', const {'from': 'profile'}));
  }

  Future<void> _delete(FavouriteRouteResponse f) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TroskyColors.surface,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TroskySpacing.s20,
            TroskySpacing.s8,
            TroskySpacing.s20,
            TroskySpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.favouriteDeleteConfirmTitle,
                style: TroskyTypography.heading22ExtraBold,
              ),
              const SizedBox(height: TroskySpacing.s8),
              Text(
                l10n.favouriteDeleteConfirmBody,
                style: TroskyTypography.body14Regular,
              ),
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.favouriteDelete,
                variant: TroskyButtonVariant.danger,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final result = await ref
        .read(userRepositoryProvider)
        .deleteFavouriteRoute(f.id);
    if (!mounted) return;
    if (result case Err()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favouriteDeleteFailed)));
      return;
    }
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('favourite_deleted', const {'kind': 'route'}));
    ref.invalidate(favouritesListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncList = ref.watch(favouritesListProvider);
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.favouritesTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: asyncList.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                _Error(onRetry: () => ref.invalidate(favouritesListProvider)),
            data: (result) => switch (result) {
              Err() => _Error(
                onRetry: () => ref.invalidate(favouritesListProvider),
              ),
              Ok(:final value) when value.isEmpty => const _EmptyState(),
              Ok(:final value) => ListView.separated(
                padding: const EdgeInsets.all(TroskySpacing.s16),
                itemBuilder: (_, i) =>
                    _Row(fav: value[i], onDelete: () => _delete(value[i])),
                separatorBuilder: (_, _) =>
                    const SizedBox(height: TroskySpacing.s8),
                itemCount: value.length,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(TroskySpacing.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite_outline,
            size: 48,
            color: TroskyColors.textSecondary,
          ),
          const SizedBox(height: TroskySpacing.s12),
          Text(
            l10n.favouritesEmpty,
            textAlign: TextAlign.center,
            style: TroskyTypography.body14SemiBold.copyWith(
              color: TroskyColors.ink,
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          Text(
            l10n.favouritesHowToAdd,
            textAlign: TextAlign.center,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.fav, required this.onDelete});
  final FavouriteRouteResponse fav;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = fav.label?.isNotEmpty == true
        ? fav.label!
        : l10n.favouriteRow(fav.originStopName, fav.destinationStopName);
    final subtitle = fav.label?.isNotEmpty == true
        ? l10n.favouriteRow(fav.originStopName, fav.destinationStopName)
        : null;
    return Semantics(
      label: 'Favourite route, $title',
      child: Container(
        padding: const EdgeInsets.all(TroskySpacing.s12),
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: TroskyColors.red, size: 20),
            const SizedBox(width: TroskySpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TroskyTypography.body14SemiBold.copyWith(
                      color: TroskyColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TroskyTypography.body12Regular.copyWith(
                          color: TroskyColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: l10n.favouriteDelete,
            ),
          ],
        ),
      ),
    );
  }
}
