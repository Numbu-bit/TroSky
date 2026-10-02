import 'package:flutter/foundation.dart';
import 'package:trosky_api/trosky_api.dart';

/// A journey to search for, filled in before Search (P-02) opens: from a
/// favourite route chip on Home.
@immutable
class SearchPrefill {
  const SearchPrefill({
    required this.originStopId,
    required this.originStopName,
    required this.destinationStopId,
    required this.destinationStopName,
  });

  SearchPrefill.fromFavourite(FavouriteRouteResponse route)
    : originStopId = route.originStopId,
      originStopName = route.originStopName,
      destinationStopId = route.destinationStopId,
      destinationStopName = route.destinationStopName;

  final String originStopId;
  final String originStopName;
  final String destinationStopId;
  final String destinationStopName;
}
