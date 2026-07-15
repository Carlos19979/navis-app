import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_form_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_selectable_card.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

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

  Widget buildSubject({RouteSpy? spy}) {
    return buildRoutedTestApp(
      const GroupFormScreen(),
      spy: spy,
      overrides: [groupRepositoryProvider.overrideWithValue(mockRepo)],
    );
  }

  Finder submitButton() => find.widgetWithText(NavisButton, 'Create group');

  void stubCreateGroup() {
    when(() => mockRepo.createGroup(
          name: any(named: 'name'),
          visibility: any(named: 'visibility'),
          description: any(named: 'description'),
        )).thenAnswer(
      (_) async => makeGroup(id: 'group-9', name: 'Racing Crew'),
    );
  }

  group('GroupFormScreen validation', () {
    testWidgets('submitting without a name shows the required-field error',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(submitButton());
      await pumpScreen(tester);

      expect(find.text('This field is required'), findsOneWidget);
      verifyNever(() => mockRepo.createGroup(
            name: any(named: 'name'),
            visibility: any(named: 'visibility'),
            description: any(named: 'description'),
          ));
    });
  });

  group('GroupFormScreen visibility', () {
    testWidgets('offers public and private options, public preselected',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(
        find.widgetWithText(NavisSelectableCard, 'Public'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavisSelectableCard, 'Private'),
        findsOneWidget,
      );

      final public = tester.widget<NavisSelectableCard>(
        find.widgetWithText(NavisSelectableCard, 'Public'),
      );
      expect(public.selected, isTrue);
    });

    testWidgets('selecting private submits visibility=private', (tester) async {
      setPhoneSize(tester);
      stubCreateGroup();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(NavisTextField, 'Group name'),
        'Racing Crew',
      );
      await tester.tap(find.text('Private'));
      await pumpScreen(tester);
      await tester.tap(submitButton());
      await pumpScreen(tester);

      verify(() => mockRepo.createGroup(
            name: 'Racing Crew',
            visibility: 'private',
            description: any(named: 'description'),
          )).called(1);
    });
  });

  group('GroupFormScreen submit', () {
    testWidgets(
        'success creates the group, shows a snackbar and opens the detail',
        (tester) async {
      setPhoneSize(tester);
      stubCreateGroup();
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(NavisTextField, 'Group name'),
        'Racing Crew',
      );
      await tester.enterText(
        find.widgetWithText(NavisTextField, 'Description (optional)'),
        'Wednesday league',
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      verify(() => mockRepo.createGroup(
            name: 'Racing Crew',
            visibility: 'public',
            description: 'Wednesday league',
          )).called(1);
      expectSnackbar(tester, 'Group created');
      expect(spy.last, '/groups/group-9');
    });

    testWidgets('failure shows a snackbar and re-enables the button',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createGroup(
            name: any(named: 'name'),
            visibility: any(named: 'visibility'),
            description: any(named: 'description'),
          )).thenThrow(Exception('boom'));
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(NavisTextField, 'Group name'),
        'Racing Crew',
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not create the group');
      expect(spy.locations, isEmpty);

      // The button re-enables: submitting again reaches the repository.
      await tester.tap(submitButton());
      await pumpScreen(tester);

      verify(() => mockRepo.createGroup(
            name: 'Racing Crew',
            visibility: 'public',
            description: any(named: 'description'),
          )).called(2);
    });
  });
}
