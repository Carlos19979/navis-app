import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/boat/data/repositories/boat_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';

final boatRepositoryProvider = Provider<BoatRepository>((ref) {
  return BoatRepositoryImpl();
});

final boatsProvider =
    AsyncNotifierProvider<BoatsNotifier, List<Boat>>(BoatsNotifier.new);

class BoatsNotifier extends AsyncNotifier<List<Boat>> {
  String? _nextCursor;
  bool _hasMore = true;

  @override
  Future<List<Boat>> build() async {
    final repository = ref.watch(boatRepositoryProvider);
    final response = await repository.getBoats();
    _nextCursor = response.nextCursor;
    _hasMore = response.nextCursor != null;
    return response.items;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final repository = ref.read(boatRepositoryProvider);
    final currentBoats = state.valueOrNull ?? [];
    final response = await repository.getBoats(cursor: _nextCursor);
    _nextCursor = response.nextCursor;
    _hasMore = response.nextCursor != null;
    state = AsyncData([...currentBoats, ...response.items]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> createBoat(Boat boat) async {
    final repository = ref.read(boatRepositoryProvider);
    final created = await repository.createBoat(boat);
    final currentBoats = state.valueOrNull ?? [];
    state = AsyncData([created, ...currentBoats]);
  }

  Future<void> updateBoat(Boat boat) async {
    final repository = ref.read(boatRepositoryProvider);
    final updated = await repository.updateBoat(boat);
    final currentBoats = state.valueOrNull ?? [];
    state = AsyncData(
      currentBoats.map((b) => b.id == updated.id ? updated : b).toList(),
    );
  }

  Future<void> deleteBoat(String id) async {
    final repository = ref.read(boatRepositoryProvider);
    await repository.deleteBoat(id);
    final currentBoats = state.valueOrNull ?? [];
    state = AsyncData(currentBoats.where((b) => b.id != id).toList());
  }
}

final boatProvider =
    FutureProvider.family<Boat, String>((ref, id) async {
  final repository = ref.watch(boatRepositoryProvider);
  return repository.getBoat(id);
});
