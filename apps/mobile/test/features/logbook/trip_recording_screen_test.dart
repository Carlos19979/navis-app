import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_recording_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

import '../../helpers/helpers.dart';

/// The screen only renders state and forwards intents, so tests fake the
/// NOTIFIER (seeded state + mocktail stubs/verification), not the GPS stream.
/// FakeGeo is still installed because initState asks the platform for the
/// last known position to center the map.
class _FakeTripRecordingNotifier extends StateNotifier<TripRecordingState>
    with Mock
    implements TripRecordingNotifier {
  _FakeTripRecordingNotifier(super.state);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TripCompletionData());
  });

  late _FakeTripRecordingNotifier notifier;

  TripRecordingState recordingState({
    RecordingStatus status = RecordingStatus.recording,
  }) {
    // Values kept short: the completion dialog's summary pills row is not
    // scrollable and the wide test font overflows it with longer numbers.
    return TripRecordingState(
      status: status,
      startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      totalDistanceNm: 2.5,
      currentSpeedKnots: 6.2,
      currentHeading: 45,
      gpsAccuracy: 5,
      currentPosition: const LatLng(39.57, 2.63),
      trackPoints: [
        TrackPoint(
          latitude: 39.56,
          longitude: 2.62,
          timestamp: DateTime(2026, 4, 26, 10),
          speedKnots: 5,
        ),
        TrackPoint(
          latitude: 39.57,
          longitude: 2.63,
          timestamp: DateTime(2026, 4, 26, 10, 15),
          speedKnots: 6,
        ),
      ],
      boatId: 'boat-1',
    );
  }

  Future<void> pumpRecordingScreen(WidgetTester tester) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    installFakeGeo();
    await tester.pumpWidget(
      buildRoutedTestApp(
        const TripRecordingScreen(boatId: 'boat-1'),
        overrides: [
          tripRecordingProvider.overrideWith((ref) => notifier),
          allPortsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await pumpScreen(tester);
  }

  void stubStart(RecordingStartResult result) {
    when(
      () => notifier.start(
        boatId: any(named: 'boatId'),
        tripId: any(named: 'tripId'),
        isRegatta: any(named: 'isRegatta'),
        departurePort: any(named: 'departurePort'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Taps the stop control and pumps the completion dialog open.
  Future<void> openStopDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('TripRecordingScreen controls per status', () {
    testWidgets('idle state shows the start button and no HUD', (tester) async {
      notifier = _FakeTripRecordingNotifier(TripRecordingState.initial);

      await pumpRecordingScreen(tester);

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('SPD'), findsNothing);
      expect(find.byIcon(Icons.stop), findsNothing);

      await drain(tester);
    });

    testWidgets('recording state shows the HUD and pause/stop controls',
        (tester) async {
      notifier = _FakeTripRecordingNotifier(recordingState());

      await pumpRecordingScreen(tester);

      expect(find.text('SPD'), findsOneWidget);
      expect(find.text('DIST'), findsOneWidget);
      // HUD values are RichText (value + unit spans).
      expect(find.text('6.2 kn', findRichText: true), findsOneWidget);
      expect(find.text('2.50 nm', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await drain(tester);
    });

    testWidgets('paused state shows the resume control', (tester) async {
      notifier = _FakeTripRecordingNotifier(
        recordingState(status: RecordingStatus.paused),
      );

      await pumpRecordingScreen(tester);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await drain(tester);
    });
  });

  group('TripRecordingScreen start permission snackbars', () {
    testWidgets('permission denied shows the required-permission snackbar',
        (tester) async {
      notifier = _FakeTripRecordingNotifier(TripRecordingState.initial);
      stubStart(RecordingStartResult.permissionDenied);

      await pumpRecordingScreen(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expectSnackbar(
        tester,
        'Location permission is required to record trips',
      );

      await drain(tester);
    });

    testWidgets('denied forever shows the enable-in-settings snackbar',
        (tester) async {
      notifier = _FakeTripRecordingNotifier(TripRecordingState.initial);
      stubStart(RecordingStartResult.permissionDeniedForever);

      await pumpRecordingScreen(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expectSnackbar(
        tester,
        'Location permission permanently denied. Enable in settings.',
      );

      await drain(tester);
    });
  });

  group('TripRecordingScreen stop flow', () {
    testWidgets(
        'stop opens the completion dialog with distance and duration; '
        'cancelling resumes the recording', (tester) async {
      notifier = _FakeTripRecordingNotifier(recordingState());

      await pumpRecordingScreen(tester);
      await openStopDialog(tester);

      expect(find.byType(TripCompletionDialog), findsOneWidget);
      expect(find.text('2.5 NM'), findsOneWidget);
      expect(find.text('0h 30m'), findsOneWidget);
      verify(() => notifier.pause()).called(1);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TripCompletionDialog), findsNothing);
      verify(() => notifier.resume()).called(1);

      await drain(tester);
    });

    testWidgets(
        'saving the completion dialog completes the trip and '
        'shows the saved snackbar', (tester) async {
      notifier = _FakeTripRecordingNotifier(recordingState());
      when(() => notifier.complete(any())).thenAnswer((_) async {});

      await pumpRecordingScreen(tester);
      await openStopDialog(tester);

      await tester.tap(find.text('Save Trip'));
      await tester.pump();
      // Let the pop route transition finish: while it runs both the map and
      // the host Scaffold show the snackbar, afterwards only the host does.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => notifier.complete(any())).called(1);
      expectSnackbar(tester, 'Trip saved!');

      await drain(tester);
    });

    testWidgets(
        'a failing complete() shows the failure snackbar and '
        'keeps the screen', (tester) async {
      notifier = _FakeTripRecordingNotifier(recordingState());
      when(() => notifier.complete(any()))
          .thenAnswer((_) async => throw Exception('boom'));

      await pumpRecordingScreen(tester);
      await openStopDialog(tester);

      await tester.tap(find.text('Save Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Failed to save trip'), findsOneWidget);
      expect(find.byType(TripRecordingScreen), findsOneWidget);

      await drain(tester);
    });
  });
}
