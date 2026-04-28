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
      version: 2,
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
