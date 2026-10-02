import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/journey.dart';

/// The passenger's last searches, newest first, kept on the phone
/// (decision 19).
abstract interface class SearchHistoryStore {
  static const int max = 5;

  Future<List<RecentSearch>> read();

  Future<void> write(List<RecentSearch> searches);
}

/// [SearchHistoryStore] in shared preferences.
class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  SharedPreferencesSearchHistoryStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const String key = 'search.recent';

  @override
  Future<List<RecentSearch>> read() async {
    final raw = await _preferences.getString(key);
    if (raw == null) return const [];
    try {
      return [
        for (final entry in jsonDecode(raw) as List)
          RecentSearch.fromJson((entry as Map).cast()),
      ];
    } on Object {
      // An older or damaged entry is just no history.
      return const [];
    }
  }

  @override
  Future<void> write(List<RecentSearch> searches) => _preferences.setString(
    key,
    jsonEncode([for (final search in searches) search.toJson()]),
  );
}

/// [SearchHistoryStore] in memory, for tests.
class InMemorySearchHistoryStore implements SearchHistoryStore {
  InMemorySearchHistoryStore([List<RecentSearch>? searches])
    : searches = [...?searches];

  List<RecentSearch> searches;

  @override
  Future<List<RecentSearch>> read() async => searches;

  @override
  Future<void> write(List<RecentSearch> searches) async =>
      this.searches = searches;
}
