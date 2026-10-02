import 'package:flutter/foundation.dart';

/// A stop the passenger picked, by id and the name to show.
@immutable
class SearchStop {
  const SearchStop({required this.id, required this.name});

  factory SearchStop.fromJson(Map<String, dynamic> json) =>
      SearchStop(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;

  Map<String, Object> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is SearchStop && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where the passenger boards: the phone's position (the backend picks the
/// stop, decision 19), or a stop they chose.
@immutable
sealed class SearchOrigin {
  const SearchOrigin();

  factory SearchOrigin.fromJson(Map<String, dynamic>? json) => json == null
      ? const CurrentLocationOrigin()
      : StopOrigin(SearchStop.fromJson(json));

  Map<String, Object>? toJson();
}

final class CurrentLocationOrigin extends SearchOrigin {
  const CurrentLocationOrigin();

  @override
  Map<String, Object>? toJson() => null;

  @override
  bool operator ==(Object other) => other is CurrentLocationOrigin;

  @override
  int get hashCode => 0;
}

final class StopOrigin extends SearchOrigin {
  const StopOrigin(this.stop);

  final SearchStop stop;

  @override
  Map<String, Object> toJson() => stop.toJson();

  @override
  bool operator ==(Object other) => other is StopOrigin && other.stop == stop;

  @override
  int get hashCode => stop.hashCode;
}

/// When to travel: from now, or from a chosen local date and time.
@immutable
class SearchWhen {
  const SearchWhen.now() : at = null;

  const SearchWhen.at(DateTime this.at);

  /// Local time; null for now.
  final DateTime? at;

  bool get isNow => at == null;

  @override
  bool operator ==(Object other) => other is SearchWhen && other.at == at;

  @override
  int get hashCode => at.hashCode;
}

/// One search: from, to and when.
@immutable
class JourneySearch {
  const JourneySearch({
    required this.origin,
    required this.destination,
    this.when = const SearchWhen.now(),
  });

  final SearchOrigin origin;
  final SearchStop destination;
  final SearchWhen when;

  JourneySearch copyWith({SearchWhen? when}) => JourneySearch(
    origin: origin,
    destination: destination,
    when: when ?? this.when,
  );

  @override
  bool operator ==(Object other) =>
      other is JourneySearch &&
      other.origin == origin &&
      other.destination == destination &&
      other.when == when;

  @override
  int get hashCode => Object.hash(origin, destination, when);
}

/// A search the passenger ran, kept for "Recent searches".
@immutable
class RecentSearch {
  const RecentSearch({required this.origin, required this.destination});

  factory RecentSearch.fromJson(Map<String, dynamic> json) => RecentSearch(
    origin: SearchOrigin.fromJson(
      (json['origin'] as Map?)?.cast<String, dynamic>(),
    ),
    destination: SearchStop.fromJson(
      (json['destination']! as Map).cast<String, dynamic>(),
    ),
  );

  final SearchOrigin origin;
  final SearchStop destination;

  Map<String, Object?> toJson() => {
    'origin': origin.toJson(),
    'destination': destination.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is RecentSearch &&
      other.origin == origin &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(origin, destination);
}
