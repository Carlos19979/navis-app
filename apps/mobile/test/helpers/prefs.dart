import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/settings_service.dart';

/// An in-memory [SharedPreferences] for the widget under test.
///
/// `sharedPreferencesProvider` throws unless it is overridden, so anything that
/// reads a persisted setting — the theme, the locale, the active boat — needs
/// this. It used to be done inline with a `FutureBuilder` around the whole
/// ProviderScope; this is the same thing without the wrapper.
///
/// ```dart
/// final prefs = await prefsOverride({'active_boat_id': 'boat-2'});
/// await tester.pumpWidget(buildTestApp(subject, overrides: [prefs]));
/// ```
Future<Override> prefsOverride([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return sharedPreferencesProvider.overrideWithValue(prefs);
}
