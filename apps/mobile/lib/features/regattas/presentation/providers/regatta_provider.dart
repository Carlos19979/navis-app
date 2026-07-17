import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';

import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';

final regattaRepositoryProvider = Provider<RegattaRepository>((ref) {
  return RegattaRepository();
});

final groupRegattasProvider =
    FutureProvider.family<List<Regatta>, String>((ref, groupId) async {
  final repo = ref.watch(regattaRepositoryProvider);
  return repo.getGroupRegattas(groupId);
});

final regattaProvider = FutureProvider.family<Regatta, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repo = ref.watch(regattaRepositoryProvider);
  return repo.getRegatta(id);
});

final regattaChecklistProvider =
    FutureProvider.family<List<ChecklistItem>, String>((ref, tripId) async {
  final repo = ref.watch(regattaRepositoryProvider);
  return repo.getChecklist(tripId);
});

final regattaParticipantsProvider =
    FutureProvider.family<List<RegattaParticipant>, String>(
        (ref, tripId) async {
  final repo = ref.watch(regattaRepositoryProvider);
  return repo.getParticipants(tripId);
});
