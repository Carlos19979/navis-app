import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(localDatabaseProvider),
    ref: ref,
  );
});

class SyncService {
  SyncService({required this.db, required this.ref});

  final LocalDatabase db;
  final Ref ref;
  bool _isSyncing = false;

  bool get isOnline => ref.read(connectivityProvider);

  Future<void> syncAll() async {
    if (_isSyncing || !isOnline) return;
    _isSyncing = true;

    try {
      await Future.wait([
        _syncBoats(),
        _syncDocuments(),
      ]);
      await db.setSyncMeta(
        'last_sync',
        DateTime.now().toIso8601String(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncBoats() async {
    try {
      final api = ApiClient.instance;
      final response = await api.get<Map<String, dynamic>>('/api/v1/boats');
      final envelope = response.data!;
      final items = envelope['data'] as List<dynamic>? ?? [];

      await db.clearTable('boats');
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        await db.upsert('boats', map['id'] as String, jsonEncode(map));
      }
    } catch (_) {}
  }

  Future<void> _syncDocuments() async {
    try {
      final api = ApiClient.instance;
      final boatsJson = await db.getAll('boats');
      for (final boatJson in boatsJson) {
        final boat = jsonDecode(boatJson) as Map<String, dynamic>;
        final boatId = boat['id'] as String;

        final response = await api.get<Map<String, dynamic>>(
          '/api/v1/boats/$boatId/documents',
        );
        final envelope = response.data!;
        final items = envelope['data'] as List<dynamic>? ?? [];

        for (final item in items) {
          final map = item as Map<String, dynamic>;
          await db.upsert(
            'documents',
            map['id'] as String,
            jsonEncode(map),
            boatId: boatId,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> syncTripsForBoat(String boatId) async {
    if (!isOnline) return;
    try {
      final api = ApiClient.instance;
      final response = await api.get<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/trips',
      );
      final envelope = response.data!;
      final items = envelope['data'] as List<dynamic>? ?? [];

      for (final item in items) {
        final map = item as Map<String, dynamic>;
        await db.upsert(
          'trips',
          map['id'] as String,
          jsonEncode(map),
          boatId: boatId,
        );
      }
    } catch (_) {}
  }
}
