import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/lifecycle/resume_refresh.dart';
import 'package:navis_mobile/core/network/session_provider.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// Groups the current user is an active member of.
final myGroupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  final response = await repo.getGroups();
  return response.items;
});

/// Discoverable public groups the user has not yet joined.
final discoverGroupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  final response = await repo.getGroups(discover: true);
  return response.items;
});

final groupProvider = FutureProvider.family<Group, String>((ref, id) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getGroup(id);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, id) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getMembers(id);
});

/// Pending join requests, for the owner. The whole point of the foreground
/// refresh: this is the owner's inbox, and it was only ever fetched once.
final groupRequestsProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, id) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.lists);
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(groupRepositoryProvider);
  return repo.getRequests(id);
});

/// Membership mutations together with the invalidation they imply.
///
/// Screens call these instead of [GroupRepository] directly, so a join can no
/// longer leave one list showing the truth and the other showing what the
/// server said minutes ago. Asking for a public group used to invalidate
/// `discoverGroups` only, which is why the club kept reading as *pending*
/// until the user pulled to refresh.
class GroupMembershipActions {
  GroupMembershipActions(this._ref);

  final Ref _ref;

  /// Asks to join a public group. The owner has to approve.
  Future<Group> requestJoin(String groupId) async {
    final group = await _ref.read(groupRepositoryProvider).requestJoin(groupId);
    _refreshLists(groupId);
    return group;
  }

  /// Joins a private group with its invite code.
  Future<Group> joinByCode(String code) async {
    final group = await _ref.read(groupRepositoryProvider).joinByCode(code);
    _refreshLists(group.id);
    return group;
  }

  Future<void> leave(String groupId) async {
    await _ref.read(groupRepositoryProvider).leaveGroup(groupId);
    _refreshLists(groupId);
  }

  /// Approves a pending request. Refreshes the requests inbox and the member
  /// list, which both change, plus the group itself for its member count.
  Future<void> approveRequest(String groupId, String userId) async {
    await _ref.read(groupRepositoryProvider).approveRequest(groupId, userId);
    _refreshMembership(groupId);
  }

  Future<void> rejectRequest(String groupId, String userId) async {
    await _ref.read(groupRepositoryProvider).rejectRequest(groupId, userId);
    _refreshMembership(groupId);
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _ref.read(groupRepositoryProvider).removeMember(groupId, userId);
    _refreshMembership(groupId);
  }

  /// Both lists, always: whether a group belongs in "my clubs" or in
  /// "discover" is exactly what a membership change decides.
  void _refreshLists(String groupId) {
    _ref.invalidate(discoverGroupsProvider);
    _ref.invalidate(myGroupsProvider);
    _ref.invalidate(groupProvider(groupId));
  }

  void _refreshMembership(String groupId) {
    _ref.invalidate(groupRequestsProvider(groupId));
    _ref.invalidate(groupMembersProvider(groupId));
    _ref.invalidate(groupProvider(groupId));
    _ref.invalidate(myGroupsProvider);
  }
}

final groupMembershipActionsProvider = Provider<GroupMembershipActions>(
  GroupMembershipActions.new,
);
