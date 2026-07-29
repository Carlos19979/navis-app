import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/session_provider.dart';
import 'package:navis_mobile/features/boat/data/models/boat_model.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';

/// A user with shared access to a boat.
class BoatMember {
  const BoatMember({
    required this.userId,
    required this.name,
    required this.permissions,
  });

  /// A member with no permissions object grants nothing: members join as
  /// viewers and the owner promotes them, so "unknown" must never read as
  /// "allowed" (see [BoatPermissions]).
  factory BoatMember.fromJson(Map<String, dynamic> json) => BoatMember(
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        permissions: json['permissions'] is Map<String, dynamic>
            ? BoatPermissions.fromJson(
                json['permissions'] as Map<String, dynamic>)
            : const BoatPermissions.none(),
      );

  final String userId;
  final String name;
  final BoatPermissions permissions;
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

  /// What the current user may do on [boatId] (`GET /boats/{id}/permissions`).
  ///
  /// The owner gets everything; a member gets whatever the owner granted.
  /// A caller with no access at all gets a 404, which surfaces as an error —
  /// deliberately, so "no access" is never mistaken for "no permissions yet".
  Future<BoatPermissions> effectivePermissions(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/permissions');
    final data = res.data!['data'] as Map<String, dynamic>;
    return BoatPermissions.fromJson(
      data['permissions'] as Map<String, dynamic>,
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

  /// Owner: set a member's granular permissions.
  Future<void> setMemberPermissions(
      String boatId, String userId, BoatPermissions permissions) async {
    await _apiClient.put<void>(
      '/api/v1/boats/$boatId/members/$userId/permissions',
      data: permissions.toJson(),
    );
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
  ref.watch(sessionUserIdProvider);
  return ref.read(boatShareRepositoryProvider).listShared();
});

/// The boat's invite code, fetched (and created on first use) by the API.
///
/// A provider rather than a bare `await` before opening the share sheet: doing
/// it inline left the tap with no feedback for as long as the round trip took,
/// and then the sheet appeared already-populated after a visible pause. Here
/// the sheet opens at once and shows the code arriving.
final boatShareCodeProvider =
    FutureProvider.autoDispose.family<String, String>((ref, boatId) async {
  ref.watch(sessionUserIdProvider);
  return ref.read(boatShareRepositoryProvider).shareCode(boatId);
});

/// The boat's crew, owner-facing. **autoDispose on purpose:** joining happens
/// on someone *else's* device, so nothing in the owner's app can invalidate a
/// long-lived cache — the owner kept seeing "not shared with anyone yet" after
/// a successful join. Dropping the cache when no screen is showing it means
/// every visit to the crew list asks the server.
final boatMembersProvider = FutureProvider.autoDispose
    .family<List<BoatMember>, String>((ref, boatId) async {
  ref.watch(sessionUserIdProvider);
  return ref.read(boatShareRepositoryProvider).listMembers(boatId);
});
