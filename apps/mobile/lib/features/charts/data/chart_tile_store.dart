import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';

final chartTileStoreProvider = Provider<ChartTileStore>((ref) {
  return ChartTileStore.instance;
});

/// A tile as it sits in the store. [bytes] is null when the server answered
/// "there is nothing here" (open water on the seamark layer, or a 404 past a
/// layer's coverage) — worth remembering so we neither re-request it nor draw
/// an error tile over it.
typedef StoredTile = ({
  Uint8List? bytes,
  bool isBlank,
  DateTime fetchedAt,
  bool pinned,
});

/// On-device chart tiles, in their own SQLite database.
///
/// Two kinds of tile live here and the difference is the whole point:
///
///  * **Pinned** tiles belong to a [ChartRegion] the user downloaded on
///    purpose. They never expire and eviction never touches them — offshore
///    with no signal, these are the map.
///  * **Browse** tiles are whatever the user happened to pan over. They are a
///    convenience cache: capped at [maxBrowseBytes], evicted
///    least-recently-used first, and re-validated after [browseMaxAge].
///
/// Pinning is *derived* from the region rows, never set on write, so a tile
/// stored while browsing is picked up by a later download of the same area and
/// stops being pinned the moment its last region is deleted.
///
/// Separate from `navis_cache.db` on purpose: hundreds of MB of raster tiles
/// have nothing to do with the JSON entity cache, and "delete my charts" must
/// not mean "resync my boats".
class ChartTileStore {
  ChartTileStore({this.databaseName = 'navis_chart_tiles.db'});

  /// The instance the map layers use. Tile fetches happen deep inside
  /// `ImageProvider.loadImage`, far from any `WidgetRef`, so the store is a
  /// singleton (as `ApiClient` is) and [chartTileStoreProvider] hands the same
  /// object to the UI. Tests construct their own with a scoped name.
  static final ChartTileStore instance = ChartTileStore();

  final String databaseName;

  /// Ceiling for unpinned tiles before eviction kicks in.
  static const int maxBrowseBytes = 120 * 1024 * 1024;

  /// Eviction target, below [maxBrowseBytes] so a single pan does not trigger
  /// a prune on every tile it stores.
  static const int browseTargetBytes = 100 * 1024 * 1024;

  /// After this, an unpinned tile is re-fetched when online. Coastlines and
  /// seamarks change slowly; the point of a chart cache is that it lasts.
  static const Duration browseMaxAge = Duration(days: 60);

  /// Saves between eviction checks. Summing 10k blob sizes on every stored
  /// tile would cost more than the eviction it guards.
  static const int _savesPerPruneCheck = 250;

  /// A read only bumps `last_used` if the stored value is this stale. Panning
  /// re-reads the same tiles continuously and a write per read turns a pan
  /// into a burst of disk I/O.
  static const Duration _touchInterval = Duration(hours: 12);

  Future<Database>? _opening;
  int _savesSincePruneCheck = 0;

  Future<Database> get database => _opening ??= _openOnce();

  /// One open shared by every caller — but a *failed* open is not cached, or a
  /// transient failure at startup would leave the map with no tile store for
  /// the rest of the session.
  Future<Database> _openOnce() async {
    try {
      return await _open();
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), databaseName);
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tiles (
        layer TEXT NOT NULL,
        z INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        bytes BLOB NOT NULL,
        size INTEGER NOT NULL,
        blank INTEGER NOT NULL DEFAULT 0,
        fetched_at INTEGER NOT NULL,
        last_used INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (layer, z, x, y)
      )
    ''');
    // Eviction scans unpinned tiles by age; pinning scans by tile address
    // across both layers, which the (layer, …) primary key cannot serve.
    await db.execute(
      'CREATE INDEX idx_tiles_evict ON tiles(pinned, last_used)',
    );
    await db.execute('CREATE INDEX idx_tiles_zxy ON tiles(z, x, y)');
    await db.execute('''
      CREATE TABLE regions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        west REAL NOT NULL,
        south REAL NOT NULL,
        east REAL NOT NULL,
        north REAL NOT NULL,
        min_zoom INTEGER NOT NULL,
        max_zoom INTEGER NOT NULL,
        tile_count INTEGER NOT NULL DEFAULT 0,
        bytes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  // ── Tiles ───────────────────────────────────────────────────────────────

