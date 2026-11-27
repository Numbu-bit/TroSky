import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// `GET /users/me/favourite-routes` — the user's pinned commute routes
/// (origin → destination pairs), oldest first per backend contract.
final favouritesListProvider =
    FutureProvider<Result<List<FavouriteRouteResponse>>>((ref) {
      return ref.read(userRepositoryProvider).listFavouriteRoutes();
    });

/// `GET /users/me/favourite-places` — the user's saved places
/// (Home / Work / Custom). Backend sorts newest first by
/// `created_at`; the Places section orders Home → Work → others.
final favouritePlacesProvider =
    FutureProvider<Result<List<FavouritePlaceResponse>>>((ref) {
      return ref.read(userRepositoryProvider).listFavouritePlaces();
    });
