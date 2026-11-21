import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rate_banner_cache.dart';

/// The shared [RateBannerCache] instance. Keep-alive so the Hive box
/// stays open across tab switches.
final rateBannerCacheProvider = Provider<RateBannerCache>(
  (_) => RateBannerCache(),
);

/// All dismissal timestamps keyed by booking id. Invalidated after each
/// `dismiss` so the banner list rebuilds.
final rateBannerDismissalsProvider = FutureProvider<Map<String, DateTime>>((
  ref,
) async {
  return ref.read(rateBannerCacheProvider).allDismissals();
});
