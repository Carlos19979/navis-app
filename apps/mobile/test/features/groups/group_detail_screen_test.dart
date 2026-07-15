import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/helpers.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    // The screen resolves the current user against the Supabase session
    // (the fake session signs in as user-1).
    await signInFakeUser();
  });

  const groupId = 'g1';

  late _MockGroupRepository mockRepo;

  setUp(() {
    mockRepo = _MockGroupRepository();
  });

  GroupMember makeMember({
    String userId = 'user-2',
    String name = 'Maria',
    String role = 'member',
    String status = 'active',
  }) {
    return GroupMember(userId: userId, name: name, role: role, status: status);
  }

  Widget buildSubject({
    RouteSpy? spy,
    Group? group,
    Future<Group> Function()? fetchGroup,
    List<GroupMember> members = const [],
    List<GroupMember> requests = const [],
    Future<List<Regatta>> Function()? regattas,
  }) {
    return buildRoutedTestApp(
      const GroupDetailScreen(groupId: groupId),
      spy: spy,
      overrides: [
        groupRepositoryProvider.overrideWithValue(mockRepo),
        groupProvider.overrideWith(
          (ref, id) => fetchGroup != null
              ? fetchGroup()
              : Future.value(group ?? makeGroup(id: groupId)),
        ),
        groupMembersProvider.overrideWith((ref, id) async => members),
        groupRequestsProvider.overrideWith((ref, id) async => requests),
        groupRegattasProvider.overrideWith(
          (ref, id) =>
              regattas != null ? regattas() : Future.value(<Regatta>[]),
        ),
      ],
    );
  }

  group('GroupDetailScreen async states', () {
    testWidgets('loading shows the loading indicator', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<Group>();
      await tester.pumpWidget(
        buildSubject(fetchGroup: () => completer.future),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavisLoading), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(fetchGroup: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
    });

    testWidgets('populated shows name, visibility and member count',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      // App bar title + header card.
      expect(find.text('Palma Sailing Club'), findsWidgets);
      expect(find.text('Public · 5 members'), findsOneWidget);
      expect(find.text('Weekend sailors'), findsOneWidget);
    });

    testWidgets('a private group shows the private label', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(group: makeGroup(id: groupId, visibility: 'private')),
      );
      await pumpScreen(tester);

      expect(find.text('Private · 5 members'), findsOneWidget);
    });
  });

  group('GroupDetailScreen invite code', () {
    testWidgets('owner of a private group sees the invite-code card',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(
            id: groupId,
            visibility: 'private',
            inviteCode: 'ABC123',
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
    });

    testWidgets('a public group hides the invite-code card even for owner',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(group: makeGroup(id: groupId, inviteCode: 'ABC123')),
      );
      await pumpScreen(tester);

      expect(find.text('Invite code'), findsNothing);
    });

    testWidgets('a non-owner member never sees the invite-code card',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(
            id: groupId,
            visibility: 'private',
            inviteCode: 'ABC123',
            myRole: 'member',
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Invite code'), findsNothing);
    });
  });

  group('GroupDetailScreen join requests', () {
    final request = makeMember(
      userId: 'user-9',
      name: 'Pepe',
      status: 'pending',
    );

    testWidgets('owner sees pending requests with admit/reject actions',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(requests: [request]));
      await pumpScreen(tester);

      expect(find.text('Requests (1)'), findsOneWidget);
      expect(find.text('Pepe'), findsOneWidget);
      expect(find.byTooltip('Admit'), findsOneWidget);
      expect(find.byTooltip('Reject'), findsOneWidget);
    });

    testWidgets('non-owner does not see the requests section', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(id: groupId, myRole: 'member'),
          requests: [request],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Requests (1)'), findsNothing);
    });

    testWidgets('admit calls approveRequest and shows a snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.approveRequest(groupId, 'user-9'))
          .thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject(requests: [request]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Admit'));
      await pumpScreen(tester);

      verify(() => mockRepo.approveRequest(groupId, 'user-9')).called(1);
      expectSnackbar(tester, 'Request admitted');
    });

    testWidgets('reject calls rejectRequest and shows a snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.rejectRequest(groupId, 'user-9'))
          .thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject(requests: [request]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Reject'));
      await pumpScreen(tester);

      verify(() => mockRepo.rejectRequest(groupId, 'user-9')).called(1);
      expectSnackbar(tester, 'Request rejected');
    });
  });

  group('GroupDetailScreen regattas section', () {
    testWidgets('loading shows a spinner within the section', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<Regatta>>();
      await tester.pumpWidget(
        buildSubject(regattas: () => completer.future),
      );
      await pumpScreen(tester);

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(regattas: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the no-regattas message', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('No regattas scheduled.'), findsOneWidget);
    });

    testWidgets('populated shows one status badge per lifecycle state',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          regattas: () async => [
            makeRegatta(id: 'r-1'),
            makeRegatta(id: 'r-2', title: 'Live Now', status: 'recording'),
            makeRegatta(id: 'r-3', title: 'Old One', status: 'completed'),
            makeRegatta(id: 'r-4', title: 'Rained Out', status: 'cancelled'),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Spring Cup'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('Schedule navigates to the schedule-regatta screen',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Schedule'));
      await pumpScreen(tester);

      expect(spy.last, '/groups/$groupId/schedule');
    });

    testWidgets('non-member does not see the regattas section', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(
            id: groupId,
            myMembershipStatus: 'none',
            myRole: '',
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Regattas & outings'), findsNothing);
      expect(find.text('Schedule'), findsNothing);
    });
  });

  group('GroupDetailScreen members', () {
    final members = [
      makeMember(userId: 'user-1', name: 'Carlos', role: 'owner'),
      makeMember(),
    ];

    testWidgets('shows You for the session user and a star for the owner',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(members: members));
      await pumpScreen(tester);

      expect(find.text('You · Owner'), findsOneWidget);
      expect(find.text('Maria · Member'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('owner can expel a member', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.removeMember(groupId, 'user-2'))
          .thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject(members: members));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Remove'));
      await pumpScreen(tester);

      verify(() => mockRepo.removeMember(groupId, 'user-2')).called(1);
      expectSnackbar(tester, 'Member removed');
    });

    testWidgets('non-owner sees no expel action', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(id: groupId, myRole: 'member'),
          members: members,
        ),
      );
      await pumpScreen(tester);

      expect(find.byTooltip('Remove'), findsNothing);
    });
  });

  group('GroupDetailScreen bottom actions', () {
    testWidgets('owner sees Delete group and deletes after confirming',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.deleteGroup(groupId)).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.scrollUntilVisible(find.text('Delete group'), 200);
      await tester.tap(find.text('Delete group'));
      await pumpScreen(tester);

      // Confirm dialog: title + confirm button share the label.
      expect(find.text('Delete group'), findsWidgets);

      await tester.tap(find.text('Delete group').last);
      await pumpScreen(tester);

      verify(() => mockRepo.deleteGroup(groupId)).called(1);
      expectSnackbar(tester, 'Group deleted');
    });

    testWidgets('member sees Leave group and leaves after confirming',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.leaveGroup(groupId)).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(group: makeGroup(id: groupId, myRole: 'member')),
      );
      await pumpScreen(tester);

      expect(find.text('Delete group'), findsNothing);

      await tester.scrollUntilVisible(find.text('Leave group'), 200);
      await tester.tap(find.text('Leave group'));
      await pumpScreen(tester);

      expect(
        find.text('Do you want to leave this group?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirm'));
      await pumpScreen(tester);

      verify(() => mockRepo.leaveGroup(groupId)).called(1);
      expectSnackbar(tester, "You've left the group");
    });

    testWidgets('cancelling leave keeps the membership', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(group: makeGroup(id: groupId, myRole: 'member')),
      );
      await pumpScreen(tester);

      await tester.scrollUntilVisible(find.text('Leave group'), 200);
      await tester.tap(find.text('Leave group'));
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.leaveGroup(any()));
    });

    testWidgets('non-member sees neither delete nor leave', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          group: makeGroup(
            id: groupId,
            myMembershipStatus: 'none',
            myRole: '',
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Delete group'), findsNothing);
      expect(find.text('Leave group'), findsNothing);
    });
  });
}
