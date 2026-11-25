// Analytics emission boundary for the passenger app. Introduced Step
// 16, hardened for C5 of the 21 Nov 2026 pre-launch audit.
//
// The schema in [_telemetrySchema] is the contract between emit sites
// and the sink: every event name that leaves the app is listed here,
// and every payload key the sanitiser will carry is listed next to it.
// Events outside the schema are dropped entirely. Keys outside the
// schema for a known event are dropped. Values that are not bounded
// scalars are dropped. The dropped data never reaches a sink, is never
// printed with its rejected value, and is only surfaced by a debug-mode
// `assert` message that names the event and the offending key — never
// the rejected value.
//
// Legacy substring-key filter kept as a defence-in-depth fallback for a
// future call site that bypasses the schema. It is not sufficient on
// its own — innocent keys like `user_id` can carry PII and safe keys
// like `platform` get stripped by regex. Adding a new event is the
// correct way to extend coverage, not loosening the filter.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'telemetry.g.dart';

/// One analytics event: a snake_case name + a map of scalar params.
/// Consumers call [sanitised] to get the payload that is safe to emit
/// (which may be null when the event is not in [_telemetrySchema]).
class TelemetryEvent {
  TelemetryEvent(this.name, [Map<String, Object?>? params])
    : params = Map.unmodifiable(params ?? const <String, Object?>{});

  final String name;
  final Map<String, Object?> params;

  /// The payload safe to hand to a sink, or null when [name] is not in
  /// the schema. Call sites MUST check for null before emitting.
  ///
  /// Guarantees for a non-null return:
  ///  - name is in [_telemetrySchema].
  ///  - every key is in that event's allow-list.
  ///  - every value is a bounded scalar (bool, int, double, string ≤
  ///    64 chars) that also survives the legacy substring key filter.
  ///  - the returned map is unmodifiable.
  Map<String, Object?>? get sanitised {
    final allowedKeys = _telemetrySchema[name];
    if (allowedKeys == null) {
      assert(() {
        developer.log(
          'dropped: event not in schema',
          name: 'trosky.telemetry.rejected',
          error: name,
        );
        return true;
      }());
      return null;
    }
    final clean = <String, Object?>{};
    for (final entry in params.entries) {
      final key = entry.key;
      if (!allowedKeys.contains(key)) {
        assert(() {
          developer.log(
            'dropped: key not in schema',
            name: 'trosky.telemetry.rejected',
            error: '$name/$key',
          );
          return true;
        }());
        continue;
      }
      if (_legacyBannedKeys.hasMatch(key)) {
        assert(() {
          developer.log(
            'dropped: legacy banned key',
            name: 'trosky.telemetry.rejected',
            error: '$name/$key',
          );
          return true;
        }());
        continue;
      }
      if (!_isSafeValue(entry.value)) {
        assert(() {
          developer.log(
            'dropped: value is not a bounded scalar',
            name: 'trosky.telemetry.rejected',
            error: '$name/$key',
          );
          return true;
        }());
        continue;
      }
      clean[key] = entry.value;
    }
    return Map.unmodifiable(clean);
  }

  /// Defensive substring filter kept as a safety net for future call
  /// sites that mint a payload outside the schema path. The schema is
  /// the primary guard; this is secondary.
  static final RegExp _legacyBannedKeys = RegExp(
    r'token|phone|email|lat|lng|coord|address|password|otp|secret',
    caseSensitive: false,
  );

  static bool _isSafeValue(Object? value) {
    if (value == null || value is bool) return true;
    if (value is int) return value >= -999999 && value <= 999999;
    if (value is double) {
      if (!value.isFinite) return false;
      return value >= -999999 && value <= 999999;
    }
    if (value is String) return value.length <= 64;
    return false;
  }
}

/// Where emit sites hand events to. One method, so a stub for tests is
/// three lines. Sinks are responsible for calling [TelemetryEvent.sanitised]
/// and dropping the event when it returns null.
abstract interface class TelemetryService {
  void emit(TelemetryEvent event);
}

/// Dev stub: prints via `dart:developer.log` under the "trosky.telemetry"
/// channel. Swap for PostHog / Amplitude later.
class ConsoleTelemetryService implements TelemetryService {
  const ConsoleTelemetryService();

  @override
  void emit(TelemetryEvent event) {
    final payload = event.sanitised;
    if (payload == null) return;
    developer.log('${event.name} $payload', name: 'trosky.telemetry');
  }
}

@Riverpod(keepAlive: true)
TelemetryService telemetry(Ref ref) => const ConsoleTelemetryService();

