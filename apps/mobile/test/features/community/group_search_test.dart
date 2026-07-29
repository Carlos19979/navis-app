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

/// "I need a group search, for public groups in discover."
///
/// These tests drive the Discover tab of CommunityScreen the way a user does —
/// by typing in the field — and assert what the user gets back: matching clubs,
/// one request per word instead of one per letter, and an honest empty / error
/// state instead of a spinner that never ends.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  late _MockGroupRepository mockRepo;

  setUp(() {
    mockRepo = _MockGroupRepository();
  });

  Widget buildSubject({List<Group> discover = const []}) {
    return buildRoutedTestApp(
      const CommunityScreen(),
      overrides: [
        ...planOverrides(pro: true),
        groupRepositoryProvider.overrideWithValue(mockRepo),
        eventsProvider.overrideWith((ref) async => const []),
        myGroupsProvider.overrideWith((ref) async => <Group>[]),
        discoverGroupsProvider.overrideWith((ref) async => discover),
      ],
    );
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  /// Types [text] in the search field and waits past the debounce window.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  /// Counts the searches that actually reached the repository, so "one request
  /// per word" is an assertion and not a hope.
  int searchCalls = 0;
  List<String> queriesSeen = <String>[];

  setUp(() {
    searchCalls = 0;
    queriesSeen = <String>[];
  });

  void stubSearch(List<Group> results) {
    when(
      () => mockRepo.getGroups(
        discover: any(named: 'discover'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((invocation) async {
      searchCalls++;
      queriesSeen
          .add(invocation.namedArguments[const Symbol('query')] as String);
      return PaginatedResponse<Group>(items: results);
    });
  }

  final palma = makeGroup(myMembershipStatus: 'none', myRole: '');
  final regattaLovers = makeGroup(
    id: 'group-9',
    name: 'Regatta Lovers',
    myMembershipStatus: 'none',
    myRole: '',
  );

  testWidgets('the search field is offered in Discover, not in My groups',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);

    await openTab(tester, 'My groups');
    expect(find.byType(TextField), findsNothing);

    await openTab(tester, 'Discover');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search clubs by name…'), findsOneWidget);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('typing a name shows the clubs that match it', (tester) async {
    setPhoneSize(tester);
    stubSearch([regattaLovers]);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');

    expect(find.text('Palma Sailing Club'), findsOneWidget);

    await search(tester, 'regatta');

    expect(queriesSeen, ['regatta']);
    expect(find.text('Regatta Lovers'), findsOneWidget);
    // The browse list is replaced by the results, not appended to.
    expect(find.text('Palma Sailing Club'), findsNothing);
    // A public club the user is not in can be joined from the results.
    expect(find.text('Request'), findsOneWidget);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a word typed letter by letter costs one request, not five',
      (tester) async {
    setPhoneSize(tester);
    stubSearch([regattaLovers]);
    await tester.pumpWidget(buildSubject());
    await pumpScreen(tester);
    await openTab(tester, 'Discover');

    for (final typed in ['p', 'pa', 'pal', 'palm', 'palma']) {
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    expect(searchCalls, 1);
    expect(queriesSeen, ['palma']);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a single letter is not searched, the user is asked for more',
      (tester) async {
    setPhoneSize(tester);
    stubSearch([regattaLovers]);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, 'p');

    expect(searchCalls, 0);
    expect(find.text('Type at least 2 letters'), findsOneWidget);
    // And no leftover spinner while we wait for the second letter.
    expect(find.byType(NavisShimmer), findsNothing);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('spaces alone are not a query: browsing continues',
      (tester) async {
    setPhoneSize(tester);
    stubSearch([regattaLovers]);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, '   ');

    expect(searchCalls, 0);
    expect(find.text('Palma Sailing Club'), findsOneWidget);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a name nobody has ends in an empty state, not a spinner',
      (tester) async {
    setPhoneSize(tester);
    stubSearch(const []);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, 'zzzz');

    expect(find.text('No clubs match that name.'), findsOneWidget);
    expect(find.byType(NavisShimmer), findsNothing);
    expect(find.byType(NavisErrorWidget), findsNothing);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('while the search is in flight the user sees a loading skeleton',
      (tester) async {
    setPhoneSize(tester);
    final pending = Completer<PaginatedResponse<Group>>();
    when(() => mockRepo.getGroups(discover: true, query: 'regatta'))
        .thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, 'regatta');

    expect(find.byType(NavisShimmer), findsOneWidget);
    // Stale browse results are not passed off as matches.
    expect(find.text('Palma Sailing Club'), findsNothing);

    pending.complete(PaginatedResponse<Group>(items: [regattaLovers]));
    await pumpScreen(tester);

    expect(find.byType(NavisShimmer), findsNothing);
    expect(find.text('Regatta Lovers'), findsOneWidget);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed search explains itself and retry finds the club',
      (tester) async {
    setPhoneSize(tester);
    var attempts = 0;
    when(() => mockRepo.getGroups(discover: true, query: 'regatta'))
        .thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('boom');
      return PaginatedResponse<Group>(items: [regattaLovers]);
    });
    await tester.pumpWidget(buildSubject());
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, 'regatta');

    expect(find.byType(NavisErrorWidget), findsOneWidget);
    expect(find.text("Couldn't search clubs"), findsOneWidget);
    // Never the raw exception.
    expect(find.textContaining('Exception'), findsNothing);

    await tester.tap(find.text('Retry'));
    await pumpScreen(tester);

    expect(attempts, 2);
    expect(find.byType(NavisErrorWidget), findsNothing);
    expect(find.text('Regatta Lovers'), findsOneWidget);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('clearing the field brings the whole discover list back',
      (tester) async {
    setPhoneSize(tester);
    stubSearch(const []);
    await tester.pumpWidget(buildSubject(discover: [palma]));
    await pumpScreen(tester);
    await openTab(tester, 'Discover');
    await search(tester, 'zzzz');

    expect(find.text('No clubs match that name.'), findsOneWidget);
    expect(find.text('Palma Sailing Club'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await pumpScreen(tester);

    expect(find.text('Palma Sailing Club'), findsOneWidget);
    expect(find.text('No clubs match that name.'), findsNothing);
    // Going back to browsing does not fire another search.
    expect(searchCalls, 1);

    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  });
}
