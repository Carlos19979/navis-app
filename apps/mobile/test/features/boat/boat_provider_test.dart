import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class MockBoatRepository extends Mock implements BoatRepository {}

void main() {
  late MockBoatRepository mockRepository;
  late ProviderContainer container;

  final testBoats = [
    const Boat(
      id: '1',
      name: 'Sea Breeze',
      registration: 'SB-001',
      type: 'sailboat',
      lengthMeters: 12.5,
      homePort: 'Valencia',
    ),
    const Boat(
      id: '2',
      name: 'Blue Horizon',
      registration: 'BH-002',
      type: 'motorboat',
      lengthMeters: 8.0,
      homePort: 'Barcelona',
    ),
  ];

  setUp(() {
    mockRepository = MockBoatRepository();
    container = ProviderContainer(
      overrides: [
        boatRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('boatsProvider', () {
    test('returns list of boats on success', () async {
      when(() => mockRepository.getBoats(
              cursor: any(named: 'cursor'), limit: any(named: 'limit')))
          .thenAnswer((_) async => PaginatedResponse<Boat>(
                items: testBoats,
              ));

      final result = await container.read(boatsProvider.future);

      expect(result, hasLength(2));
      expect(result.first.name, 'Sea Breeze');
      expect(result.last.name, 'Blue Horizon');
      verify(() => mockRepository.getBoats()).called(1);
    });

    test('returns single boat by id', () async {
      when(() => mockRepository.getBoat('1'))
          .thenAnswer((_) async => testBoats.first);

      final result = await container.read(boatProvider('1').future);

      expect(result.name, 'Sea Breeze');
      expect(result.registration, 'SB-001');
      verify(() => mockRepository.getBoat('1')).called(1);
    });
  });
}