/// The canonical list of analytics events the passenger app may emit.
/// Keep alphabetical within each section. Adding a new emit site means
/// adding the event name and its allowed keys here first.
///
/// Values are deliberately typed as [Set<String>] rather than a richer
/// schema object — richer schema per-field types are enforced at runtime
/// in [TelemetryEvent._isSafeValue]. The set only decides which keys
/// are allowed through; values still have to pass the scalar/bounded
/// check.
///
/// To keep the surface small, intentionally dropped events are tracked
/// here too (as empty entries in [_droppedEventNames]) so future reviews
/// catch regressions where a drop becomes a leak.
const Map<String, Set<String>> _telemetrySchema = {
  // Account
  'account_delete_opened': {},
  'account_delete_confirmed': {},
  'account_delete_failed': {'reason'},
  'pii_edit_opened': {'field'},
  'pii_edit_submitted': {'field'},
  'pii_edit_failed': {'field', 'reason'},
  'profile_opened': {},
  'profile_section_tapped': {'section'},
  'profile_signout_tapped': {},
  'profile_language_opened': {},
  'profile_about_opened': {},
  'profile_report_problem_opened': {},
  'about_terms_tapped': {},
  'about_privacy_tapped': {},
  'about_licenses_tapped': {},
  'password_reset_requested': {},
  'password_reset_completed': {},

  // Favourites
  'favourites_opened': {'from'},
  'favourite_deleted': {'kind'},
  'favourites_empty_add_tapped': {},

  // Home
  'home_bell_tapped': {},
  'home_sos_tapped': {},

  // Notifications
  'notifications_opened': {'from'},
  'notifications_tab_changed': {'tab'},
  'notification_mark_all_read': {},
  'notification_tapped': {'type', 'has_deep_link'},
  'notification_unroutable': {'type'},
  'notification_pref_toggled': {'category', 'enabled'},

  // Safety
  'rate_opened': {'from'},
  'rate_star_selected': {'stars'},
  'rate_submitted': {'stars', 'has_comment'},
  'rate_dismissed': {},
  'report_opened': {},
  'report_category_picked': {'category'},
  'report_submitted': {'category', 'has_photos'},
  'report_submit_failed': {'reason'},
  'sos_opened': {'from'},
  'sos_hold_started': {},
  'sos_hold_cancelled': {},
  'sos_sent': {'category', 'location_attached'},
  'sos_send_failed': {'reason'},
  'sos_marked_safe': {},
  'sos_call_911_tapped': {},

  // Search
  'search_favourite_chip_tapped': {'kind'},

  // Tracking
  'track_trip_opened': {},
  'track_trip_ws_fallback_to_poll': {'after_seconds'},
  'track_trip_ws_connected': {},
  'track_trip_recenter_tapped': {},
  'track_trip_share_tapped': {},
  'track_trip_sos_tapped': {},
  'track_trip_call_driver_tapped': {},
  'track_trip_message_driver_tapped': {},

  // Tickets
  'ticket_fetch_failed': {'reason'},
  'ticket_opened': {
    'booking_status',
    'seat_index',
    'seat_count',
    'is_first_open',
  },
  'ticket_saved': {'seat_index'},
  'ticket_shared': {'seat_index'},
  'ticket_swiped': {'from', 'to'},

  // Trips
  'trip_details_opened': {'from'},
  'trip_call_driver_tapped': {},
  'trip_message_driver_tapped': {},
  'trip_track_tapped': {},
  'trip_cancel_tapped': {},
  'rate_banner_shown': {'booking_id_hash'},
  'rate_banner_tapped': {'booking_id_hash'},
  'rate_banner_dismissed': {'booking_id_hash'},

  // Wallet
  'wallet_opened': {'from'},
  'wallet_filter_changed': {'type'},
  'wallet_transaction_opened': {'type'},
  'wallet_transactions_expanded': {},
  'wallet_transactions_collapsed': {},
  'wallet_payment_method_tapped': {'type'},
  'wallet_payment_method_set_default': {'type'},
  'wallet_payment_method_removed': {'type'},
  'wallet_add_method_opened': {},
  'wallet_add_method_submitted': {'type'},
  'wallet_topup_opened': {},
  'wallet_topup_submitted': {'amount'},
  'wallet_topup_preset_picked': {'amount'},
  'wallet_topup_success': {},
  'wallet_topup_failed': {'reason'},
};

/// Events deliberately dropped from the sink. Listed here so a future
/// reviewer can tell a schema gap ("missing from allow-list") apart
/// from an intentional drop. Empty today — every live emit site is
/// either in the schema above or has been removed.
@visibleForTesting
const Set<String> droppedEventNames = {};

/// Read-only view of the schema for tests. Not exported through the
/// library barrel: schema shape is internal to this file.
@visibleForTesting
Map<String, Set<String>> get telemetrySchemaForTest => _telemetrySchema;
