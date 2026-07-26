import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/config/settings_service.dart';

const _keyPreTripChecklist = 'settings_pretrip_checklist';

/// What happens when the crew starts a trip, now that the safety checklist is a
/// recommendation instead of a mandatory step.
enum PreTripChecklistMode {
  /// Ask each time (the default): "Review checklist" or "Skip".
  ask,

  /// Always open the checklist without asking.
  review,

  /// Always go straight to recording without asking.
  skip;

  static PreTripChecklistMode fromStored(String? stored) => switch (stored) {
        'review' => review,
        'skip' => skip,
        _ => ask,
      };
}

/// Persisted pre-trip checklist behaviour.
///
/// Lives in `core/config` next to the other [SharedPreferences]-backed settings
/// because three features read it: the trip flow (which asks), the checklist
/// screen (which honours it) and Settings (which resets it — the way back for
/// someone who chose "always skip" once and wants the checklist again).
final preTripChecklistModeProvider =
    NotifierProvider<PreTripChecklistModeNotifier, PreTripChecklistMode>(
  PreTripChecklistModeNotifier.new,
);

class PreTripChecklistModeNotifier extends Notifier<PreTripChecklistMode> {
  @override
  PreTripChecklistMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return PreTripChecklistMode.fromStored(
      prefs.getString(_keyPreTripChecklist),
    );
  }

  void set(PreTripChecklistMode mode) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_keyPreTripChecklist, mode.name);
    state = mode;
  }
}
