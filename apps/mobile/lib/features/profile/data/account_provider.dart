import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// The current user's plan and derived entitlements, from GET /api/v1/me.
class Account {
  const Account({
    required this.plan,
    required this.isPro,
    required this.maxBoats,
    required this.boatCount,
    required this.canCreateGroups,
    required this.reminderDocLimit,
    required this.maintenanceSchedules,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    // Prefer the nested `entitlements` object; fall back to the legacy
    // top-level mirrors for older API builds.
    final ent = json['entitlements'] as Map<String, dynamic>?;
    int entInt(String key, String legacyKey, int fallback) =>
        (ent?[key] as num?)?.toInt() ??
        (json[legacyKey] as num?)?.toInt() ??
        fallback;
    bool entBool(String key, String legacyKey) =>
        (ent?[key] as bool?) ?? (json[legacyKey] as bool?) ?? false;

    return Account(
      plan: json['plan'] as String? ?? 'free',
      isPro: json['is_pro'] as bool? ?? (json['plan'] == 'pro'),
      maxBoats: entInt('max_boats', 'max_boats', 1),
      boatCount: entInt('boat_count', 'boat_count', 0),
      canCreateGroups: entBool('can_create_groups', 'can_create_groups'),
      reminderDocLimit: entInt('reminder_doc_limit', 'reminder_doc_limit', 1),
      maintenanceSchedules: (ent?['maintenance_schedules'] as bool?) ?? false,
    );
  }

  final String plan;
  final bool isPro;
  final int maxBoats;
  final int boatCount;
  final bool canCreateGroups;

  /// How many documents get expiry reminders (-1 = unlimited).
  final int reminderDocLimit;

  /// Whether scheduled maintenance reminders are unlocked.
  final bool maintenanceSchedules;

  /// Display label for the plan.
  String get planLabel => isPro ? 'Pro' : 'Free';
}

class AccountRepository {
  AccountRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<Account> getMe() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/api/v1/me');
    return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  /// Dev/testing: change the current user's plan (real apps drive this from a
  /// payment webhook, not the client).
  Future<Account> setPlan(String plan) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/me/plan',
      data: {'plan': plan},
    );
    return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(),
);

final accountProvider = FutureProvider<Account>((ref) async {
  return ref.read(accountRepositoryProvider).getMe();
});
