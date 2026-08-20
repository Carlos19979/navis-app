import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

import '../helpers/map_noise.dart';
import '../helpers/plugins.dart';
import '../helpers/test_helpers.dart';

/// Loads every font declared in the test asset bundle (Inter + MaterialIcons +
/// CupertinoIcons) so golden renders show real glyphs instead of empty boxes.
Future<void> loadTestFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// A phone-sized viewport for goldens.
const goldenPhone = Size(390, 844);

/// Pumps [child] inside the full app chrome (theme + localization + Riverpod)
/// at a fixed size and theme, then settles. Use for screen goldens.
///
/// Screens with flutter_animate entrance/looping effects never settle; for
/// those pass `settle: false` to pump a fixed frame sequence instead, which
/// is deterministic under the fake test clock.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  Size size = goldenPhone,
  Locale locale = const Locale('es'),
  bool settle = true,
}) async {
  // Any screen with a network image reaches path_provider through
  // flutter_cache_manager, and there is no plugin under test: the boat photo
  // header threw MissingPluginException before it could render its placeholder.
  // Cosmetic, and already the exact set this filter tolerates.
  installTileNoiseFilter();
  stubPathProvider();
  // What `NavisApp.builder` does at startup. Without it `DateFormat`
  // falls back to en_US and every golden shows «26 Apr 2026» while the
  // rest of the frame is in Spanish — a bug in the *shot*, not the app,
  // and the kind that makes a real one invisible.
  NavisDateUtils.useLocale(locale);

  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      // The same baseline world the widget tests get. Without it a golden sees
      // `boatPermissionsProvider` in its fail-closed state and renders a
      // padlock: that is how the documents baseline came to show "action
      // unavailable" instead of a document list, and stayed that way — goldens
      // are out of CI, so nothing was watching.
      overrides: [...defaultTestOverrides, ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpGoldenFrames(tester);
  }
}

/// Pumps the frame sequence used for screens that never settle.
///
/// Deliberately many small frames rather than three big ones. Two things need
/// them, and the old three-frame version served neither:
///
///  * **Chained async providers.** A screen like the document list resolves
///    `boatPermissionsProvider` first and only then mounts the subtree that
///    watches `boatDocumentsProvider`, so the content needs one frame per link
///    in the chain before it exists at all.
///  * **Entrance animations.** A widget created on the *last* pumped frame has
///    a controller sitting at zero, so it is captured fully transparent. That
///    is how the documents baseline came to be a blank page with a working app
///    bar: the cards were in the tree, at opacity 0.0, and no frame was left to
///    advance them.
///
/// Four seconds of 100 ms frames covers both, and stays deterministic because
/// the test clock is fake — the same elapsed time gives the same pixels on
/// every run.
Future<void> pumpGoldenFrames(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Golden file path for a screen in a given theme:
/// `goldens/<name>_<light|dark>.png`.
String goldenPath(String name, Brightness brightness) =>
    'goldens/${name}_${brightness == Brightness.dark ? 'dark' : 'light'}.png';
