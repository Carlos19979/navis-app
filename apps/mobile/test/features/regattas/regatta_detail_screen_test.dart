import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/regatta_detail_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/helpers.dart';

class _MockRegattaRepository extends Mock implements RegattaRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    // Owner checks compare against the fake session user (user-1).
    await signInFakeUser();
  });

  const regattaId = 'r1';

  late _MockRegattaRepository mockRepo;

  setUp(() {
    mockRepo = _MockRegattaRepository();
  });

  Widget buildSubject({
    RouteSpy? spy,
    Regatta? regatta,
    Future<Regatta> Function()? fetchRegatta,
    List<RegattaParticipant> participants = const [],
    List<GroupMember> members = const [],
  }) {
    return buildRoutedTestApp(
      const RegattaDetailScreen(regattaId: regattaId),
      spy: spy,
      overrides: [
        regattaRepositoryProvider.overrideWithValue(mockRepo),
        regattaProvider.overrideWith(
          (ref, id) => fetchRegatta != null
              ? fetchRegatta()
              : Future.value(regatta ?? makeRegatta(id: regattaId)),
        ),
        regattaParticipantsProvider.overrideWith(
          (ref, id) async => participants,
        ),
        groupMembersProvider.overrideWith((ref, id) async => members),
      ],
    );
  }

  group('RegattaDetailScreen async states', () {
    testWidgets('loading shows the loading indicator', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<Regatta>();
      await tester.pumpWidget(
        buildSubject(fetchRegatta: () => completer.future),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavisLoading), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(fetchRegatta: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
    });

    testWidgets('populated shows title, port and date', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      // App bar + summary card.
      expect(find.text('Spring Cup'), findsWidgets);
      expect(find.text('Palma de Mallorca'), findsOneWidget);
      expect(find.text('Are you going?'), findsOneWidget);
    });
  });

  group('RegattaDetailScreen status badge', () {
    for (final (status, label) in [
      ('planned', 'Scheduled'),
      ('recording', 'In progress'),
      ('completed', 'Completed'),
      ('cancelled', 'Cancelled'),
    ]) {
      testWidgets('$status shows the $label badge', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(
          buildSubject(regatta: makeRegatta(id: regattaId, status: status)),
        );
        await pumpScreen(tester);

        expect(find.text(label), findsOneWidget);
      });
    }
  });

  group('RegattaDetailScreen RSVP', () {
    testWidgets('tapping a pill sends the RSVP', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.setRsvp(regattaId, 'going')).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Going').first);
      await pumpScreen(tester);

      verify(() => mockRepo.setRsvp(regattaId, 'going')).called(1);
    });

    testWidgets('RSVP failure shows an error snackbar', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.setRsvp(regattaId, 'maybe'))
          .thenThrow(Exception('boom'));
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Maybe').first);
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not respond');
    });

    testWidgets('participants card shows going/maybe/not-going counts',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          // No group so only the counts card renders.
          regatta: makeRegatta(id: regattaId, groupId: null),
          participants: const [
            RegattaParticipant(userId: 'user-2', rsvp: 'going'),
            RegattaParticipant(userId: 'user-3', rsvp: 'going'),
            RegattaParticipant(userId: 'user-4', rsvp: 'maybe'),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('group members list shows each member with RSVP status',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          participants: const [
            RegattaParticipant(userId: 'user-2', rsvp: 'going'),
          ],
          members: const [
            GroupMember(
              userId: 'user-1',
              name: 'Carlos',
              role: 'owner',
              status: 'active',
            ),
            GroupMember(
              userId: 'user-2',
              name: 'Maria',
              role: 'member',
              status: 'active',
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
    });
  });

  group('RegattaDetailScreen owner controls', () {
    testWidgets('planned: checklist CTA navigates to the checklist',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        find.text('Prepare checklist and set sail'),
        200,
      );
      await tester.tap(find.text('Prepare checklist and set sail'));
      await pumpScreen(tester);

      expect(spy.last, '/trips/$regattaId/checklist?groupId=group-1');
    });

    testWidgets('planned: cancel regatta calls the repository', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.cancel(regattaId)).thenAnswer(
        (_) async => makeRegatta(id: regattaId, status: 'cancelled'),
      );
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.scrollUntilVisible(find.text('Cancel regatta'), 200);
      await tester.tap(find.text('Cancel regatta'));
      await pumpScreen(tester);

      verify(() => mockRepo.cancel(regattaId)).called(1);
      expectSnackbar(tester, 'Regatta cancelled');
    });

    testWidgets('recording: shows the in-progress card', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          regatta: makeRegatta(id: regattaId, status: 'recording'),
        ),
      );
      await pumpScreen(tester);

      expect(
        find.text('The regatta is under way (recording).'),
        findsOneWidget,
      );
      expect(find.text('Prepare checklist and set sail'), findsNothing);
    });

    testWidgets('completed: delete asks for confirmation then deletes',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.delete(regattaId)).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(
          regatta: makeRegatta(id: regattaId, status: 'completed'),
        ),
      );
      await pumpScreen(tester);

      await tester.scrollUntilVisible(find.text('Delete regatta'), 200);
      await tester.tap(find.text('Delete regatta'));
      await pumpScreen(tester);

      await tester.tap(find.text('Delete'));
      await pumpScreen(tester);

      verify(() => mockRepo.delete(regattaId)).called(1);
      expectSnackbar(tester, 'Regatta deleted');
    });

    testWidgets('non-owner sees no owner controls', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          regatta: makeRegatta(id: regattaId, ownerId: 'user-2'),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Prepare checklist and set sail'), findsNothing);
      expect(find.text('Cancel regatta'), findsNothing);
      expect(find.text('Delete regatta'), findsNothing);
      // The RSVP pills stay available to participants.
      expect(find.text('Are you going?'), findsOneWidget);
    });
  });
}
