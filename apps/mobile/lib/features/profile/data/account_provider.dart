import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/session_provider.dart';

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
    required this.attachmentLimit,
    required this.galleryLimit,
    required this.fullReadiness,
    required this.costAnalytics,
    required this.exportPassport,
    required this.sharedCoordination,
    required this.anomalyAlerts,
    required this.anchorAlarm,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    // Prefer the nested `entitlements` object; fall back to the legacy
    // top-level mirrors for older API builds.
    final ent = json['entitlements'] as Map<String, dynamic>?;
    final isPro = json['is_pro'] as bool? ?? (json['plan'] == 'pro');
    int entInt(String key, String legacyKey, int fallback) =>
        (ent?[key] as num?)?.toInt() ??
        (json[legacyKey] as num?)?.toInt() ??
        fallback;
    bool entBool(String key, String legacyKey) =>
        (ent?[key] as bool?) ?? (json[legacyKey] as bool?) ?? false;
    // Pro-only capabilities: if an older API omits them, fall back to isPro so
    // gating stays correct.
    bool proCap(String key) => (ent?[key] as bool?) ?? isPro;

    return Account(
      plan: json['plan'] as String? ?? 'free',
      isPro: isPro,
      maxBoats: entInt('max_boats', 'max_boats', 1),
      boatCount: entInt('boat_count', 'boat_count', 0),
      canCreateGroups: entBool('can_create_groups', 'can_create_groups'),
      reminderDocLimit: entInt('reminder_doc_limit', 'reminder_doc_limit', 1),
      maintenanceSchedules: (ent?['maintenance_schedules'] as bool?) ?? false,
      attachmentLimit:
          entInt('attachment_limit', 'attachment_limit', isPro ? -1 : 1),
      galleryLimit: entInt('gallery_limit', 'gallery_limit', isPro ? 10 : 1),
      fullReadiness: proCap('full_readiness'),
      costAnalytics: proCap('cost_analytics'),
      exportPassport: proCap('export_passport'),
      sharedCoordination: proCap('shared_coordination'),
      anomalyAlerts: proCap('anomaly_alerts'),
      anchorAlarm: proCap('anchor_alarm'),
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

  /// Photos/attachments per maintenance log (-1 = unlimited).
  final int attachmentLimit;

  /// Total photos per boat, cover included (Free keeps just the cover).
  final int galleryLimit;

  /// Full boat-readiness breakdown (docs + gear + maintenance). Free sees docs only.
  final bool fullReadiness;

  /// Advanced cost intelligence (cost/NM, cost/trip, efficiency, seasonal).
  final bool costAnalytics;

  /// Boat passport (PDF dossier) export.
  final bool exportPassport;

  /// Shared-boat coordination (bookings + expense splitting).
  final bool sharedCoordination;

  /// Anomaly alerts (e.g. fuel-per-mile outliers).
  final bool anomalyAlerts;

  /// Anchor watch: drop an anchor position + swing radius and get a drift alarm.
  final bool anchorAlarm;

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

  /// GDPR data export: everything the server stores for this user, as a
  /// JSON-ready map (GET /api/v1/user/export).
  Future<Map<String, dynamic>> exportData() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/user/export');
    return response.data!['data'] as Map<String, dynamic>;
  }

  /// Permanently deletes the account, its data and files (GDPR). The backend
  /// removes the auth user, so the session is invalid afterwards.
  Future<void> deleteAccount() async {
    await _apiClient.delete<void>('/api/v1/user');
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(),
);

final accountProvider = FutureProvider<Account>((ref) async {
  ref.watch(sessionUserIdProvider);
  return ref.read(accountRepositoryProvider).getMe();
});
