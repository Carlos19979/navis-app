import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';

const _keyActiveBoat = 'active_boat_id';

/// Which boat the app is currently about.
///
/// New concept: the home used to be a list of boats, so "the boat you are
/// working on" only existed for as long as you were inside its detail screen,
/// and every trip back out lost it. Today's screen is *about* a boat, so the
/// choice has to outlive a navigation — and a restart, because most owners have
/// one boat and should never think about this at all.
///
/// Persisted with the same pattern as the theme and the locale
/// (`settings_service.dart`): a [Notifier] over [SharedPreferences], overridden
/// at startup.
class ActiveBoatNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_keyActiveBoat);
  }

  /// Records [boatId] as the boat in context. Pass null to forget it (used when
  /// the last boat is deleted).
  void select(String? boatId) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (boatId == null) {
      prefs.remove(_keyActiveBoat);
    } else {
      prefs.setString(_keyActiveBoat, boatId);
    }
    state = boatId;
  }
}

final activeBoatIdProvider =
    NotifierProvider<ActiveBoatNotifier, String?>(ActiveBoatNotifier.new);

/// Every boat the user can act on: their own first, then the shared ones.
///
/// Shared boats are folded in on purpose — a crew member with one shared boat
/// and none of their own still has a boat to come home to.
final allBoatsProvider = Provider<List<Boat>>((ref) {
  final owned = ref.watch(boatsProvider).valueOrNull ?? const <Boat>[];
  final shared = ref.watch(sharedBoatsProvider).valueOrNull ?? const <Boat>[];
  return [...owned, ...shared];
});

/// The boat Today is about, or null when the account has none yet.
///
/// Resolution order, and each step matters:
///  1. the stored choice, **if it still exists** — a boat can be deleted, or a
///     share revoked, on another device;
///  2. otherwise the first boat, so a fresh install or a stale id still lands
///     somewhere useful rather than on an empty screen with boats in the list.
final activeBoatProvider = Provider<Boat?>((ref) {
  final boats = ref.watch(allBoatsProvider);
  if (boats.isEmpty) return null;

  final storedId = ref.watch(activeBoatIdProvider);
  if (storedId != null) {
    for (final boat in boats) {
      if (boat.id == storedId) return boat;
    }
  }
  return boats.first;
});
