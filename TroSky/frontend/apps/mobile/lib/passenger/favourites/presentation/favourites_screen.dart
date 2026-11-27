// P-26 Favourites.
//
// Two sections (step 21/close-stubs-C):
//   - Places (primary): Home, Work, and custom places via
//     `/users/me/favourite-places`. Home/Work rows switch between an
//     "Add Home" / "Add Work" affordance and a filled row with an
//     overflow (Edit / Delete, where applicable).
//   - Saved routes (secondary): the older `/favourite-routes` list.
//     Kept unchanged so users with pinned routes don't lose them.
//
// Add is driven by a modal sheet with a kind radio + label field +
// a minimal stop picker that reuses `routeRepositoryProvider
// .searchStops`. Home/Work are backend-capped at one each; setting
// Home a second time replaces the earlier one server-side.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
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

  Future<void> _deleteRoute(FavouriteRouteResponse f) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.favouriteDeleteConfirmTitle,
      body: l10n.favouriteDeleteConfirmBody,
      destructiveLabel: l10n.favouriteDelete,
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

  Future<void> _deletePlace(FavouritePlaceResponse place) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.favouritePlaceDeleteConfirmTitle,
      body: l10n.favouritePlaceDeleteConfirmBody,
      destructiveLabel: l10n.favouritePlaceDeleteAction,
    );
    if (confirmed != true) return;
    final result = await ref
        .read(userRepositoryProvider)
        .deleteFavouritePlace(place.id);
    if (!mounted) return;
    if (result case Err()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.favouritePlaceDeleteFailed)));
      return;
    }
    ref
        .read(telemetryProvider)
        .emit(
          TelemetryEvent('favourite_place_deleted', {'kind': place.kind.wire}),
        );
    ref.invalidate(favouritePlacesProvider);
  }

  Future<void> _addPlace({FavouritePlaceKind? kind}) async {
    final result = await showModalBottomSheet<FavouritePlaceResponse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TroskyColors.surface,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddPlaceSheet(initialKind: kind ?? FavouritePlaceKind.custom),
      ),
    );
    if (!mounted || result == null) return;
    ref
        .read(telemetryProvider)
        .emit(
          TelemetryEvent('favourite_place_added', {'kind': result.kind.wire}),
        );
    if (result.kind == FavouritePlaceKind.home) {
      ref.read(telemetryProvider).emit(TelemetryEvent('favourite_home_set'));
    } else if (result.kind == FavouritePlaceKind.work) {
      ref.read(telemetryProvider).emit(TelemetryEvent('favourite_work_set'));
    }
    ref.invalidate(favouritePlacesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placesAsync = ref.watch(favouritePlacesProvider);
    final routesAsync = ref.watch(favouritesListProvider);
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
        floatingActionButton: FloatingActionButton(
          tooltip: l10n.favouritePlaceAddFabTooltip,
          onPressed: () => _addPlace(),
          backgroundColor: TroskyColors.navy,
          foregroundColor: TroskyColors.surface,
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(favouritePlacesProvider)
                ..invalidate(favouritesListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                _PlacesSection(
                  async: placesAsync,
                  onAdd: _addPlace,
                  onDelete: _deletePlace,
                ),
                const SizedBox(height: TroskySpacing.s24),
                _RoutesSection(async: routesAsync, onDelete: _deleteRoute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String destructiveLabel,
}) => showModalBottomSheet<bool>(
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
          Text(title, style: TroskyTypography.heading22ExtraBold),
          const SizedBox(height: TroskySpacing.s8),
          Text(body, style: TroskyTypography.body14Regular),
          const SizedBox(height: TroskySpacing.s16),
          TroskyButton(
            label: destructiveLabel,
            variant: TroskyButtonVariant.danger,
            onPressed: () => Navigator.of(sheetCtx).pop(true),
          ),
        ],
      ),
    ),
  ),
);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TroskySpacing.s8),
      child: Text(
        label,
        style: TroskyTypography.body12SemiBoldH133.copyWith(
          color: TroskyColors.textSecondary,
        ),
      ),
    );
  }
}

class _PlacesSection extends StatelessWidget {
  const _PlacesSection({
    required this.async,
    required this.onAdd,
    required this.onDelete,
  });

