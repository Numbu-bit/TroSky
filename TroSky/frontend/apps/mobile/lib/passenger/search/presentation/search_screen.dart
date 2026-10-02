import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/application/home_providers.dart';
import '../application/search_providers.dart';
import '../domain/journey.dart';
import '../search_prefill.dart';
import 'search_results_screen.dart';
import 'trip_view.dart';
import 'widgets/search_header.dart';

enum _Field { from, to }

/// Search (P-02): where from, where to and when. Not in Figma; built in the
/// style of the Search Results header (decision 19).
///
/// From is "Current location" unless the phone's location can't be used;
/// then it must be a chosen stop. Opened from a Home favourite chip
/// ([prefill]), it fills both stops and searches at once.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.prefill});

  final SearchPrefill? prefill;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _fromText = TextEditingController();
  final _toText = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  SearchOrigin? _origin;
  SearchStop? _destination;
  SearchWhen _when = const SearchWhen.now();
  _Field _active = _Field.to;

  /// The active field's text, once typing paused ([stopSearchDebounce]).
  String _query = '';
  Timer? _debounce;

  bool get _locationRefused =>
      switch (ref.read(locationControllerProvider).access) {
        LocationAccess.denied ||
        LocationAccess.deniedForever ||
        LocationAccess.serviceOff => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() => _focusChanged(_Field.from, _fromFocus));
    _toFocus.addListener(() => _focusChanged(_Field.to, _toFocus));
    final prefill = widget.prefill;
    if (prefill != null) {
      _origin = StopOrigin(
        SearchStop(id: prefill.originStopId, name: prefill.originStopName),
      );
      _destination = SearchStop(
        id: prefill.destinationStopId,
        name: prefill.destinationStopName,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    } else {
      _origin = _locationRefused ? null : const CurrentLocationOrigin();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => (_origin == null ? _fromFocus : _toFocus).requestFocus(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showChoices();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromText.dispose();
    _toText.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  /// The fields show the chosen values.
  void _showChoices() {
    final l10n = AppLocalizations.of(context);
    _fromText.text = switch (_origin) {
      CurrentLocationOrigin() => l10n.searchCurrentLocation,
      StopOrigin(:final stop) => stop.name,
      null => '',
    };
    _toText.text = _destination?.name ?? '';
  }

  void _focusChanged(_Field field, FocusNode node) {
    if (!node.hasFocus) return;
    final text = field == _Field.from ? _fromText : _toText;
    // Typing replaces the chosen value.
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
    setState(() {
      _active = field;
      _query = '';
    });
  }

  void _typed(_Field field, String text) {
    setState(() {
      if (field == _Field.from) {
        _origin = null;
      } else {
        _destination = null;
      }
    });
    _debounce?.cancel();
    _debounce = Timer(stopSearchDebounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  void _chooseOrigin(SearchOrigin origin) {
    setState(() {
      _origin = origin;
      _query = '';
    });
    _showChoices();
    if (_destination == null) {
      _toFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _chooseDestination(SearchStop stop) {
    setState(() {
      _destination = stop;
      _query = '';
    });
    _showChoices();
    if (_origin == null) {
      _fromFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _chooseStop(SearchStop stop) => _active == _Field.from
      ? _chooseOrigin(StopOrigin(stop))
      : _chooseDestination(stop);

  /// Both fields from a favourite or a recent search.
  void _fill(SearchOrigin origin, SearchStop destination) {
    setState(() {
      _origin = origin is CurrentLocationOrigin && _locationRefused
          ? null
          : origin;
      _destination = destination;
      _query = '';
    });
    _showChoices();
    FocusScope.of(context).unfocus();
  }

  bool get _ready {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return false;
    return !(origin is StopOrigin && origin.stop == destination);
  }

  Future<void> _search() async {
    if (!_ready) return;
    final search = JourneySearch(
      origin: _origin!,
      destination: _destination!,
      when: _when,
    );
    FocusScope.of(context).unfocus();
    unawaited(
      ref
          .read(searchHistoryProvider.notifier)
          .add(
            RecentSearch(
              origin: search.origin,
              destination: search.destination,
            ),
          ),
    );
    final outcome = await context.pushNamed<ResultsOutcome>(
      AppRoute.searchResults.name,
      extra: search,
    );
    if (!mounted || outcome != ResultsOutcome.choosePickup) return;
    setState(() => _origin = null);
    _showChoices();
    _fromFocus.requestFocus();
  }

  Future<void> _schedule() async {
    final at = await pickDepartureTime(
      context,
      _when.at,
      now: ref.read(clockProvider)(),
    );
    if (at != null && mounted) setState(() => _when = SearchWhen.at(at));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.lightIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchHeader(
              label: l10n.searchLabel,
              title: l10n.searchTitle,
              backLabel: l10n.backLabel,
              onBack: () => context.pop(),
              child: JourneyPanel(
                vertical: true,
                children: [
                  _fieldCell(
                    field: _Field.from,
                    label: l10n.searchFromLabel,
                    hint: l10n.searchFromHint,
                    dot: TroskyColors.green,
                  ),
                  _fieldCell(
                    field: _Field.to,
                    label: l10n.searchToLabel,
                    hint: l10n.searchToHint,
                    dot: TroskyColors.amber,
                  ),
                ],
              ),
            ),
            Expanded(
              // The Now / Schedule bar scrolls with the list, so a small
              // phone with the keyboard open keeps room for the button.
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: _WhenBar(
                      when: _when,
                      onNow: () =>
                          setState(() => _when = const SearchWhen.now()),
                      onSchedule: _schedule,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      TroskySpacing.s16,
                      TroskySpacing.s12,
                      TroskySpacing.s16,
                      TroskySpacing.s16,
                    ),
                    sliver: SliverList.list(children: _choices(l10n)),
                  ),
                ],
              ),
            ),
            _SearchButton(
              label: l10n.searchButton,
              onPressed: _ready ? _search : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldCell({
    required _Field field,
    required String label,
    required String hint,
    required Color dot,
  }) {
    final active = _active == field;
    final controller = field == _Field.from ? _fromText : _toText;
    return JourneyCell(
      dotColor: dot,
      active: active,
      // The field's own node carries its label (as in TroskyInputField).
      child: MergeSemantics(
        child: Semantics(
          label: label,
          child: TextField(
            key: ValueKey('search-${field.name}'),
            controller: controller,
            focusNode: field == _Field.from ? _fromFocus : _toFocus,
            onChanged: (text) => _typed(field, text),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            cursorColor: TroskyColors.white,
            style: journeyText(active: true),
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: journeyText(active: false),
            ),
          ),
        ),
      ),
    );
  }

  /// What the list below the header offers for the active field.
  List<Widget> _choices(AppLocalizations l10n) {
    if (_query.length >= stopSearchMinLength) {
      return [
        _Heading(l10n.searchStopsHeading),
        _StopResults(query: _query, onChosen: _chooseStop),
      ];
    }
    if (_query.isNotEmpty) return [_Note(l10n.searchTypeMore)];
    final favourites = ref.watch(favouriteRoutesProvider).value ?? const [];
    final recent = ref.watch(searchHistoryProvider).value ?? const [];
    return [
      if (_active == _Field.from) ...[
        _CurrentLocationRow(
          refused: _locationRefused,
          selected: _origin is CurrentLocationOrigin,
          onPressed: () => _chooseOrigin(const CurrentLocationOrigin()),
        ),
        _NearbyStops(onChosen: _chooseStop),
      ],
      if (favourites.isNotEmpty) ...[
        _Heading(l10n.searchFavouritesHeading),
        Wrap(
          spacing: TroskySpacing.s8,
          runSpacing: TroskySpacing.s8,
          children: [
            for (final route in favourites)
              TroskyRouteChip(
                label:
                    route.label ??
                    l10n.homeRoute(
                      route.originStopName,
                      route.destinationStopName,
                    ),
                onPressed: () => _fill(
                  StopOrigin(
                    SearchStop(
                      id: route.originStopId,
                      name: route.originStopName,
                    ),
                  ),
                  SearchStop(
                    id: route.destinationStopId,
                    name: route.destinationStopName,
                  ),
                ),
              ),
          ],
        ),
      ],
      if (recent.isNotEmpty) ...[
        _Heading(l10n.searchRecentHeading),
        for (final search in recent)
          _ChoiceRow(
            icon: TroskyIcons.clock(color: TroskyColors.textSecondary),
            title: l10n.homeRoute(switch (search.origin) {
              CurrentLocationOrigin() => l10n.searchCurrentLocationShort,
              StopOrigin(:final stop) => stop.name,
            }, search.destination.name),
            onPressed: () => _fill(search.origin, search.destination),
          ),
      ],
    ];
  }
}

/// Picks a date (today to 30 days ahead) and then a time, starting from
/// [initial] or [now]; null if either is cancelled.
Future<DateTime?> pickDepartureTime(
  BuildContext context,
  DateTime? initial, {
  required DateTime now,
}) async {
  final start = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: start.isBefore(now) ? now : start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// "Fri 3 Oct · 17:00"
String scheduleLabel(DateTime at) => DateFormat('EEE d MMM · HH:mm').format(at);

/// The "Now" / "Schedule" pills, in the filter-pill bar of P6.
class _WhenBar extends StatelessWidget {
  const _WhenBar({
    required this.when,
    required this.onNow,
    required this.onSchedule,
  });

  final SearchWhen when;
  final VoidCallback onNow;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PillBar(
      children: [
        TroskyFilterPill(
          label: l10n.searchWhenNow,
          selected: when.isNow,
          onPressed: onNow,
        ),
        TroskyFilterPill(
          label: when.at == null
              ? l10n.searchWhenSchedule
              : scheduleLabel(when.at!),
          selected: !when.isNow,
          onPressed: onSchedule,
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: TroskySpacing.s12,
      bottom: TroskySpacing.s8,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TroskyTypography.heading13Bold.copyWith(
          color: TroskyColors.textPrimary,
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TroskySpacing.s12),
    child: Text(
      text,
      style: TroskyTypography.body12Regular.copyWith(
        color: TroskyColors.textSecondary,
      ),
    ),
  );
}

/// A row in the choices list: an icon, a title and an optional detail.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    this.detail,
    this.selected = false,
    this.onPressed,
  });

  final Widget icon;
  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: [title, ?detail].join(', '),
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: icon)),
              const SizedBox(width: TroskySpacing.s12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TroskySpacing.s6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TroskyTypography.body14Medium.copyWith(
                          color: onPressed == null
                              ? TroskyColors.textMuted
                              : TroskyColors.textPrimary,
                        ),
                      ),
                      if (detail case final detail?)
                        Text(
                          detail,
                          style: TroskyTypography.body12Regular.copyWith(
                            color: TroskyColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (selected) TroskyIcons.check(color: TroskyColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationRow extends StatelessWidget {
  const _CurrentLocationRow({
    required this.refused,
    required this.selected,
    required this.onPressed,
  });

  final bool refused;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ChoiceRow(
      icon: TroskyIcons.myLocation(
        color: refused ? TroskyColors.textMuted : TroskyColors.green,
      ),
      title: l10n.searchCurrentLocation,
      detail: refused ? l10n.searchLocationOff : l10n.searchCurrentLocationHint,
      selected: selected,
      onPressed: refused ? null : onPressed,
    );
  }
}

class _NearbyStops extends ConsumerWidget {
  const _NearbyStops({required this.onChosen});

  final ValueChanged<SearchStop> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stops = ref.watch(nearbyStopListProvider).value ?? const [];
    if (stops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.searchNearbyHeading),
        for (final stop in stops)
          _ChoiceRow(
            icon: TroskyIcons.pinSmall(color: TroskyColors.textSecondary),
            title: stop.name,
            detail: l10n.searchStopDistance(
              formatDistance(l10n, stop.distanceM),
            ),
            onPressed: () => onChosen(SearchStop(id: stop.id, name: stop.name)),
          ),
      ],
    );
  }
}

class _StopResults extends ConsumerWidget {
  const _StopResults({required this.query, required this.onChosen});

  final String query;
  final ValueChanged<SearchStop> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(stopSearchProvider(query))
        .when(
          loading: () => Semantics(
            label: l10n.searchStopsHeading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final width in const [160.0, 120.0, 140.0])
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: TroskySpacing.s12),
                    child: TroskySkeleton(width: width, height: 14),
                  ),
              ],
            ),
          ),
          error: (_, _) => Row(
            children: [
              Expanded(child: _Note(l10n.searchStopsError)),
              TroskyTextLink(
                prompt: '',
                action: l10n.offlineRetry,
                onPressed: () => ref.invalidate(stopSearchProvider(query)),
              ),
            ],
          ),
          data: (stops) => stops.isEmpty
              ? _Note(l10n.searchNoStops(query))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final StopResponse stop in stops)
                      _ChoiceRow(
                        icon: TroskyIcons.pinSmall(
                          color: TroskyColors.textSecondary,
                        ),
                        title: stop.name,
                        detail: stop.city,
                        onPressed: () =>
                            onChosen(SearchStop(id: stop.id, name: stop.name)),
                      ),
                  ],
                ),
        );
  }
}

/// The main button on a white bar, above the keyboard and the phone's
/// bottom inset.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom > 0
        ? TroskySpacing.s12
        : MediaQuery.viewPaddingOf(context).bottom + TroskySpacing.s12;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TroskyColors.surface,
        border: Border(
          top: BorderSide(color: TroskyColors.border, width: TroskyBorders.w1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TroskySpacing.s16,
          TroskySpacing.s12,
          TroskySpacing.s16,
          bottom,
        ),
        child: TroskyButton(
          label: label,
          variant: TroskyButtonVariant.primary,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// The white bar of filter pills under the P6 header: 10 × 16 px padding,
/// 8 px apart, a line under it, scrolling sideways when they don't fit.
class PillBar extends StatelessWidget {
  const PillBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TroskyColors.surface,
        border: Border(
          bottom: BorderSide(
            color: TroskyColors.border,
            width: TroskyBorders.w1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TroskySpacing.s16,
          vertical: TroskySpacing.s10,
        ),
        child: Row(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(width: TroskySpacing.s8),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
