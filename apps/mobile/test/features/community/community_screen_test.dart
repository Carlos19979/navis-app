import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
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

  /// Everything is on one page now, so «go to the clubs» is a scroll, not a
  /// tab tap — and often not even that, since the sections are stacked.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await pumpFrames(tester, frames: 8);
    await scrollUntilVisible(tester, target, communityScrollKey);
  }

  /// Creating a club is the FAB now, not a CTA inside an empty tab.
  Future<void> tapCreateClub(WidgetTester tester) async {
    await pumpFrames(tester, frames: 8);
    await tester.tap(find.byType(NavisGradientFab));
    await pumpScreen(tester);
  }

  group('CommunityScreen is one feed', () {
    testWidgets('regattas and both club sections are on the same page',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(events: [makeEvent()]));

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(communityScrollKey),
      );

      // Section headings, tracked uppercase — not tabs.
      expect(labels, containsAll(['REGATTAS', 'MY CLUBS', 'DISCOVER CLUBS']));
      expect(labels, contains('Copa del Rey'));
      expect(find.byType(TabBar), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('both actions are always there, not behind a tab index',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpFrames(tester, frames: 8);

      // The old screen hid the FAB and «join by code» on the regattas tab, so
      // the same screen offered different doors depending on where you had
      // left it.
      expect(find.byType(NavisGradientFab), findsOneWidget);
      await scrollUntilVisible(
        tester,
        find.widgetWithText(TextButton, 'Join by code'),
        communityScrollKey,
      );
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
      await pumpFrames(tester, frames: 8);

      // One skeleton per section that is still loading.
      expect(find.byType(NavisShimmer), findsWidgets);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(myGroups: () async => throw Exception('boom')),
      );
      await reveal(tester, find.byType(NavisErrorWidget));

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the message and a create-group CTA',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      final labels = await scrollAndCollectText(
        tester,
        find.byKey(communityScrollKey),
      );

      // A section with nothing in it says so in one muted line; the way to
      // create a club is the FAB, which is always on screen.
      expect(labels, contains("You're not in a club yet."));
      expect(find.byType(NavisGradientFab), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('populated shows the group cards', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(myGroups: () async => [makeGroup()]),
      );
      await reveal(tester, find.text('Palma Sailing Club'));

      expect(find.text('Palma Sailing Club'), findsOneWidget);
    });
  });

  group('CommunityScreen create group gating', () {
    testWidgets(
        'Free tapping the create button sees the paywall, no navigation',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await tapCreateClub(tester);

      expectPaywall();
      expect(spy.locations, isEmpty);
    });

    testWidgets('Pro tapping the create button navigates to /groups/new',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy, pro: true));
      await tapCreateClub(tester);

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
      await pumpFrames(tester, frames: 8);
      await tester.tap(find.byType(NavisGradientFab));
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
      await tapCreateClub(tester);

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
      await pumpFrames(tester, frames: 8);

      expect(find.byType(NavisShimmer), findsWidgets);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(discover: () async => throw Exception('boom')),
      );
      await reveal(tester, find.byType(NavisErrorWidget));

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the no-public-groups message', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      final labels = await scrollAndCollectText(
        tester,
        find.byKey(communityScrollKey),
      );

      expect(labels, contains('No public clubs to discover.'));

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
      await reveal(tester, find.text('Palma Sailing Club'));

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
      await reveal(tester, find.text('Request'));

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
      await reveal(tester, find.text('Request'));

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
      await reveal(tester, find.text('Pending'));

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Request'), findsNothing);
    });
  });

  group('CommunityScreen join by code', () {
    // The sheet's own field: the feed has a search field of its own now, so
    // `byType(TextField)` matches two.
    final codeField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );

    Future<void> openDialog(WidgetTester tester) async {
      final button = find.widgetWithText(TextButton, 'Join by code');
      await reveal(tester, button);
      await tester.tap(button);
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

      // Scoped to the sheet: the feed has its own search field now, so
      // `byType(TextField)` matches two.
      await tester.enterText(codeField, 'ABC123');
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

      await tester.enterText(codeField, 'WRONG1');
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
