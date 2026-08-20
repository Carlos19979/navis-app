import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// NavisCard is the base surface of the app, so anything it draws is drawn once
/// per card per frame — ten times over in a ten-row list, which is what showed
/// up as foreground battery drain. These tests pin the two costs that must never
/// come back: **no blur** and **no drop shadow**.
///
/// The card's *fill* is an aesthetic choice and it has moved: it used to be a
/// translucent veil over the ocean gradient, and in the editorial design it is
/// an opaque surface closed by a hairline. That change is deliberate, so the
/// assertions here are about cost, not about translucency — a solid fill is
/// free, a shadow and a blur are not.
void main() {
  Future<BoxDecoration> pumpAndReadDecoration(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    LinearGradient? gradient,
    Color? borderColor,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        home: Scaffold(
          body: NavisCard(
            gradient: gradient,
            borderColor: borderColor,
            child: const Text('content'),
          ),
        ),
      ),
    );
    // The card paints with a DecoratedBox rather than a Container: it needs a
    // decoration and nothing else Container offers.
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(NavisCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  group('NavisCard', () {
    testWidgets('draws no BackdropFilter', (tester) async {
      await pumpAndReadDecoration(tester);

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('draws no drop shadow, in either theme', (tester) async {
      for (final brightness in Brightness.values) {
        final decoration = await pumpAndReadDecoration(
          tester,
          brightness: brightness,
        );

        // A shadow per card is the other per-frame cost, and on the light
        // canvas it also reads as a grey smudge. Depth comes from the hairline.
        expect(
          decoration.boxShadow,
          anyOf(isNull, isEmpty),
          reason: 'depth must come from the hairline, not from elevation',
        );
        expect(decoration.gradient, isNotNull);
      }
    });

    testWidgets('keeps the hairline border at the surface radius',
        (tester) async {
      final decoration = await pumpAndReadDecoration(tester);

      expect(decoration.border, isNotNull);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(Dimens.radiusSurface),
      );
      final side = (decoration.border! as Border).top;
      expect(side.width, Dimens.hairline);
    });

    testWidgets('honours a caller gradient and border colour', (tester) async {
      const custom = LinearGradient(colors: [Color(0x11223344), Colors.red]);
      final decoration = await pumpAndReadDecoration(
        tester,
        gradient: custom,
        borderColor: Colors.amber,
      );

      expect(decoration.gradient, custom);
      expect((decoration.border! as Border).top.color, Colors.amber);
    });

    testWidgets('taps through onTap and pads with margin', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavisCard(
              margin: const EdgeInsets.all(Dimens.spaceXl),
              onTap: () => taps++,
              child: const Text('tappable'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('tappable'));
      expect(taps, 1);
      expect(
        tester
            .widgetList<Padding>(
              find.descendant(
                of: find.byType(NavisCard),
                matching: find.byType(Padding),
              ),
            )
            .map((p) => p.padding),
        contains(const EdgeInsets.all(Dimens.spaceXl)),
      );
    });
  });
}
