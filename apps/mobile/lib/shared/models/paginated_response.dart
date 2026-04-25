class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    this.nextCursor,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final items = (json['items'] as List<dynamic>)
        .map((item) => itemParser(item as Map<String, dynamic>))
        .toList();

    return PaginatedResponse<T>(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
