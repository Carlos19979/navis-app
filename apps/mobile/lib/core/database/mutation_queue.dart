import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';

const _maxRetries = 5;

final mutationQueueProvider =
    StateNotifierProvider<MutationQueueNotifier, int>((ref) {
  final notifier = MutationQueueNotifier(
    db: ref.watch(localDatabaseProvider),
    ref: ref,
  );

  ref.listen<bool>(connectivityProvider, (previous, isOnline) {
    if (isOnline && previous == false) {
      notifier.replayAll();
    }
  });

  return notifier;
});

class MutationQueueNotifier extends StateNotifier<int> {
  MutationQueueNotifier({required this.db, required this.ref}) : super(0) {
    _loadCount();
  }

  final LocalDatabase db;
  final Ref ref;
  bool _isReplaying = false;

  Future<void> _loadCount() async {
    state = await db.getPendingMutationCount();
  }

  Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final id = _generateId();
    await db.insertMutation({
      'id': id,
      'method': method,
      'path': path,
      'body': body != null ? jsonEncode(body) : null,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    state = await db.getPendingMutationCount();
  }

  Future<void> replayAll() async {
    if (_isReplaying) return;
    _isReplaying = true;

    try {
      final mutations = await db.getPendingMutations();
      final api = ApiClient.instance;

      for (final mutation in mutations) {
        final id = mutation['id'] as String;
        final method = mutation['method'] as String;
        final path = mutation['path'] as String;
        final bodyStr = mutation['body'] as String?;
        final retryCount = mutation['retry_count'] as int;
        final body = bodyStr != null
            ? jsonDecode(bodyStr) as Map<String, dynamic>
            : null;

        if (retryCount >= _maxRetries) {
          await db.deleteMutation(id);
          continue;
        }

        try {
          await _executeMutation(api, method, path, body);
          await db.deleteMutation(id);
        } catch (_) {
          await db.incrementRetryCount(id);
          final delay = Duration(
            seconds: min(pow(2, retryCount + 1).toInt(), 60),
          );
          await Future<void>.delayed(delay);

          if (!ref.read(connectivityProvider)) break;
        }
      }
    } finally {
      _isReplaying = false;
      state = await db.getPendingMutationCount();
    }
  }

  Future<void> _executeMutation(
    ApiClient api,
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    switch (method) {
      case 'POST':
        await api.post<Map<String, dynamic>>(path, data: body);
      case 'PUT':
        await api.put<Map<String, dynamic>>(path, data: body);
      case 'DELETE':
        await api.delete<void>(path);
    }
  }

  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(99999);
    return '${now}_$rand';
  }
}
