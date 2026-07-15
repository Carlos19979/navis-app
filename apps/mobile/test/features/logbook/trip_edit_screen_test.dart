// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_edit_screen.dart';

import '../../helpers/helpers.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
    registerFallbackValue(makeTrip());
  });

  const tripId = 'trip-1';

  late _MockTripRepository mockRepo;

  setUp(() {
    mockRepo = _MockTripRepository();
  });

  Trip makeEditableTrip() => makeTrip().copyWith(
        engineHours: 12.5,
        fuelConsumedL: 30.0,
      );

  Widget buildSubject({Trip? trip, RouteSpy? spy}) {
    return buildRoutedTestApp(
      const TripEditScreen(tripId: tripId),
      spy: spy,
      overrides: [
        tripProvider.overrideWith(
          (ref, id) async => trip ?? makeEditableTrip(),
        ),
        tripRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  group('TripEditScreen', () {
    testWidgets('prefills fields from the trip', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Edit trip'), findsOneWidget);
      expect(find.text('Palma de Mallorca'), findsOneWidget);
      expect(find.text('Port de Soller'), findsOneWidget);
      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('30.0'), findsOneWidget);
      expect(find.text('Great trip'), findsOneWidget);
      expect(find.text('Update Trip'), findsOneWidget);
    });

    testWidgets('empty departure port shows validation error', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Palma de Mallorca'),
        '',
      );
      await tester.ensureVisible(find.text('Update Trip'));
      await tester.tap(find.text('Update Trip'));
      await pumpScreen(tester);

      expect(find.text('Please enter the departure port'), findsOneWidget);
      verifyNever(() => mockRepo.updateTrip(any()));
    });

    testWidgets('non-numeric engine hours shows validation error',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '12.5'),
        'abc',
      );
      await tester.ensureVisible(find.text('Update Trip'));
      await tester.tap(find.text('Update Trip'));
      await pumpScreen(tester);

      expect(find.text('Please enter a valid number'), findsOneWidget);
      verifyNever(() => mockRepo.updateTrip(any()));
    });

    testWidgets('non-numeric fuel shows validation error', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '30.0'),
        'lots',
      );
      await tester.ensureVisible(find.text('Update Trip'));
      await tester.tap(find.text('Update Trip'));
      await pumpScreen(tester);

      expect(find.text('Please enter a valid number'), findsOneWidget);
      verifyNever(() => mockRepo.updateTrip(any()));
    });

    testWidgets('save success calls updateTrip, shows snackbar and pops',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.updateTrip(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments.first as Trip);

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Palma de Mallorca'),
        'Andratx',
      );
      await tester.ensureVisible(find.text('Update Trip'));
      await tester.tap(find.text('Update Trip'));
      await pumpScreen(tester);

      final saved = verify(() => mockRepo.updateTrip(captureAny()))
          .captured
          .single as Trip;
      expect(saved.departurePort, 'Andratx');
      expect(saved.engineHours, 12.5);
      expectSnackbar(tester, 'Trip updated');
      // context.pop() returned to the host page.
      expect(find.text('__host__'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('save failure shows error snackbar and stays on screen',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.updateTrip(any()))
          .thenThrow(Exception('server error'));

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Update Trip'));
      await tester.tap(find.text('Update Trip'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Failed to update trip');
      expect(find.byType(TripEditScreen), findsOneWidget);

      await drain(tester);
    });
  });
}
