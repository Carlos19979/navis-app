import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/error/exceptions.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
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

  Future<void> pumpRecordingScreen(
    WidgetTester tester, {
    BoatPermissions permissions = const BoatPermissions.all(),
  }) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    installFakeGeo();
    await tester.pumpWidget(
      buildRoutedTestApp(
        const TripRecordingScreen(boatId: 'boat-1'),
        overrides: [
          tripRecordingProvider.overrideWith((ref) => notifier),
          overridePorts(),
          overrideConnectivity(),
          nearbyPortsProvider.overrideWith((ref, params) async => []),
          boatPermissionsProvider.overrideWith((ref, id) async => permissions),
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

      await tester.tap(find.text('Save trip'));
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

      await tester.tap(find.text('Save trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Failed to save trip'), findsOneWidget);
      expect(find.byType(TripRecordingScreen), findsOneWidget);

      await drain(tester);
    });

    testWidgets(
        'a 403 on save says the owner has not granted the permission, '
        'not DioException', (tester) async {
      notifier = _FakeTripRecordingNotifier(recordingState());
      when(() => notifier.complete(any())).thenAnswer(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/trips'),
          error: const ServerException(message: 'FORBIDDEN', statusCode: 403),
        ),
      );

      await pumpRecordingScreen(tester);
      await openStopDialog(tester);

      await tester.tap(find.text('Save trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('You cannot record trips on this boat.'),
        findsOneWidget,
      );
      expect(find.textContaining('Failed to save trip'), findsNothing);
      expect(find.textContaining('DioException'), findsNothing);

      await drain(tester);
    });
  });

  group('TripRecordingScreen can_record_trips gate', () {
    testWidgets(
        'without the permission the start control is replaced by the '
        'blocked card', (tester) async {
      notifier = _FakeTripRecordingNotifier(TripRecordingState.initial);

      await pumpRecordingScreen(
        tester,
        permissions: const BoatPermissions.none(),
      );

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byType(BlockedActionCard), findsOneWidget);
      expect(
          find.text('You cannot record trips on this boat.'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('a recording already in progress keeps its controls',
        (tester) async {
      // The permission was checked when it started; a slow or failed lookup
      // must not strip the controls from an active recording.
      notifier = _FakeTripRecordingNotifier(recordingState());

      await pumpRecordingScreen(
        tester,
        permissions: const BoatPermissions.none(),
      );

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(BlockedActionCard), findsNothing);

      await drain(tester);
    });

    testWidgets('start is not attempted without the permission',
        (tester) async {
      notifier = _FakeTripRecordingNotifier(TripRecordingState.initial);
      stubStart(RecordingStartResult.started);

      // autoStart would normally begin recording on the first frame.
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const TripRecordingScreen(boatId: 'boat-1', autoStart: true),
          overrides: [
            tripRecordingProvider.overrideWith((ref) => notifier),
            overridePorts(),
            overrideConnectivity(),
            nearbyPortsProvider.overrideWith((ref, params) async => []),
            boatPermissionsProvider.overrideWith(
              (ref, id) async => const BoatPermissions.none(),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      // Not a single GPS fix taken, and the user is told why.
      verifyNever(
        () => notifier.start(
          boatId: any(named: 'boatId'),
          tripId: any(named: 'tripId'),
          isRegatta: any(named: 'isRegatta'),
          departurePort: any(named: 'departurePort'),
        ),
      );
      expect(
        find.textContaining('You cannot record trips on this boat.'),
        findsWidgets,
      );

      await drain(tester);
    });
  });
}
