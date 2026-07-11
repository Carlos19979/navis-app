import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';

class MockTripRepository extends Mock implements TripRepository {}

class FakeTrip extends Fake implements Trip {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late MockTripRepository tripRepo;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(FakeTrip());
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, 'navis_cache.db'));

    db = LocalDatabase();
    tripRepo = MockTripRepository();
    container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(db),
      tripRepositoryProvider.overrideWithValue(tripRepo),
      // Bypasses the connectivity listener (platform channel) of the real
      // provider body; enqueue/getPendingMutations work against the ffi DB.
      mutationQueueProvider.overrideWith(
        (ref) => MutationQueueNotifier(db: db, ref: ref),
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Seeds a crash-interrupted PAUSED session (paused avoids touching the
  /// geolocator platform channel on recovery) with three fixes forming a
  /// straight line.
  Future<void> seedSession({String? tripId}) async {
    await db.startRecordingSession(
      boatId: 'boat-1',
      tripId: tripId,
      isRegatta: false,
      departurePort: 'Palma',
      startedAt: DateTime(2026, 7, 11, 10),
    );
    await db.updateRecordingSession({'status': 'paused'});
    for (final (i, speed) in [(0, 4.0), (1, 6.0), (2, 5.0)].indexed) {
      await db.insertRecordingPoint(
        lat: 39.5 + 0.01 * i,
        lon: 2.6,
        timestamp: DateTime(2026, 7, 11, 10, i),
        speedKnots: speed.$2,
      );
    }
  }

  group('TripRecordingNotifier session recovery', () {
    test('hasPersistedSession is false with a clean database', () async {
      final notifier = container.read(tripRecordingProvider.notifier);
      expect(await notifier.hasPersistedSession(), isFalse);
    });

    test('recoverSession restores points, stats and trip', () async {
      await seedSession(tripId: 'trip-9');
      final notifier = container.read(tripRecordingProvider.notifier);

      expect(await notifier.hasPersistedSession(), isTrue);
      expect(await notifier.recoverSession(), isTrue);

      final state = container.read(tripRecordingProvider);
      expect(state.status, RecordingStatus.paused);
      expect(state.trackPoints, hasLength(3));
      expect(state.boatId, 'boat-1');
      expect(state.trip?.id, 'trip-9');
      expect(state.maxSpeedKnots, 6.0);
      // Two ~0.6nm legs along a meridian.
      expect(state.totalDistanceNm, closeTo(1.2, 0.1));
      expect(state.startTime, DateTime(2026, 7, 11, 10));
    });

    test('recoverSession returns false with no session', () async {
      final notifier = container.read(tripRecordingProvider.notifier);
      expect(await notifier.recoverSession(), isFalse);
      expect(
          container.read(tripRecordingProvider).status, RecordingStatus.idle);
    });
  });

  group('TripRecordingNotifier upload', () {
    test('uploadPending posts pending points and marks them handed off',
        () async {
      await seedSession(tripId: 'trip-9');
      when(() => tripRepo.addTrackPoints(any(), any()))
          .thenAnswer((_) async {});

      final notifier = container.read(tripRecordingProvider.notifier);
      await notifier.recoverSession();
      await notifier.uploadPending();

      final captured =
          verify(() => tripRepo.addTrackPoints('trip-9', captureAny()))
              .captured;
      expect((captured.single as List).length, 3);
      expect(await db.getPendingRecordingPoints(), isEmpty);

      // Second call: nothing left to upload.
      await notifier.uploadPending();
      verifyNever(() => tripRepo.addTrackPoints('trip-9', any()));
    });

    test('uploadPending falls back to the mutation queue on failure', () async {
      await seedSession(tripId: 'trip-9');
      when(() => tripRepo.addTrackPoints(any(), any()))
          .thenThrow(Exception('offline'));

      final notifier = container.read(tripRecordingProvider.notifier);
      await notifier.recoverSession();
      await notifier.uploadPending();

      // Handed off exactly once: points marked, batch parked in the queue.
      expect(await db.getPendingRecordingPoints(), isEmpty);
      final mutations = await db.getPendingMutations();
      expect(mutations, hasLength(1));
      expect(mutations.single['method'], 'POST');
      expect(mutations.single['path'], '/api/v1/trips/trip-9/tracks');
    });
  });

  group('TripRecordingNotifier discard and complete', () {
    test('discard deletes the solo trip and clears everything', () async {
      await seedSession(tripId: 'trip-9');
      when(() => tripRepo.deleteTrip(any())).thenAnswer((_) async {});

      final notifier = container.read(tripRecordingProvider.notifier);
      await notifier.recoverSession();
      await notifier.discard();

      verify(() => tripRepo.deleteTrip('trip-9')).called(1);
      expect(
          container.read(tripRecordingProvider).status, RecordingStatus.idle);
      expect(await notifier.hasPersistedSession(), isFalse);
      expect(await db.getRecordingPoints(), isEmpty);
    });

    test('complete uploads, completes on the server and clears the session',
        () async {
      await seedSession(tripId: 'trip-9');
      when(() => tripRepo.addTrackPoints(any(), any()))
          .thenAnswer((_) async {});
      when(() => tripRepo.completeTrip(
            any(),
            arrivalPort: any(named: 'arrivalPort'),
            distanceNm: any(named: 'distanceNm'),
            engineHours: any(named: 'engineHours'),
            fuelConsumedL: any(named: 'fuelConsumedL'),
          )).thenAnswer((invocation) async => Trip(
            id: 'trip-9',
            boatId: 'boat-1',
            departurePort: 'Palma',
            departureTime: DateTime(2026, 7, 11, 10),
          ));

      final notifier = container.read(tripRecordingProvider.notifier);
      await notifier.recoverSession();
      await notifier.complete(const TripCompletionData(arrivalPort: 'Andratx'));

      verify(() => tripRepo.completeTrip(
            'trip-9',
            arrivalPort: 'Andratx',
            distanceNm: any(named: 'distanceNm'),
            engineHours: any(named: 'engineHours'),
            fuelConsumedL: any(named: 'fuelConsumedL'),
          )).called(1);
      expect(
          container.read(tripRecordingProvider).status, RecordingStatus.idle);
      expect(await notifier.hasPersistedSession(), isFalse);
    });

    test('complete parks the completion in the queue when offline', () async {
      await seedSession(tripId: 'trip-9');
      when(() => tripRepo.addTrackPoints(any(), any()))
          .thenThrow(Exception('offline'));
      when(() => tripRepo.completeTrip(
            any(),
            arrivalPort: any(named: 'arrivalPort'),
            distanceNm: any(named: 'distanceNm'),
            engineHours: any(named: 'engineHours'),
            fuelConsumedL: any(named: 'fuelConsumedL'),
          )).thenThrow(Exception('offline'));

      final notifier = container.read(tripRecordingProvider.notifier);
      await notifier.recoverSession();
      await notifier.complete(const TripCompletionData(arrivalPort: 'Andratx'));

      final mutations = await db.getPendingMutations();
      final paths = mutations.map((m) => m['path']).toList();
      expect(paths, contains('/api/v1/trips/trip-9/tracks'));
      expect(paths, contains('/api/v1/trips/trip-9/complete'));
      expect(
          container.read(tripRecordingProvider).status, RecordingStatus.idle);
    });
  });
}
