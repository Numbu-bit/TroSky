// `PaginatedResponse` (backend/app/schemas/common.py).

/// One page of a list: [items], and where they sit in the whole ([total]
/// items, starting at [offset]).
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// Reads `{items, total, limit, offset}`, each item with [item].
  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) item,
  ) => Paginated(
    items: [
      for (final entry in json['items'] as List)
        item((entry as Map).cast<String, dynamic>()),
    ],
    total: json['total'] as int,
    limit: json['limit'] as int,
    offset: json['offset'] as int,
  );

  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  /// Whether items after this page exist.
  bool get hasMore => offset + items.length < total;
}
