import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';

enum MutationMethod { post, put, delete }

class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
  });

  factory PendingMutation.fromJson(Map<String, dynamic> json) {
    return PendingMutation(
      id: json['id'] as String,
      method: MutationMethod.values.byName(json['method'] as String),
      path: json['path'] as String,
      body: json['body'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final MutationMethod method;
  final String path;
  final Map<String, dynamic>? body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method.name,
        'path': path,
        if (body != null) 'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

final mutationQueueProvider =
    StateNotifierProvider<MutationQueueNotifier, Queue<PendingMutation>>(
  MutationQueueNotifier.new,
);

final pendingMutationCountProvider = Provider<int>((ref) {
  return ref.watch(mutationQueueProvider).length;
});

class MutationQueueNotifier extends StateNotifier<Queue<PendingMutation>> {
  MutationQueueNotifier(this._ref) : super(Queue()) {
    _loadFromDisk();
    _ref.listen(connectivityProvider, (prev, isOnline) {
      if (isOnline && state.isNotEmpty) {
        replayAll();
      }
    });
  }

  final Ref _ref;
  bool _isReplaying = false;
  static const _storageKey = 'pending_mutations';

  int get pendingCount => state.length;

  void enqueue(PendingMutation mutation) {
    state = Queue.from([...state, mutation]);
    _saveToDisk();
  }

  Future<void> replayAll() async {
    if (_isReplaying || state.isEmpty) return;
    _isReplaying = true;

    final api = ApiClient.instance;
    final failed = Queue<PendingMutation>();

    while (state.isNotEmpty) {
      final mutation = state.first;
      state = Queue.from(state.skip(1));

      try {
        switch (mutation.method) {
          case MutationMethod.post:
            await api.post<dynamic>(mutation.path, data: mutation.body);
          case MutationMethod.put:
            await api.put<dynamic>(mutation.path, data: mutation.body);
          case MutationMethod.delete:
            await api.delete<dynamic>(mutation.path);
        }
      } catch (_) {
        failed.add(mutation);
        break;
      }
    }

    state = Queue.from([...failed, ...state]);
    await _saveToDisk();
    _isReplaying = false;
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final json = state.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_storageKey, json);
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getStringList(_storageKey);
    if (json != null && json.isNotEmpty) {
      state = Queue.from(
        json.map((s) =>
            PendingMutation.fromJson(jsonDecode(s) as Map<String, dynamic>)),
      );
    }
  }
}
