import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/boat/data/models/boat_model.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';

/// A user with shared access to a boat.
class BoatMember {
  const BoatMember({
    required this.userId,
    required this.name,
    required this.role,
  });

  factory BoatMember.fromJson(Map<String, dynamic> json) => BoatMember(
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'viewer',
      );

  final String userId;
  final String name;
  final String role;
}

class BoatShareRepository {
  BoatShareRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  /// Owner: get/create the boat's invite code.
  Future<String> shareCode(String boatId) async {
    final res = await _apiClient
        .put<Map<String, dynamic>>('/api/v1/boats/$boatId/share-code');
    return (res.data!['data'] as Map<String, dynamic>)['code'] as String;
  }

  /// Join a boat with its share code (become a viewer member).
  Future<void> joinBoat(String code) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/join',
      data: {'code': code},
    );
  }

  /// Boats shared with the current user.
  Future<List<Boat>> listShared() async {
    final res =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/boats/shared');
    final data = (res.data!['data'] as List).cast<Map<String, dynamic>>();
    return data.map((j) => BoatModel.fromJson(j).toEntity()).toList();
  }

  /// Owner: list the members a boat is shared with.
  Future<List<BoatMember>> listMembers(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/members');
    final data = (res.data!['data'] as List).cast<Map<String, dynamic>>();
    return data.map(BoatMember.fromJson).toList();
  }

  /// Owner: revoke a member's access.
  Future<void> removeMember(String boatId, String userId) async {
    await _apiClient.delete<void>('/api/v1/boats/$boatId/members/$userId');
  }

  /// Member: leave a shared boat.
  Future<void> leaveBoat(String boatId) async {
    await _apiClient.post<void>('/api/v1/boats/$boatId/leave');
  }
}

final boatShareRepositoryProvider = Provider<BoatShareRepository>(
  (ref) => BoatShareRepository(),
);

final sharedBoatsProvider = FutureProvider<List<Boat>>((ref) async {
  return ref.read(boatShareRepositoryProvider).listShared();
});

final boatMembersProvider =
    FutureProvider.family<List<BoatMember>, String>((ref, boatId) async {
  return ref.read(boatShareRepositoryProvider).listMembers(boatId);
});