  Future<StoredTile?> lookup(ChartTileLayer layer, TileRef ref) async {
    final db = await database;
    final rows = await db.query(
      'tiles',
      columns: ['bytes', 'blank', 'fetched_at', 'last_used', 'pinned'],
      where: 'layer = ? AND z = ? AND x = ? AND y = ?',
      whereArgs: [layer.id, ref.z, ref.x, ref.y],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final isBlank = (row['blank'] as int) == 1;
    final pinned = (row['pinned'] as int) == 1;
    final lastUsed = row['last_used'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!pinned && now - lastUsed > _touchInterval.inMilliseconds) {
      await db.update(
        'tiles',
        {'last_used': now},
        where: 'layer = ? AND z = ? AND x = ? AND y = ?',
        whereArgs: [layer.id, ref.z, ref.x, ref.y],
      );
    }

    return (
      bytes: isBlank ? null : row['bytes'] as Uint8List,
      isBlank: isBlank,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int),
      pinned: pinned,
    );
  }

  Future<bool> has(ChartTileLayer layer, TileRef ref) async {
    final db = await database;
    final rows = await db.query(
      'tiles',
      columns: ['1'],
      where: 'layer = ? AND z = ? AND x = ? AND y = ?',
      whereArgs: [layer.id, ref.z, ref.x, ref.y],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Stores tile bytes. Pass an empty list for "the server has no tile here".
  ///
  /// Never sets `pinned` — see the class doc: pinning belongs to the regions.
  Future<void> save(
    ChartTileLayer layer,
    TileRef ref,
    Uint8List bytes,
  ) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'tiles',
      {
        'layer': layer.id,
        'z': ref.z,
        'x': ref.x,
        'y': ref.y,
        'bytes': bytes,
        'size': bytes.length,
        'blank': bytes.isEmpty ? 1 : 0,
        'fetched_at': now,
        'last_used': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (++_savesSincePruneCheck >= _savesPerPruneCheck) {
      _savesSincePruneCheck = 0;
      await pruneBrowseCache();
    }
  }

  Future<int> totalBytes() => _sumBytes();

  Future<int> pinnedBytes() => _sumBytes(where: 'pinned = 1');

  Future<int> _sumBytes({String? where}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) AS total FROM tiles'
      '${where == null ? '' : ' WHERE $where'}',
    );
    return (rows.first['total'] as num).toInt();
  }

  /// Drops aged-out and then least-recently-used unpinned tiles until the
  /// browse cache is back under [browseTargetBytes]. Pinned tiles are never
  /// candidates, so a full browse cache cannot cost the user the region they
  /// downloaded for the passage.
  Future<void> pruneBrowseCache() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(browseMaxAge).millisecondsSinceEpoch;
    await db.delete(
      'tiles',
      where: 'pinned = 0 AND fetched_at < ?',
      whereArgs: [cutoff],
    );

    var unpinned = await _sumBytes(where: 'pinned = 0');
    if (unpinned <= maxBrowseBytes) return;

