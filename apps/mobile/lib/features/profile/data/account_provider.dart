import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// The current user's plan and derived limits, from GET /api/v1/me.
class Account {
  const Account({
    required this.plan,
    required this.maxBoats,
    required this.boatCount,
    required this.canCreateGroups,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      plan: json['plan'] as String? ?? 'normal',
      maxBoats: (json['max_boats'] as num?)?.toInt() ?? 1,
      boatCount: (json['boat_count'] as num?)?.toInt() ?? 0,
      canCreateGroups: json['can_create_groups'] as bool? ?? false,
    );
  }

  final String plan;
  final int maxBoats;
  final int boatCount;
  final bool canCreateGroups;

  /// Localized-ish display label for the plan.
  String get planLabel => switch (plan) {
        'armador' => 'Armador',
        'gestor' => 'Gestor',
        _ => 'Normal',
      };
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
