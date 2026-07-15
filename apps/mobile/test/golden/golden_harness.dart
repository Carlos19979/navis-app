import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

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
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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

/// Pumps the fixed frame sequence used for screens that never settle:
/// one frame to start async providers, one for entrance animations and a
/// final one-second frame so staggered effects reach a stable state.
Future<void> pumpGoldenFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

/// Golden file path for a screen in a given theme:
/// `goldens/<name>_<light|dark>.png`.
String goldenPath(String name, Brightness brightness) =>
    'goldens/${name}_${brightness == Brightness.dark ? 'dark' : 'light'}.png';
