import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// Groups the current user is an active member of.
final myGroupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  final response = await repo.getGroups();
  return response.items;
});

/// Discoverable public groups the user has not yet joined.
final discoverGroupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  final response = await repo.getGroups(discover: true);
  return response.items;
});

final groupProvider = FutureProvider.family<Group, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroup(id);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getMembers(id);
});

final groupRequestsProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getRequests(id);
});