  final AsyncValue<Result<List<FavouritePlaceResponse>>> async;
  final void Function({FavouritePlaceKind? kind}) onAdd;
  final Future<void> Function(FavouritePlaceResponse place) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: l10n.favouritesPlacesHeader),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: TroskySpacing.s16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(l10n.favouriteDeleteFailed),
          data: (result) => switch (result) {
            Err() => Text(l10n.favouriteDeleteFailed),
            Ok(:final value) => _PlacesList(
              places: value,
              onAdd: onAdd,
              onDelete: onDelete,
            ),
          },
        ),
      ],
    );
  }
}

class _PlacesList extends StatelessWidget {
  const _PlacesList({
    required this.places,
    required this.onAdd,
    required this.onDelete,
  });

  final List<FavouritePlaceResponse> places;
  final void Function({FavouritePlaceKind? kind}) onAdd;
  final Future<void> Function(FavouritePlaceResponse place) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = places.where((p) => p.kind == FavouritePlaceKind.home).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final work = places.where((p) => p.kind == FavouritePlaceKind.work).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final custom =
        places.where((p) => p.kind == FavouritePlaceKind.custom).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: [
        home.isEmpty
            ? _AddKindRow(
                kind: FavouritePlaceKind.home,
                label: l10n.favouritePlaceAddHome,
                onTap: () => onAdd(kind: FavouritePlaceKind.home),
              )
            : _PlaceRow(place: home.first, onDelete: onDelete),
        const SizedBox(height: TroskySpacing.s8),
        work.isEmpty
            ? _AddKindRow(
                kind: FavouritePlaceKind.work,
                label: l10n.favouritePlaceAddWork,
                onTap: () => onAdd(kind: FavouritePlaceKind.work),
              )
            : _PlaceRow(place: work.first, onDelete: onDelete),
        for (final place in custom) ...[
          const SizedBox(height: TroskySpacing.s8),
          _PlaceRow(place: place, onDelete: onDelete),
        ],
      ],
    );
  }
}

class _AddKindRow extends StatelessWidget {
  const _AddKindRow({
    required this.kind,
    required this.label,
    required this.onTap,
  });
  final FavouritePlaceKind kind;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TroskyRadii.r12),
      child: Container(
        padding: const EdgeInsets.all(TroskySpacing.s12),
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
          border: Border.all(color: TroskyColors.dividerSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: TroskySpacing.s12),
            Expanded(
              child: Text(
                label,
                style: TroskyTypography.body14SemiBold.copyWith(
                  color: TroskyColors.navy,
                ),
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              color: TroskyColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.onDelete});
  final FavouritePlaceResponse place;
  final Future<void> Function(FavouritePlaceResponse) onDelete;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(place.kind);
    final subtitle = place.stopName ?? '—';
    return Semantics(
      label: 'Place, ${place.label}, $subtitle',
      child: Container(
        padding: const EdgeInsets.all(TroskySpacing.s12),
        decoration: BoxDecoration(
          color: TroskyColors.surface,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: TroskySpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.label,
                    style: TroskyTypography.body14SemiBold.copyWith(
                      color: TroskyColors.ink,
                    ),
                  ),
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
              onPressed: () => unawaited(onDelete(place)),
              tooltip: AppLocalizations.of(context).favouritePlaceDeleteAction,
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _iconFor(FavouritePlaceKind kind) => switch (kind) {
  FavouritePlaceKind.home => (Icons.home_outlined, TroskyColors.navy),
  FavouritePlaceKind.work => (Icons.work_outline, TroskyColors.success),
  FavouritePlaceKind.custom => (Icons.star_outline, TroskyColors.amber),
};

class _RoutesSection extends StatelessWidget {
  const _RoutesSection({required this.async, required this.onDelete});
  final AsyncValue<Result<List<FavouriteRouteResponse>>> async;
  final Future<void> Function(FavouriteRouteResponse) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: l10n.favouritesRoutesHeader),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: TroskySpacing.s12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(l10n.favouriteDeleteFailed),
          data: (result) => switch (result) {
            Err() => Text(l10n.favouriteDeleteFailed),
            Ok(:final value) when value.isEmpty => _RoutesEmpty(),
            Ok(:final value) => Column(
              children: [
                for (final f in value) ...[
                  _RouteRow(fav: f, onDelete: () => unawaited(onDelete(f))),
                  const SizedBox(height: TroskySpacing.s8),
                ],
              ],
            ),
          },
        ),
      ],
    );
  }
}

