import 'package:navis_mobile/core/network/api_client.dart';

/// Talks to the moderation endpoints (App Store Review Guideline 1.2): report
/// objectionable content, block/unblock users, and fetch the caller's blocked
/// list so their content can be hidden.
class ModerationRepository {
  ModerationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  /// Reports a piece of user-generated content for operator review.
  /// [contentType] is 'group' or 'event'; [reason] is one of
  /// spam / offensive / harassment / other.
  Future<void> report({
    required String contentType,
    required String contentId,
    required String reason,
    String? note,
  }) async {
    await _apiClient.post<void>('/api/v1/reports', data: {
      'content_type': contentType,
      'content_id': contentId,
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  /// Blocks [userId] so their public content is hidden from the caller.
  Future<void> block(String userId) async {
    await _apiClient.post<void>('/api/v1/users/$userId/block');
  }

  /// Removes a previously created block.
  Future<void> unblock(String userId) async {
    await _apiClient.delete<void>('/api/v1/users/$userId/block');
  }

  /// Returns the set of user IDs the caller has blocked.
  Future<Set<String>> blockedUserIds() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/me/blocked');
    final data = response.data!['data'] as Map<String, dynamic>;
    final ids = data['blocked_user_ids'] as List<dynamic>? ?? <dynamic>[];
    return ids.map((e) => e as String).toSet();
  }
}
