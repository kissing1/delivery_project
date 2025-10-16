class ListResponse<T> {
  final List<T> items;
  final int count;

  ListResponse({required this.items, required this.count});

  factory ListResponse.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) mapItem,
  ) {
    final raw = (j['items'] ?? []) as List;
    return ListResponse<T>(
      items: raw.map((e) => mapItem(e as Map<String, dynamic>)).toList(),
      count: (j['count'] ?? raw.length) as int,
    );
  }

  Map<String, dynamic> toJson(Object Function(T) toJsonItem) => {
    'items': items.map(toJsonItem).toList(),
    'count': count,
  };
}
