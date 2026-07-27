import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/checklist_preference.dart';
import 'package:navis_mobile/core/config/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(
      Map<String, Object> initialPrefs) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('preTripChecklistModeProvider', () {
    test('defaults to asking before each trip', () async {
      final container = await containerWith({});

      expect(
        container.read(preTripChecklistModeProvider),
        PreTripChecklistMode.ask,
      );
    });

    test('reads the stored choice', () async {
      final container =
          await containerWith({'settings_pretrip_checklist': 'skip'});

      expect(
        container.read(preTripChecklistModeProvider),
        PreTripChecklistMode.skip,
      );
    });

    test('an unknown stored value falls back to asking', () async {
      final container =
          await containerWith({'settings_pretrip_checklist': 'nonsense'});

      expect(
        container.read(preTripChecklistModeProvider),
        PreTripChecklistMode.ask,
      );
    });

    test('set persists the choice so the next trip does not ask', () async {
      final container = await containerWith({});

      container
          .read(preTripChecklistModeProvider.notifier)
          .set(PreTripChecklistMode.skip);

      expect(
        container.read(preTripChecklistModeProvider),
        PreTripChecklistMode.skip,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_pretrip_checklist'), 'skip');
    });

    test('re-enabling from settings goes back to asking', () async {
      final container =
          await containerWith({'settings_pretrip_checklist': 'skip'});

      container
          .read(preTripChecklistModeProvider.notifier)
          .set(PreTripChecklistMode.ask);

      expect(
        container.read(preTripChecklistModeProvider),
        PreTripChecklistMode.ask,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_pretrip_checklist'), 'ask');
    });
  });
}
