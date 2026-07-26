import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

import '../../helpers/lifecycle.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

Group _group(
  String id, {
  String status = 'active',
  String role = 'member',
}) =>
    Group(
      id: id,
      ownerId: 'owner-1',
      name: 'Club $id',
      visibility: 'public',
      myMembershipStatus: status,
      myRole: role,
    );

GroupMember _member(String userId) => GroupMember(
      userId: userId,
      name: 'Member $userId',
      role: 'member',
      status: 'pending',
    );

void main() {
  late FakeLifecycle lifecycle;
  late MockGroupRepository repository;

  setUp(() {
    lifecycle = FakeLifecycle();
    addTearDown(lifecycle.dispose);
    repository = MockGroupRepository();
    when(() => repository.getGroups(discover: any(named: 'discover')))
        .thenAnswer(
            (_) async => PaginatedResponse<Group>(items: [_group('a')]));
    when(() => repository.getGroup(any()))
        .thenAnswer((invocation) async => _group('a'));
    when(() => repository.getMembers(any()))
        .thenAnswer((_) async => [_member('u1')]);
    when(() => repository.getRequests(any()))
        .thenAnswer((_) async => [_member('u2')]);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        ...lifecycle.overrides,
        groupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('foreground refresh', () {
    test('my clubs refetches when the app comes back', () async {
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(myGroupsProvider.future);

      verify(() => repository.getGroups()).called(1);
    });

    test('discover refetches when the app comes back', () async {
      final container = makeContainer();
      container.listen(discoverGroupsProvider, (_, __) {});
      await container.read(discoverGroupsProvider.future);
      verify(() => repository.getGroups(discover: true)).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(discoverGroupsProvider.future);

      verify(() => repository.getGroups(discover: true)).called(1);
    });

    test("the owner's join requests refetch when the app comes back", () async {
      // The inbox that used to need a manual pull: a request arrives while the
      // owner is elsewhere, and reopening Navis has to show it.
      final container = makeContainer();
      container.listen(groupRequestsProvider('g1'), (_, __) {});
      await container.read(groupRequestsProvider('g1').future);
      verify(() => repository.getRequests('g1')).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(groupRequestsProvider('g1').future);

      verify(() => repository.getRequests('g1')).called(1);
    });

    test('group detail and members refetch when the app comes back', () async {
      final container = makeContainer();
      container.listen(groupProvider('g1'), (_, __) {});
      container.listen(groupMembersProvider('g1'), (_, __) {});
      await container.read(groupProvider('g1').future);
      await container.read(groupMembersProvider('g1').future);
      verify(() => repository.getGroup('g1')).called(1);
      verify(() => repository.getMembers('g1')).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(groupProvider('g1').future);
      await container.read(groupMembersProvider('g1').future);

      verify(() => repository.getGroup('g1')).called(1);
      verify(() => repository.getMembers('g1')).called(1);
    });

    test('a few seconds away is not worth a refetch', () async {
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);

      lifecycle.leaveAndReturn(away: const Duration(seconds: 5));
      await lifecycle.settle(container);

      verifyNever(() => repository.getGroups());
    });

    test('an inactive blip does not refetch', () async {
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);

      lifecycle.blip();
      await lifecycle.settle(container);

      verifyNever(() => repository.getGroups());
    });

    test('lists nobody is watching are not refetched on resume', () async {
      // Both lists stay alive once Community has been opened, so a resume must
      // not fire their requests while the user sits on another tab.
      final container = makeContainer();
      await container.read(myGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);

      verifyNever(() => repository.getGroups());

      // ...but the data is stale, so reopening the tab does refetch.
      await container.read(myGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);
    });
  });

  group('GroupMembershipActions.requestJoin', () {
    test('refreshes both lists, not just discover', () async {
      // The build-4 bug: only discover was invalidated, so "my clubs" kept
      // showing the pre-request state until the user pulled to refresh.
      when(() => repository.requestJoin('g1'))
          .thenAnswer((_) async => _group('g1', status: 'pending'));
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      container.listen(discoverGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      await container.read(discoverGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);

      await container.read(groupMembershipActionsProvider).requestJoin('g1');
      await container.pump();

      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);
    });

    test('returns the group the server reports as pending', () async {
      when(() => repository.requestJoin('g1'))
          .thenAnswer((_) async => _group('g1', status: 'pending'));
      final container = makeContainer();

      final group = await container
          .read(groupMembershipActionsProvider)
          .requestJoin('g1');

      expect(group.isPending, isTrue);
    });

    test('a failed request invalidates nothing', () async {
      when(() => repository.requestJoin('g1')).thenThrow(Exception('boom'));
      final container = makeContainer();
      container.listen(discoverGroupsProvider, (_, __) {});
      await container.read(discoverGroupsProvider.future);
      verify(() => repository.getGroups(discover: true)).called(1);

      await expectLater(
        container.read(groupMembershipActionsProvider).requestJoin('g1'),
        throwsException,
      );
      await container.pump();

      verifyNever(() => repository.getGroups(discover: true));
    });
  });

  group('GroupMembershipActions', () {
    test('joinByCode refreshes both lists', () async {
      when(() => repository.joinByCode('ABC123'))
          .thenAnswer((_) async => _group('g1'));
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      container.listen(discoverGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      await container.read(discoverGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);

      await container.read(groupMembershipActionsProvider).joinByCode('ABC123');
      await container.pump();

      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);
    });

    test('approveRequest refreshes the inbox, the members and the group',
        () async {
      when(() => repository.approveRequest('g1', 'u2'))
          .thenAnswer((_) async {});
      final container = makeContainer();
      container.listen(groupRequestsProvider('g1'), (_, __) {});
      container.listen(groupMembersProvider('g1'), (_, __) {});
      container.listen(groupProvider('g1'), (_, __) {});
      await container.read(groupRequestsProvider('g1').future);
      await container.read(groupMembersProvider('g1').future);
      await container.read(groupProvider('g1').future);
      verify(() => repository.getRequests('g1')).called(1);
      verify(() => repository.getMembers('g1')).called(1);
      verify(() => repository.getGroup('g1')).called(1);

      await container
          .read(groupMembershipActionsProvider)
          .approveRequest('g1', 'u2');
      await container.pump();

      verify(() => repository.getRequests('g1')).called(1);
      verify(() => repository.getMembers('g1')).called(1);
      verify(() => repository.getGroup('g1')).called(1);
    });

    test('rejectRequest refreshes the inbox', () async {
      when(() => repository.rejectRequest('g1', 'u2')).thenAnswer((_) async {});
      final container = makeContainer();
      container.listen(groupRequestsProvider('g1'), (_, __) {});
      await container.read(groupRequestsProvider('g1').future);
      verify(() => repository.getRequests('g1')).called(1);

      await container
          .read(groupMembershipActionsProvider)
          .rejectRequest('g1', 'u2');
      await container.pump();

      verify(() => repository.getRequests('g1')).called(1);
    });

    test('removeMember refreshes the member list', () async {
      when(() => repository.removeMember('g1', 'u1')).thenAnswer((_) async {});
      final container = makeContainer();
      container.listen(groupMembersProvider('g1'), (_, __) {});
      await container.read(groupMembersProvider('g1').future);
      verify(() => repository.getMembers('g1')).called(1);

      await container
          .read(groupMembershipActionsProvider)
          .removeMember('g1', 'u1');
      await container.pump();

      verify(() => repository.getMembers('g1')).called(1);
    });

    test('leave refreshes both lists', () async {
      when(() => repository.leaveGroup('g1')).thenAnswer((_) async {});
      final container = makeContainer();
      container.listen(myGroupsProvider, (_, __) {});
      container.listen(discoverGroupsProvider, (_, __) {});
      await container.read(myGroupsProvider.future);
      await container.read(discoverGroupsProvider.future);
      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);

      await container.read(groupMembershipActionsProvider).leave('g1');
      await container.pump();

      verify(() => repository.getGroups()).called(1);
      verify(() => repository.getGroups(discover: true)).called(1);
    });
  });
}
