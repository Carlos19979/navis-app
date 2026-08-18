/// How far along a region's tile download is.
enum ChartRegionStatus {
  /// Tiles are still being fetched. The region is usable but incomplete.
  downloading,

  /// Every tile was stored (or accounted for as empty water).
  ready,

  /// The download stopped early — cancelled, or too many tiles failed.
  failed;

  static ChartRegionStatus fromId(String id) => switch (id) {
        'downloading' => ChartRegionStatus.downloading,
        'ready' => ChartRegionStatus.ready,
        _ => ChartRegionStatus.failed,
      };
}

/// A geographic box whose chart tiles are stored on the device, so the map
/// draws with no network at all. Tiles belonging to a region are pinned: the
/// browse-cache eviction never reclaims them, and they never expire.
class ChartRegion {
  const ChartRegion({
    required this.id,
    required this.name,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.minZoom,
    required this.maxZoom,
    required this.createdAt,
    this.tileCount = 0,
    this.bytes = 0,
    this.status = ChartRegionStatus.downloading,
  });

  final String id;
  final String name;
  final double west;
  final double south;
  final double east;
  final double north;
  final int minZoom;
  final int maxZoom;
  final DateTime createdAt;

  /// Tiles actually stored for this region (both layers).
  final int tileCount;

  /// Bytes those tiles occupy.
  final int bytes;

  final ChartRegionStatus status;

  ChartRegion copyWith({
    String? id,
    String? name,
    double? west,
    double? south,
    double? east,
    double? north,
    int? minZoom,
    int? maxZoom,
    DateTime? createdAt,
    int? tileCount,
    int? bytes,
    ChartRegionStatus? status,
  }) {
    return ChartRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      west: west ?? this.west,
      south: south ?? this.south,
      east: east ?? this.east,
      north: north ?? this.north,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      createdAt: createdAt ?? this.createdAt,
      tileCount: tileCount ?? this.tileCount,
      bytes: bytes ?? this.bytes,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChartRegion &&
      other.id == id &&
      other.name == name &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom &&
      other.createdAt == createdAt &&
      other.tileCount == tileCount &&
      other.bytes == bytes &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        west,
        south,
        east,
        north,
        minZoom,
        maxZoom,
        createdAt,
        tileCount,
        bytes,
        status,
      );
}
