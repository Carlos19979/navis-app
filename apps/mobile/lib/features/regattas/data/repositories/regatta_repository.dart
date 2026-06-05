import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/regattas/data/models/regatta_model.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';

class RegattaRepository {
  RegattaRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Regatta>> getGroupRegattas(String groupId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/groups/$groupId/trips');
    return (response.data!['data'] as List<dynamic>)
        .map((j) => RegattaModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Regatta> getRegatta(String id) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/trips/$id');
    return RegattaModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  Future<Regatta> schedule({
    required String groupId,
    required String boatId,
    required String departurePort,
    String? title,
    DateTime? scheduledAt,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/groups/$groupId/trips',
      data: {
        'boat_id': boatId,
        'departure_port': departurePort,
        if (title != null && title.isNotEmpty) 'title': title,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return RegattaModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> setRsvp(String tripId, String rsvp) async {
    await _apiClient
        .post<void>('/api/v1/trips/$tripId/rsvp', data: {'rsvp': rsvp});
  }

  Future<List<RegattaParticipant>> getParticipants(String tripId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/trips/$tripId/participants');
    return (response.data!['data'] as List<dynamic>)
        .map((j) => RegattaParticipantModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Regatta> start(String tripId) async {
    final response = await _apiClient
        .put<Map<String, dynamic>>('/api/v1/trips/$tripId/start');
    return RegattaModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  Future<Regatta> cancel(String tripId) async {
    final response = await _apiClient
        .put<Map<String, dynamic>>('/api/v1/trips/$tripId/cancel');
    return RegattaModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  /// Reverts a recording regatta back to "planned" (discards the recording).
  Future<Regatta> revertToPlanned(String tripId) async {
    final response = await _apiClient
        .put<Map<String, dynamic>>('/api/v1/trips/$tripId/revert');
    return RegattaModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  // --- Checklist ---

  Future<List<ChecklistItem>> getChecklist(String tripId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/trips/$tripId/checklist');
    return (response.data!['data'] as List<dynamic>)
        .map((j) => ChecklistItemModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> setChecklistItem(
      String tripId, String itemId, bool isChecked) async {
    await _apiClient.put<void>(
      '/api/v1/trips/$tripId/checklist/$itemId',
      data: {'is_checked': isChecked},
    );
  }

  Future<ChecklistItem> addChecklistItem(String tripId, String label) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/trips/$tripId/checklist',
      data: {'label': label},
    );
    return ChecklistItemModel.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> removeChecklistItem(String tripId, String itemId) async {
    await _apiClient.delete<void>('/api/v1/trips/$tripId/checklist/$itemId');
  }

  Future<void> completeChecklist(String tripId) async {
    await _apiClient.put<void>('/api/v1/trips/$tripId/checklist/complete');
  }
}