class _RoutesEmpty extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s12),
      child: Column(
        children: [
          Text(
            l10n.favouritesHowToAdd,
            textAlign: TextAlign.center,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: TroskySpacing.s8),
          TextButton(
            onPressed: () {
              ref
                  .read(telemetryProvider)
                  .emit(TelemetryEvent('favourites_empty_add_tapped'));
              context.pushNamed(AppRoute.search.name);
            },
            child: Text(l10n.favouritesEmptyAddCta),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.fav, required this.onDelete});
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

/// Add-place sheet: kind radio + label field + a minimal stop
/// autocomplete that reuses `routeRepositoryProvider.searchStops`.
class _AddPlaceSheet extends ConsumerStatefulWidget {
  const _AddPlaceSheet({required this.initialKind});
  final FavouritePlaceKind initialKind;

  @override
  ConsumerState<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends ConsumerState<_AddPlaceSheet> {
  late FavouritePlaceKind _kind = widget.initialKind;
  final _label = TextEditingController();
  final _stopQuery = TextEditingController();
  StopResponse? _stop;
  bool _submitting = false;
  Timer? _debounce;
  List<StopResponse> _suggestions = const [];

  @override
  void dispose() {
    _label.dispose();
    _stopQuery.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (q.trim().length < 2) {
        setState(() => _suggestions = const []);
        return;
      }
      final r = await ref
          .read(routeRepositoryProvider)
          .searchStops(q.trim(), limit: 6);
      if (!mounted) return;
      setState(() {
        _suggestions = switch (r) {
          Ok(:final value) => value,
          Err() => const [],
        };
      });
    });
  }

  String _defaultLabel(AppLocalizations l10n) => switch (_kind) {
    FavouritePlaceKind.home => l10n.favouritePlaceHome,
    FavouritePlaceKind.work => l10n.favouritePlaceWork,
    FavouritePlaceKind.custom => '',
  };

  bool get _valid {
    if (_stop == null) return false;
    if (_kind == FavouritePlaceKind.custom && _label.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_valid) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);
    final label = switch (_kind) {
      FavouritePlaceKind.custom => _label.text.trim(),
      _ => _label.text.trim().isEmpty ? null : _label.text.trim(),
    };
    final result = await ref
        .read(userRepositoryProvider)
        .addFavouritePlace(
          FavouritePlaceCreateRequest(
            kind: _kind,
            label: label,
            stopId: _stop!.id,
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err():
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.favouritePlaceSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TroskySpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.favouritePlaceAddTitle,
              style: TroskyTypography.heading22ExtraBold,
            ),
            const SizedBox(height: TroskySpacing.s12),
            SegmentedButton<FavouritePlaceKind>(
              segments: [
                ButtonSegment(
                  value: FavouritePlaceKind.home,
                  label: Text(l10n.favouritePlaceHome),
                  icon: const Icon(Icons.home_outlined),
                ),
                ButtonSegment(
                  value: FavouritePlaceKind.work,
                  label: Text(l10n.favouritePlaceWork),
                  icon: const Icon(Icons.work_outline),
                ),
                ButtonSegment(
                  value: FavouritePlaceKind.custom,
                  label: Text(l10n.favouritePlaceKindCustom),
                  icon: const Icon(Icons.star_outline),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                if (_kind != FavouritePlaceKind.custom &&
                    _label.text.trim().isEmpty) {
                  _label.text = _defaultLabel(l10n);
                }
              }),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TextField(
              controller: _label,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.favouritePlaceLabelLabel,
                border: const OutlineInputBorder(),
                hintText: _defaultLabel(l10n),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TroskySpacing.s8),
            TextField(
              controller: _stopQuery,
              decoration: InputDecoration(
                labelText: l10n.favouritePlaceStopLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              onChanged: _onQuery,
            ),
            if (_stop case final s?)
              Padding(
                padding: const EdgeInsets.only(top: TroskySpacing.s4),
                child: Text(
                  s.name,
                  style: TroskyTypography.body12SemiBoldH133.copyWith(
                    color: TroskyColors.success,
                  ),
                ),
              ),
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: TroskyColors.background,
                  borderRadius: BorderRadius.circular(TroskyRadii.r8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.name),
                      onTap: () {
                        setState(() {
                          _stop = s;
                          _stopQuery.text = s.name;
                          _suggestions = const [];
                        });
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: TroskySpacing.s16),
            TroskyButton(
              label: l10n.favouritePlaceSaveCta,
              variant: TroskyButtonVariant.primary,
              onPressed: (_valid && !_submitting) ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
