import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/events_screen.dart';
import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
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
    bool pro = false,
    List<Event> events = const [],
    Future<List<Group>> Function()? myGroups,
    Future<List<Group>> Function()? discover,
    Override? accountOverride,
  }) {
    return buildRoutedTestApp(
      const CommunityScreen(),
      spy: spy,
      overrides: [
        ...planOverrides(pro: pro),
        // Applied after planOverrides so it wins, for the tests that need the
        // account to be pending or failing.
        if (accountOverride != null) accountOverride,
        groupRepositoryProvider.overrideWithValue(mockRepo),
        eventsProvider.overrideWith((ref) async => events),
        myGroupsProvider.overrideWith(
          (ref) => myGroups != null ? myGroups() : Future.value(<Group>[]),
        ),
        discoverGroupsProvider.overrideWith(
          (ref) => discover != null ? discover() : Future.value(<Group>[]),
        ),
      ],
    );
  }

  /// Taps a top tab and pumps the tab transition plus the async providers.
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  group('CommunityScreen tabs', () {
    testWidgets('renders the three tabs with the regattas feed first',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(events: [makeEvent()]));
      await pumpScreen(tester);

      expect(find.text('Regattas'), findsOneWidget);
      expect(find.text('My groups'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      // The Regattas tab embeds the events feed body.
      expect(find.byType(EventsBody), findsOneWidget);
      expect(find.text('Copa del Rey'), findsOneWidget);
    });

    testWidgets('FAB and join-by-code action only appear on clubs tabs',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.byType(NavisGradientFab), findsNothing);
      expect(
        find.widgetWithText(TextButton, 'Join by code'),
        findsNothing,
      );

      await openTab(tester, 'My groups');

      expect(find.byType(NavisGradientFab), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Join by code'),
        findsOneWidget,
      );

      await openTab(tester, 'Discover');

      expect(find.byType(NavisGradientFab), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Join by code'),
        findsOneWidget,
      );

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CommunityScreen my groups states', () {
    testWidgets('loading shows shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<Group>>();
      await tester.pumpWidget(
        buildSubject(myGroups: () => completer.future),
      );
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      expect(find.byType(NavisShimmer), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(myGroups: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the message and a create-group CTA',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      expect(find.text("You're not in any group yet."), findsOneWidget);
      expect(find.text('Create group'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('populated shows the group cards', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(myGroups: () async => [makeGroup()]),
      );
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      expect(find.text('Palma Sailing Club'), findsOneWidget);
    });
  });

  group('CommunityScreen create group gating', () {
    testWidgets('Free tapping the empty CTA sees the paywall, no navigation',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      await tester.tap(find.text('Create group'));
      await pumpScreen(tester);

      expectPaywall();
      expect(spy.locations, isEmpty);
    });

    testWidgets('Pro tapping the empty CTA navigates to /groups/new',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy, pro: true));
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      await tester.tap(find.text('Create group'));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(spy.last, '/groups/new');
    });

    testWidgets('a Pro user is not shown the paywall while /me is in flight',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      // The account request has not landed when the user taps. Reading the tier
      // synchronously reports free here, which used to paywall a paid user.
      final account = Completer<Account>();
      addTearDown(() {
        if (!account.isCompleted) {
          account.complete(accountForTier(PlanTier.pro));
        }
      });
      await tester.pumpWidget(
        buildSubject(
          spy: spy,
          accountOverride: accountProvider.overrideWith((_) => account.future),
        ),
      );
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      await tester.tap(find.text('Create group'));
      await tester.pump();

      // Nothing decided yet: no paywall on a maybe.
      expectPaywall(shown: false);

      account.complete(accountForTier(PlanTier.pro));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(spy.last, '/groups/new');
    });

    testWidgets('an unknown plan asks the user to retry, not to pay',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(
          spy: spy,
          accountOverride: accountProvider.overrideWith(
            (_) async => throw Exception('offline'),
          ),
        ),
      );
      await pumpScreen(tester);
      await openTab(tester, 'My groups');

      await tester.tap(find.text('Create group'));
      await pumpScreen(tester);

      // A failed plan check is not evidence the user is on Free.
      expectPaywall(shown: false);
      expect(spy.locations, isEmpty);
      expectSnackbar(
          tester,
          "We couldn't check your plan. "
          'Check your connection and try again.');
    });
  });

  group('CommunityScreen discover states', () {
    testWidgets('loading shows shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<Group>>();
      await tester.pumpWidget(
        buildSubject(discover: () => completer.future),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      expect(find.byType(NavisShimmer), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(discover: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the no-public-groups message', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      expect(find.text('No public groups to discover.'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('populated shows group cards with a Request action',
        (tester) async {
      setPhoneSize(tester);
      final discoverable = makeGroup(
        myMembershipStatus: 'none',
        myRole: '',
      );
      await tester.pumpWidget(
        buildSubject(discover: () async => [discoverable]),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      expect(find.text('Palma Sailing Club'), findsOneWidget);
      expect(find.text('Request'), findsOneWidget);
    });
  });

  group('CommunityScreen discover join', () {
    final discoverable = makeGroup(myMembershipStatus: 'none', myRole: '');

    testWidgets('Request calls requestJoin and shows a success snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.requestJoin('group-1'))
          .thenAnswer((_) async => makeGroup(myMembershipStatus: 'pending'));
      await tester.pumpWidget(
        buildSubject(discover: () async => [discoverable]),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      await tester.tap(find.text('Request'));
      await pumpScreen(tester);

      verify(() => mockRepo.requestJoin('group-1')).called(1);
      expectSnackbar(tester, 'Request sent');
    });

    testWidgets('Request failure shows an error snackbar', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.requestJoin('group-1')).thenThrow(Exception('boom'));
      await tester.pumpWidget(
        buildSubject(discover: () async => [discoverable]),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      await tester.tap(find.text('Request'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not send request');
    });

    testWidgets('a pending group shows the Pending label instead of Request',
        (tester) async {
      setPhoneSize(tester);
      final pending = makeGroup(myMembershipStatus: 'pending', myRole: '');
      await tester.pumpWidget(
        buildSubject(discover: () async => [pending]),
      );
      await pumpScreen(tester);
      await openTab(tester, 'Discover');

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Request'), findsNothing);
    });
  });

  group('CommunityScreen join by code', () {
    Future<void> openDialog(WidgetTester tester) async {
      await openTab(tester, 'My groups');
      await tester.tap(find.widgetWithText(TextButton, 'Join by code'));
      await pumpScreen(tester);
    }

    testWidgets('joins with the entered code and shows a success snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.joinByCode('ABC123'))
          .thenAnswer((_) async => makeGroup());
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDialog(tester);

      expect(find.text('Join a club'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.pump();
      await tester.tap(find.text('Join'));
      await pumpScreen(tester);

      verify(() => mockRepo.joinByCode('ABC123')).called(1);
      expectSnackbar(tester, "You've joined Palma Sailing Club");
    });

    testWidgets('invalid code shows an error snackbar', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.joinByCode(any())).thenThrow(Exception('404'));
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'WRONG1');
      await tester.pump();
      await tester.tap(find.text('Join'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Invalid code or error joining');
    });

    testWidgets('cancelling the dialog does not call the repository',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.joinByCode(any()));
    });
  });
}
