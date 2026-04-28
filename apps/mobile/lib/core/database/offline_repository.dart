import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';

final offlineRepositoryProvider = Provider<OfflineRepository>((ref) {
  return OfflineRepository(
    db: ref.watch(localDatabaseProvider),
    isOnline: ref.watch(connectivityProvider),
  );
});

class OfflineRepository {
  const OfflineRepository({required this.db, required this.isOnline});

  final LocalDatabase db;
  final bool isOnline;

  Future<List<Map<String, dynamic>>> getCachedList(String table) async {
    final rows = await db.getAll(table);
    return rows.map((r) => jsonDecode(r) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getCachedByBoat(
    String table,
    String boatId,
  ) async {
    final rows = await db.getByBoatId(table, boatId);
    return rows.map((r) => jsonDecode(r) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getCachedById(
    String table,
    String id,
  ) async {
    final json = await db.getById(table, id);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> cacheItem(
    String table,
    String id,
    Map<String, dynamic> data, {
    String? boatId,
  }) async {
    await db.upsert(table, id, jsonEncode(data), boatId: boatId);
  }

  Future<void> cacheList(
    String table,
    List<Map<String, dynamic>> items, {
    String? boatId,
  }) async {
    for (final item in items) {
      await db.upsert(
        table,
        item['id'] as String,
        jsonEncode(item),
        boatId: boatId,
      );
    }
  }

  Future<void> removeItem(String table, String id) async {
    await db.deleteById(table, id);
  }

  bool isNetworkError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return false;
  }
}
