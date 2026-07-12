import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// Overall go/no-go signal for a boat, mirroring the server's ReadinessStatus.
enum ReadinessStatus {
  ready,
  attention,
  notReady;

  static ReadinessStatus fromApi(String? v) => switch (v) {
        'ready' => ReadinessStatus.ready,
        'attention' => ReadinessStatus.attention,
        'not_ready' => ReadinessStatus.notReady,
        _ => ReadinessStatus.attention,
      };
}

/// A group of readiness checks (documents, safety_gear, maintenance).
class ReadinessCategory {
  const ReadinessCategory({
    required this.key,
    required this.status,
    required this.total,
    required this.expired,
    required this.critical,
    required this.warning,
    required this.ok,
  });

  factory ReadinessCategory.fromJson(Map<String, dynamic> j) =>
      ReadinessCategory(
        key: j['key'] as String? ?? '',
        status: ReadinessStatus.fromApi(j['status'] as String?),
        total: (j['total'] as num?)?.toInt() ?? 0,
        expired: (j['expired'] as num?)?.toInt() ?? 0,
        critical: (j['critical'] as num?)?.toInt() ?? 0,
        warning: (j['warning'] as num?)?.toInt() ?? 0,
        ok: (j['ok'] as num?)?.toInt() ?? 0,
      );

  final String key; // documents | safety_gear | maintenance
  final ReadinessStatus status;
  final int total;
  final int expired;
  final int critical;
  final int warning;
  final int ok;
}

/// A single item needing attention. The UI localizes it from [ref] + [days].
class ReadinessItem {
  const ReadinessItem({
    required this.category,
    required this.ref,
    required this.status,
    required this.days,
  });

  factory ReadinessItem.fromJson(Map<String, dynamic> j) => ReadinessItem(
        category: j['category'] as String? ?? '',
        ref: j['ref'] as String? ?? '',
        status: ReadinessStatus.fromApi(j['status'] as String?),
        days: (j['days'] as num?)?.toInt() ?? 0,
      );

  final String category;
  final String ref; // API document type, or "engine_service"
  final ReadinessStatus status;
  final int days; // days until due; negative = overdue
}

/// A boat's "ready to sail" summary.
class Readiness {
  const Readiness({
    required this.score,
    required this.status,
    required this.full,
    required this.categories,
    required this.attention,
  });

  factory Readiness.fromJson(Map<String, dynamic> j) => Readiness(
        score: (j['score'] as num?)?.toInt() ?? 0,
        status: ReadinessStatus.fromApi(j['status'] as String?),
        full: j['full'] as bool? ?? false,
        categories: ((j['categories'] as List?) ?? [])
            .map((e) => ReadinessCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        attention: ((j['attention'] as List?) ?? [])
            .map((e) => ReadinessItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int score;
  final ReadinessStatus status;

  /// Whether this is the full (Pro) breakdown; false = documents-only (Free).
  final bool full;
  final List<ReadinessCategory> categories;
  final List<ReadinessItem> attention;

  ReadinessCategory? category(String key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }
}

class ReadinessRepository {
  ReadinessRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<Readiness> getForBoat(String boatId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/readiness');
    return Readiness.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

final readinessRepositoryProvider = Provider<ReadinessRepository>(
  (ref) => ReadinessRepository(),
);
