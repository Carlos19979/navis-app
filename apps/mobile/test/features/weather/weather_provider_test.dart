import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/weather/data/repositories/weather_repository.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import '../../helpers/geo.dart';
import '../../helpers/lifecycle.dart';
import '../../helpers/test_helpers.dart';

class MockWeatherRepository extends Mock implements WeatherRepository {}

void main() {
  late FakeLifecycle lifecycle;
  late MockWeatherRepository repository;

  setUp(() {
    lifecycle = FakeLifecycle();
    addTearDown(lifecycle.dispose);
    repository = MockWeatherRepository();
    when(() => repository.getOverview(any(), any()))
        .thenAnswer((_) async => makeOverview());
  });

  ProviderContainer makeContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(
      overrides: [
        ...lifecycle.overrides,
        weatherRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final fixedPosition = positionProvider.overrideWith(
    (ref) async => makePosition(lat: 39.5, lon: 2.6),
  );

  group('weatherOverviewProvider', () {
    test('refetches the forecast when the app comes back to the foreground',
        () async {
      // The build-4 complaint: the forecast stayed at whatever it was when the
      // tab was first opened, until the user pulled to refresh by hand.
      final container = makeContainer(overrides: [fixedPosition]);
      container.listen(weatherOverviewProvider, (_, __) {});
      await container.read(weatherOverviewProvider.future);
      verify(() => repository.getOverview(39.5, 2.6)).called(1);

      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(weatherOverviewProvider.future);

      verify(() => repository.getOverview(39.5, 2.6)).called(1);
    });

    test('does not refetch when the app was only away for seconds', () async {
      final container = makeContainer(overrides: [fixedPosition]);
      container.listen(weatherOverviewProvider, (_, __) {});
      await container.read(weatherOverviewProvider.future);
      verify(() => repository.getOverview(39.5, 2.6)).called(1);

      lifecycle.leaveAndReturn(away: const Duration(seconds: 3));
      await lifecycle.settle(container);

      verifyNever(() => repository.getOverview(any(), any()));
    });

    test('an inactive blip does not refetch the forecast', () async {
      final container = makeContainer(overrides: [fixedPosition]);
      container.listen(weatherOverviewProvider, (_, __) {});
      await container.read(weatherOverviewProvider.future);
      verify(() => repository.getOverview(39.5, 2.6)).called(1);

      lifecycle.blip();
      await lifecycle.settle(container);

      verifyNever(() => repository.getOverview(any(), any()));
    });

    test('returns null without a fix, and asks for no forecast', () async {
      final container = makeContainer(overrides: [
        positionProvider.overrideWith((ref) async => null),
      ]);

      expect(await container.read(weatherOverviewProvider.future), isNull);
      verifyNever(() => repository.getOverview(any(), any()));
    });

    test('reads the forecast for the current fix', () async {
      final container = makeContainer(overrides: [fixedPosition]);

      final overview = await container.read(weatherOverviewProvider.future);

      expect(overview?.current.temperature, 24.0);
      verify(() => repository.getOverview(39.5, 2.6)).called(1);
    });
  });

  group('positionProvider', () {
    test('re-acquires the fix when the app comes back', () async {
      // Everything on the weather screen hangs off the fix, and the boat has
      // usually moved while the phone was in a pocket.
      installFakeGeo(initialPosition: makePosition(lat: 39.5, lon: 2.6));
      final container = makeContainer();
      container.listen(positionProvider, (_, __) {});
      expect((await container.read(positionProvider.future))?.latitude, 39.5);

      installFakeGeo(initialPosition: makePosition(lat: 41.3, lon: 2.1));
      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);

      expect((await container.read(positionProvider.future))?.latitude, 41.3);
    });

    test('a short trip out does not spend a GPS fix', () async {
      installFakeGeo(initialPosition: makePosition(lat: 39.5, lon: 2.6));
      final container = makeContainer();
      container.listen(positionProvider, (_, __) {});
      await container.read(positionProvider.future);

      installFakeGeo(initialPosition: makePosition(lat: 41.3, lon: 2.1));
      lifecycle.leaveAndReturn(away: const Duration(seconds: 20));
      await lifecycle.settle(container);

      expect((await container.read(positionProvider.future))?.latitude, 39.5);
    });

    test('a denied permission yields no fix', () async {
      installFakeGeo(
        checkResult: LocationPermission.denied,
        requestResult: LocationPermission.denied,
      );
      final container = makeContainer();

      expect(await container.read(positionProvider.future), isNull);
    });

    test('location services turned off yield no fix', () async {
      installFakeGeo(serviceEnabled: false);
      final container = makeContainer();

      expect(await container.read(positionProvider.future), isNull);
    });
  });

  group('hourlyForDayProvider', () {
    test('follows the fix, so an expanded day reloads with the new position',
        () async {
      final day = DateTime(2026, 7, 26);
      when(() => repository.getHourly(any(), any(), day))
          .thenAnswer((_) async => []);
      installFakeGeo(initialPosition: makePosition(lat: 39.5, lon: 2.6));
      final container = makeContainer();
      container.listen(hourlyForDayProvider(day), (_, __) {});
      await container.read(hourlyForDayProvider(day).future);

      installFakeGeo(initialPosition: makePosition(lat: 41.3, lon: 2.1));
      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await container.read(hourlyForDayProvider(day).future);

      verify(() => repository.getHourly(41.3, 2.1, day)).called(1);
    });
  });
}
