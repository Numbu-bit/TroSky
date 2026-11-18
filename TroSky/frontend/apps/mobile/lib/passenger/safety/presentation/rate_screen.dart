// P-14 Rate your trip. Driver avatar + name on top, five-star picker,
// optional comment, submit. Rating is final after submit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/safety_args.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.args});
  final RateArgs args;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int _stars = 0;
  final TextEditingController _comment = TextEditingController();
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('rate_opened', {'from': 'trips_banner'}));
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final comment = _comment.text.trim().isEmpty ? null : _comment.text.trim();
    ref
        .read(telemetryProvider)
        .emit(
          TelemetryEvent('rate_submitted', {
            'stars': _stars,
            'has_comment': comment != null,
          }),
        );
    final result = await ref
        .read(bookingRepositoryProvider)
        .rate(
          widget.args.booking.id,
          RateBookingRequest(score: _stars, comment: comment),
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.rateThanks)));
        Navigator.of(context).maybePop();
      case Err(:final failure):
        setState(() {
          _submitting = false;
          _failure = failure.code;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The booking summary doesn't carry the driver name; use a fallback
    // until Trip Details (P-04) fetched it. When Trip Details is wired
    // through to this screen later, swap this for `trip.driver?.fullName`.
    final driverName = l10n.rateDriverFallback;
    return AnnotatedRegion(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        appBar: AppBar(
          title: Text(l10n.rateTitle),
          backgroundColor: TroskyColors.surface,
          foregroundColor: TroskyColors.ink,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TroskySpacing.s16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: TroskyColors.background,
                    child: Text(
                      driverName.substring(0, 1).toUpperCase(),
                      style: TroskyTypography.heading22ExtraBold.copyWith(
                        color: TroskyColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: TroskySpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: TroskyTypography.heading18Bold.copyWith(
                            color: TroskyColors.ink,
                          ),
                        ),
                        Text(
                          widget.args.booking.trip?.routeName ??
                              l10n.rateRouteFallback,
                          style: TroskyTypography.body12Regular.copyWith(
                            color: TroskyColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TroskySpacing.s24),
              Semantics(
                slider: true,
                value: l10n.rateStarsSemantic(_stars),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        iconSize: 44,
                        onPressed: () => setState(() => _stars = i),
                        icon: Icon(
                          i <= _stars ? Icons.star : Icons.star_border,
                          color: i <= _stars
                              ? TroskyColors.mtnYellow
                              : TroskyColors.textSecondary,
                        ),
                        tooltip: l10n.rateStarTooltip(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              TextField(
                controller: _comment,
                maxLength: 280,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.rateCommentHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_failure != null) ...[
                const SizedBox(height: TroskySpacing.s8),
                Text(
                  l10n.rateSubmitFailure,
                  style: TroskyTypography.body14Regular.copyWith(
                    color: TroskyColors.red,
                  ),
                ),
              ],
              const SizedBox(height: TroskySpacing.s16),
              TroskyButton(
                label: l10n.rateSubmit,
                variant: TroskyButtonVariant.primary,
                onPressed: (_stars > 0 && !_submitting) ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
