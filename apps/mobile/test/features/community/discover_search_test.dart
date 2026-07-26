import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/helpers.dart';

class _MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  late _MockGroupRepository mockRepo;

  setUp(() {
    mockRepo = _MockGroupRepository();
  });

  Widget buildSubject({
    RouteSpy? spy,
    List<Group> discover = const [],
  }) {
    return buildRoutedTestApp(
      const CommunityScreen(),
      spy: spy,
      overrides: [
        ...planOverrides(pro: true),
        groupRepositoryProvider.overrideWithValue(mockRepo),
        eventsProvider.overrideWith((ref) async => const []),
        myGroupsProvider.overrideWith((ref) async => <Group>[]),
        discoverGroupsProvider.overrideWith((ref) async => discover),
      ],
    );
  }

  Future<void> openDiscover(WidgetTester tester) async {
    await tester.tap(find.text('Discover'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  /// Types [text] in the search field and lets the 300 ms debounce elapse.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));
  }

  void stubSearch(String query, List<Group> results) {
    when(() => mockRepo.getGroups(discover: true, query: query)).thenAnswer(
      (_) async => PaginatedResponse<Group>(items: results),
    );
  }

  group('Discover search', () {
    testWidgets('an empty field browses the discover list', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(discover: [makeGroup(myMembershipStatus: 'none')]),
      );
      await pumpScreen(tester);
      await openDiscover(tester);

      expect(find.text('Palma Sailing Club'), findsOneWidget);
      verifyNever(
        () => mockRepo.getGroups(
          discover: any(named: 'discover'),
          query: any(named: 'query'),
        ),
      );

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('one letter asks for more instead of searching',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'p');

      expect(find.text('Type at least 2 letters'), findsOneWidget);
      verifyNever(
        () => mockRepo.getGroups(
          discover: any(named: 'discover'),
          query: any(named: 'query'),
        ),
      );

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('searching shows the matching clubs with a Request action',
        (tester) async {
      setPhoneSize(tester);
      stubSearch('reg', [
        makeGroup(
          id: 'group-9',
          name: 'Regatta Lovers',
          myMembershipStatus: 'none',
          myRole: '',
        ),
      ]);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'reg');

      verify(() => mockRepo.getGroups(discover: true, query: 'reg')).called(1);
      expect(find.text('Regatta Lovers'), findsOneWidget);
      expect(find.text('Request'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('debounce sends one request for a word typed letter by letter',
        (tester) async {
      setPhoneSize(tester);
      stubSearch('reg', const []);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);

      await tester.enterText(find.byType(TextField), 'r');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 're');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'reg');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockRepo.getGroups(discover: true, query: 'reg')).called(1);
      verifyNever(() => mockRepo.getGroups(discover: true, query: 're'));

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('loading shows the shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<PaginatedResponse<Group>>();
      when(() => mockRepo.getGroups(discover: true, query: 'reg'))
          .thenAnswer((_) => completer.future);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'reg');

      expect(find.byType(NavisShimmer), findsOneWidget);

      completer.complete(const PaginatedResponse<Group>(items: []));
      await drain(tester);
    });

    testWidgets('no matches shows the not-found message', (tester) async {
      setPhoneSize(tester);
      stubSearch('zzz', const []);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'zzz');

      expect(find.text('No clubs match that name.'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed search shows a friendly error, not the exception',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.getGroups(discover: true, query: 'reg'))
          .thenThrow(Exception('boom'));
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'reg');

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      expect(find.text("Couldn't search clubs"), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('clearing the field goes back to browsing', (tester) async {
      setPhoneSize(tester);
      stubSearch('zzz', const []);
      await tester.pumpWidget(
        buildSubject(discover: [makeGroup(myMembershipStatus: 'none')]),
      );
      await pumpScreen(tester);
      await openDiscover(tester);
      await search(tester, 'zzz');

      expect(find.text('No clubs match that name.'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await pumpScreen(tester);

      expect(find.text('Palma Sailing Club'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
