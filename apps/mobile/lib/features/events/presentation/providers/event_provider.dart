import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/events/data/repositories/event_repository.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final response = await repository.getEvents();
  return response.items;
});

final eventProvider =
    FutureProvider.family<Event, String>((ref, id) async {
  final repository = ref.watch(eventRepositoryProvider);
  return repository.getEvent(id);
});
