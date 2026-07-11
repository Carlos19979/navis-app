import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

class LocalDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'navis_cache.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE boats (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        boat_id TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        boat_id TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_mutations (
        id TEXT PRIMARY KEY,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_documents_boat ON documents(boat_id)',
    );
    await db.execute(
      'CREATE INDEX idx_trips_boat ON trips(boat_id)',
    );
    await db.execute(
      'CREATE INDEX idx_mutations_created ON pending_mutations(created_at)',
    );
    await _createRecordingTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_mutations (
          id TEXT PRIMARY KEY,
          method TEXT NOT NULL,
          path TEXT NOT NULL,
          body TEXT,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mutations_created ON pending_mutations(created_at)',
      );
    }
    if (oldVersion < 3) {
      await _createRecordingTables(db);
    }
  }

  /// Crash-safe trip recording: the active session and every GPS fix are
  /// written to disk as they happen, so killing the app mid-passage loses
  /// nothing — the session is offered for resume on next launch.
  Future<void> _createRecordingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recording_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        boat_id TEXT NOT NULL,
        trip_id TEXT,
        is_regatta INTEGER NOT NULL DEFAULT 0,
        departure_port TEXT,
        started_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recording_points (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        timestamp TEXT NOT NULL,
        speed_knots REAL,
        handed_off INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> upsert(
    String table,
    String id,
    String data, {
    String? boatId,
  }) async {
    final db = await database;
    await db.insert(
      table,
      {
        'id': id,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
        if (boatId != null) 'boat_id': boatId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getById(String table, String id) async {
    final db = await database;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first['data'] as String;
  }

  Future<List<String>> getAll(String table) async {
    final db = await database;
    final rows = await db.query(table, orderBy: 'updated_at DESC');
    return rows.map((r) => r['data'] as String).toList();
  }

  Future<List<String>> getByBoatId(String table, String boatId) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'boat_id = ?',
      whereArgs: [boatId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => r['data'] as String).toList();
  }

  Future<void> deleteById(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<void> setSyncMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSyncMeta(String key) async {
    final db = await database;
    final rows =
        await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> insertMutation(Map<String, dynamic> mutation) async {
    final db = await database;
    await db.insert('pending_mutations', mutation);
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    final db = await database;
    return db.query('pending_mutations', orderBy: 'created_at ASC');
  }

  Future<int> getPendingMutationCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_mutations');
    return result.first['cnt'] as int;
  }

  Future<void> deleteMutation(String id) async {
    final db = await database;
    await db.delete('pending_mutations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetryCount(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_mutations SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  // ── Trip recording persistence ────────────────────────────────────────

  /// Starts (or replaces) the single active recording session and clears any
  /// leftover points from a previous session.
  Future<void> startRecordingSession({
    required String boatId,
    String? tripId,
    required bool isRegatta,
    String? departurePort,
    required DateTime startedAt,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('recording_points');
      await txn.insert(
        'recording_session',
        {
          'id': 1,
          'boat_id': boatId,
          'trip_id': tripId,
          'is_regatta': isRegatta ? 1 : 0,
          'departure_port': departurePort,
          'started_at': startedAt.toIso8601String(),
          'status': 'recording',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> getRecordingSession() async {
    final db = await database;
    final rows = await db.query('recording_session', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateRecordingSession(Map<String, dynamic> fields) async {
    final db = await database;
    await db.update('recording_session', fields, where: 'id = 1');
  }

  Future<void> clearRecordingSession() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('recording_session');
      await txn.delete('recording_points');
    });
  }

  /// Persists one GPS fix and returns its sequence number.
  Future<int> insertRecordingPoint({
    required double lat,
    required double lon,
    required DateTime timestamp,
    double? speedKnots,
  }) async {
    final db = await database;
    return db.insert('recording_points', {
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp.toIso8601String(),
      'speed_knots': speedKnots,
    });
  }

  /// All recorded points in order (for resume / final save).
  Future<List<Map<String, dynamic>>> getRecordingPoints() async {
    final db = await database;
    return db.query('recording_points', orderBy: 'seq ASC');
  }

  /// Points not yet handed off to an upload (direct POST or mutation queue).
  Future<List<Map<String, dynamic>>> getPendingRecordingPoints() async {
    final db = await database;
    return db.query(
      'recording_points',
      where: 'handed_off = 0',
      orderBy: 'seq ASC',
    );
  }

  /// Marks points up to [maxSeq] as handed off so they are not uploaded twice.
  Future<void> markRecordingPointsHandedOff(int maxSeq) async {
    final db = await database;
    await db.update(
      'recording_points',
      {'handed_off': 1},
      where: 'seq <= ?',
      whereArgs: [maxSeq],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