    final rows = await db.query(
      'tiles',
      columns: ['rowid', 'size'],
      where: 'pinned = 0',
      orderBy: 'last_used ASC',
    );
    final doomed = <int>[];
    for (final row in rows) {
      if (unpinned <= browseTargetBytes) break;
      doomed.add(row['rowid']! as int);
      unpinned -= (row['size']! as num).toInt();
    }
    if (doomed.isEmpty) return;
    final placeholders = List.filled(doomed.length, '?').join(',');
    await db.delete(
      'tiles',
      where: 'rowid IN ($placeholders)',
      whereArgs: doomed,
    );
  }

  // ── Regions ─────────────────────────────────────────────────────────────

  Future<List<ChartRegion>> regions() async {
    final db = await database;
    final rows = await db.query('regions', orderBy: 'created_at DESC');
    return rows.map(_regionFromRow).toList();
  }

  Future<ChartRegion?> region(String id) async {
    final db = await database;
    final rows = await db.query(
      'regions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _regionFromRow(rows.first);
  }

  /// Inserts or updates a region and re-derives tile pinning from the result.
  Future<void> saveRegion(ChartRegion region) async {
    final db = await database;
    await db.insert(
      'regions',
      {
        'id': region.id,
        'name': region.name,
        'west': region.west,
        'south': region.south,
        'east': region.east,
        'north': region.north,
        'min_zoom': region.minZoom,
        'max_zoom': region.maxZoom,
        'tile_count': region.tileCount,
        'bytes': region.bytes,
        'created_at': region.createdAt.millisecondsSinceEpoch,
        'status': region.status.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recomputePinned(db);
  }

  /// Forgets a region and frees the tiles it was holding. Tiles still covered
  /// by another region survive, because pinning is re-derived first.
  Future<void> deleteRegion(String id) async {
    final db = await database;
    final doomed = await region(id);
    if (doomed == null) return;
    await db.delete('regions', where: 'id = ?', whereArgs: [id]);
    await _recomputePinned(db);
    for (var z = doomed.minZoom; z <= doomed.maxZoom; z++) {
      final range = TileMath.range(_box(doomed), z);
      await db.delete(
        'tiles',
        where: 'pinned = 0 AND z = ? AND x BETWEEN ? AND ? '
            'AND y BETWEEN ? AND ?',
        whereArgs: [z, range.minX, range.maxX, range.minY, range.maxY],
      );
    }
  }

  /// Tiles actually on disk for [region], counted from the tile table rather
  /// than from whatever the downloader thought it wrote — a resumed download
  /// skips tiles it already has, and this still reports the truth.
  Future<({int tiles, int bytes})> regionUsage(ChartRegion region) async {
    final db = await database;
    var tiles = 0;
    var bytes = 0;
    for (var z = region.minZoom; z <= region.maxZoom; z++) {
      final range = TileMath.range(_box(region), z);
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c, COALESCE(SUM(size), 0) AS s FROM tiles '
        'WHERE z = ? AND x BETWEEN ? AND ? AND y BETWEEN ? AND ?',
        [z, range.minX, range.maxX, range.minY, range.maxY],
      );
      tiles += (rows.first['c'] as num).toInt();
      bytes += (rows.first['s'] as num).toInt();
    }
    return (tiles: tiles, bytes: bytes);
  }

  /// Wipes every tile and region.
  Future<void> clear() async {
    final db = await database;
    await db.delete('tiles');
    await db.delete('regions');
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  Future<void> _recomputePinned(DatabaseExecutor db) async {
    await db.update('tiles', {'pinned': 0}, where: 'pinned = 1');
    for (final row in await db.query('regions')) {
      final region = _regionFromRow(row);
      // A failed download's leftovers are not worth protecting from eviction.
      if (region.status == ChartRegionStatus.failed) continue;
      for (var z = region.minZoom; z <= region.maxZoom; z++) {
        final range = TileMath.range(_box(region), z);
        await db.update(
          'tiles',
          {'pinned': 1},
          where: 'z = ? AND x BETWEEN ? AND ? AND y BETWEEN ? AND ?',
          whereArgs: [z, range.minX, range.maxX, range.minY, range.maxY],
        );
      }
    }
  }

  static TileBox _box(ChartRegion region) => (
        west: region.west,
        south: region.south,
        east: region.east,
        north: region.north,
      );

  static ChartRegion _regionFromRow(Map<String, Object?> row) => ChartRegion(
        id: row['id']! as String,
        name: row['name']! as String,
        west: (row['west']! as num).toDouble(),
        south: (row['south']! as num).toDouble(),
        east: (row['east']! as num).toDouble(),
        north: (row['north']! as num).toDouble(),
        minZoom: (row['min_zoom']! as num).toInt(),
        maxZoom: (row['max_zoom']! as num).toInt(),
        tileCount: (row['tile_count']! as num).toInt(),
        bytes: (row['bytes']! as num).toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at']! as num).toInt(),
        ),
        status: ChartRegionStatus.fromId(row['status']! as String),
      );
}
