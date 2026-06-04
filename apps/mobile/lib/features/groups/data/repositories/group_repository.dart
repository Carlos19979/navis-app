import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/groups/data/models/group_member_model.dart';
import 'package:navis_mobile/features/groups/data/models/group_model.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class GroupRepository {
  GroupRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<PaginatedResponse<Group>> getGroups({
    String? cursor,
    int limit = 20,
    bool discover = false,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/groups',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (discover) 'discover': true,
      },
    );
    final envelope = response.data!;
    final items = (envelope['data'] as List<dynamic>)
        .map((j) => GroupModel.fromJson(j as Map<String, dynamic>).toEntity())
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>?;
    return PaginatedResponse<Group>(
      items: items,
      nextCursor: meta?['next_cursor'] as String?,
    );
  }

  Future<Group> getGroup(String id) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/groups/$id');
    return GroupModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Group> createGroup({
    required String name,
    required String visibility,
    String? description,
    String? photoUrl,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/groups',
      data: {
        'name': name,
        'visibility': visibility,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
      },
    );
    return GroupModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Group> updateGroup(
    String id, {
    String? name,
    String? description,
    String? visibility,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/groups/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (visibility != null) 'visibility': visibility,
      },
    );
    return GroupModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<void> deleteGroup(String id) async {
    await _apiClient.delete<void>('/api/v1/groups/$id');
  }

  Future<Group> requestJoin(String id) async {
    final response =
        await _apiClient.post<Map<String, dynamic>>('/api/v1/groups/$id/join');
    return GroupModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Group> joinByCode(String code) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/groups/join',
      data: {'code': code},
    );
    return GroupModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<void> leaveGroup(String id) async {
    await _apiClient.post<void>('/api/v1/groups/$id/leave');
  }

  Future<List<GroupMember>> getMembers(String id) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/groups/$id/members');
    return (response.data!['data'] as List<dynamic>)
        .map((j) =>
            GroupMemberModel.fromJson(j as Map<String, dynamic>).toEntity())
        .toList();
  }

  Future<void> removeMember(String id, String userId) async {
    await _apiClient.delete<void>('/api/v1/groups/$id/members/$userId');
  }

  Future<List<GroupMember>> getRequests(String id) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/groups/$id/requests');
    return (response.data!['data'] as List<dynamic>)
        .map((j) =>
            GroupMemberModel.fromJson(j as Map<String, dynamic>).toEntity())
        .toList();
  }

  Future<void> approveRequest(String id, String userId) async {
    await _apiClient.post<void>('/api/v1/groups/$id/requests/$userId/approve');
  }

  Future<void> rejectRequest(String id, String userId) async {
    await _apiClient.post<void>('/api/v1/groups/$id/requests/$userId/reject');
  }
}
