import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/pre_trip_checklist_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/helpers.dart';

class _MockRegattaRepository extends Mock implements RegattaRepository {}

/// How many checklist items are on screen.
///
/// The items are [NavisRow]s now, not `Checkbox`es: the whole row toggles, so
/// the target is 48 dp instead of 20 on a moving boat. Counting rows also stops
/// the prompt dialog's own «remember my choice» checkbox from being counted as
/// an item, which is what the old finder did.
int checklistRows(WidgetTester tester) =>
    find.byType(NavisRow).evaluate().length;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeRoute());
  });

  const tripId = 'r1';
  const groupId = 'g1';

  late _MockRegattaRepository mockRepo;

  setUp(() {
    mockRepo = _MockRegattaRepository();
  });

  /// Overrides the settings store with a prefs instance holding [mode] as the
  /// remembered pre-trip checklist choice (null = nothing remembered yet).
  Future<Override> checklistMode(String? mode) async {
    SharedPreferences.setMockInitialValues(
      mode == null ? {} : {'settings_pretrip_checklist': mode},
    );
    final prefs = await SharedPreferences.getInstance();
    return sharedPreferencesProvider.overrideWithValue(prefs);
  }

  ChecklistItem makeItem({
    String id = 'c1',
    String label = 'Lifejackets',
    bool isChecked = false,
    int position = 0,
  }) {
    return ChecklistItem(
      id: id,
      label: label,
      isChecked: isChecked,
      position: position,
    );
  }

  group('PreTripChecklistScreen local mode', () {
    /// Boat mode with the checklist set to always open, which is what the old
    /// mandatory behaviour looked like.
    Future<Widget> buildLocal({
      RouteSpy? spy,
      String? departurePort,
      String? mode = 'review',
    }) async {
      return buildRoutedTestApp(
        PreTripChecklistScreen(boatId: 'b1', departurePort: departurePort),
        spy: spy,
        overrides: [
          regattaRepositoryProvider.overrideWithValue(mockRepo),
          await checklistMode(mode),
        ],
      );
    }

    testWidgets('shows the 10 default safety items', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await buildLocal());
      await pumpScreen(tester);

      expect(checklistRows(tester), 10);
      expect(
        find.text('Lifejackets for the whole crew'),
        findsOneWidget,
      );
    });

    testWidgets('adds a custom item through the dialog', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await buildLocal());
      await pumpScreen(tester);

      await tester.tap(find.byIcon(Icons.add));
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Extra water');
      await tester.tap(find.text('Add'));
      await pumpScreen(tester);

      expect(checklistRows(tester), 11);
      expect(find.text('Extra water'), findsOneWidget);
    });

    testWidgets('removes an item locally', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await buildLocal());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Delete').first);
      await pumpScreen(tester);

      expect(checklistRows(tester), 9);
      expect(
        find.text('Lifejackets for the whole crew'),
        findsNothing,
      );
    });

    testWidgets('Start Trip opens recording with autostart', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Start trip'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/b1/record?autostart=true');
    });

    testWidgets('Start Trip forwards a pre-selected departure port',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        await buildLocal(spy: spy, departurePort: 'Port Nou'),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Start trip'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/b1/record?autostart=true&port=Port%20Nou');
    });
  });

  group('PreTripChecklistScreen optional checklist prompt', () {
    Future<Widget> buildLocal({
      RouteSpy? spy,
      String? mode,
      SharedPreferences? prefs,
    }) async {
      return buildRoutedTestApp(
        const PreTripChecklistScreen(boatId: 'b1'),
        spy: spy,
        overrides: [
          regattaRepositoryProvider.overrideWithValue(mockRepo),
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs)
          else
            await checklistMode(mode),
        ],
      );
    }

    testWidgets('with nothing remembered it asks instead of forcing it',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy));
      await pumpScreen(tester);

      expect(find.text('Review checklist'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      // Nothing decided yet: no checklist, no trip.
      expect(find.text('Lifejackets for the whole crew'), findsNothing);
      expect(spy.locations, isEmpty);
    });

    testWidgets('Review checklist opens the checklist', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Review checklist'));
      await pumpScreen(tester);

      expect(checklistRows(tester), 10);
      expect(spy.locations, isEmpty);
    });

    testWidgets('Skip starts recording without the checklist', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Skip'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/b1/record?autostart=true');
      expect(checklistRows(tester), 0);
    });

    testWidgets('remembering Skip persists the choice', (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(await buildLocal(prefs: prefs));
      await pumpScreen(tester);

      await tester.tap(find.text('Remember my choice'));
      await pumpScreen(tester);
      await tester.tap(find.text('Skip'));
      await pumpScreen(tester);

      expect(prefs.getString('settings_pretrip_checklist'), 'skip');
    });

    testWidgets('not remembering leaves the question for the next trip',
        (tester) async {
      setPhoneSize(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(await buildLocal(prefs: prefs));
      await pumpScreen(tester);

      await tester.tap(find.text('Skip'));
      await pumpScreen(tester);

      expect(prefs.getString('settings_pretrip_checklist'), isNull);
    });

    testWidgets('a remembered Skip does not ask again and starts the trip',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy, mode: 'skip'));
      await pumpScreen(tester);

      expect(find.text('Review checklist'), findsNothing);
      expect(checklistRows(tester), 0);
      expect(spy.last, '/boats/b1/record?autostart=true');
    });

    testWidgets('a remembered Review opens the checklist without asking',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await buildLocal(spy: spy, mode: 'review'));
      await pumpScreen(tester);

      expect(find.text('Review checklist'), findsNothing);
      expect(checklistRows(tester), 10);
      expect(spy.locations, isEmpty);
    });
  });

  group('PreTripChecklistScreen regatta mode', () {
    Widget buildRegatta({
      RouteSpy? spy,
      List<ChecklistItem> items = const [],
      Future<List<ChecklistItem>> Function()? fetchItems,
    }) {
      return buildRoutedTestApp(
        const PreTripChecklistScreen(tripId: tripId, groupId: groupId),
        spy: spy,
        overrides: [
          regattaRepositoryProvider.overrideWithValue(mockRepo),
          regattaChecklistProvider.overrideWith(
            (ref, id) =>
                fetchItems != null ? fetchItems() : Future.value(items),
          ),
          regattaProvider.overrideWith(
            (ref, id) async => makeRegatta(id: tripId),
          ),
        ],
      );
    }

    testWidgets('loading shows the loading indicator', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<ChecklistItem>>();
      await tester.pumpWidget(
        buildRegatta(fetchItems: () => completer.future),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavisLoading), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows the error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildRegatta(fetchItems: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
    });

    testWidgets('toggle persists the item to the trip', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.setChecklistItem(tripId, 'c1', true))
          .thenAnswer((_) async {});
      await tester.pumpWidget(buildRegatta(items: [makeItem()]));
      await pumpScreen(tester);

      await tester.tap(find.byType(NavisRow));
      await pumpScreen(tester);

      verify(() => mockRepo.setChecklistItem(tripId, 'c1', true)).called(1);
      expect(
        tester.widget<NavisRow>(find.byType(NavisRow)).done,
        isTrue,
      );
    });

    testWidgets('toggle failure reverts optimistically and shows a snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.setChecklistItem(tripId, 'c1', true))
          .thenThrow(Exception('boom'));
      await tester.pumpWidget(buildRegatta(items: [makeItem()]));
      await pumpScreen(tester);

      await tester.tap(find.byType(NavisRow));
      await pumpScreen(tester);

      expect(
        tester.widget<NavisRow>(find.byType(NavisRow)).done,
        isFalse,
      );
      expectSnackbar(tester, 'Could not update');
    });

    testWidgets('unchecked items show Set sail anyway with the safety hint',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildRegatta(items: [makeItem(), makeItem(id: 'c2', position: 1)]),
      );
      await pumpScreen(tester);

      expect(find.text('Set sail anyway'), findsOneWidget);
      expect(find.text('Complete and set sail'), findsNothing);
    });

    testWidgets('all-checked items show Complete and set sail', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildRegatta(items: [makeItem(isChecked: true)]),
      );
      await pumpScreen(tester);

      expect(find.text('Complete and set sail'), findsOneWidget);
      expect(find.text('Set sail anyway'), findsNothing);
    });

    testWidgets('completing starts the regatta and opens recording',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.completeChecklist(tripId)).thenAnswer((_) async {});
      when(() => mockRepo.start(tripId)).thenAnswer(
        (_) async => makeRegatta(id: tripId, status: 'recording'),
      );
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRegatta(spy: spy, items: [makeItem(isChecked: true)]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Complete and set sail'));
      await pumpScreen(tester);

      verify(() => mockRepo.completeChecklist(tripId)).called(1);
      verify(() => mockRepo.start(tripId)).called(1);
      expect(
        spy.last,
        '/boats/boat-1/record?tripId=$tripId&regatta=true',
      );
    });

    testWidgets('start failure shows a snackbar and stays', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.completeChecklist(tripId))
          .thenThrow(Exception('boom'));
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRegatta(spy: spy, items: [makeItem(isChecked: true)]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Complete and set sail'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not start');
      expect(spy.locations, isEmpty);
    });
  });
}
