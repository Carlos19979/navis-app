import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// NavisCard is the base card of the app, so a `BackdropFilter` inside it cost
/// one blur pass per card per frame (ten of them in a ten-row list) for an
/// effect that is invisible over the app's smooth gradient background. These
/// tests pin the two per-card costs that must never come back: **no blur** and
/// **no drop shadow**.
///
/// The card's *fill* is an aesthetic choice and has moved: it used to be a
/// translucent veil over the ocean gradient, and in the editorial design it is
/// an opaque surface separated by a hairline. That change is deliberate, so the
/// assertion here is about cost, not about translucency — a solid fill is free,
/// a shadow and a blur are not.
void main() {
  Future<BoxDecoration> pumpAndReadDecoration(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    LinearGradient? gradient,
    Color? borderColor,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: NavisCard(
            gradient: gradient,
            borderColor: borderColor,
            child: const Text('content'),
          ),
        ),
      ),
    );
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(NavisCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
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
        // canvas it also reads as grey smudge. Hierarchy comes from the
        // hairline below.
        expect(
          decoration.boxShadow,
          anyOf(isNull, isEmpty),
          reason: 'depth must come from the hairline, not from elevation',
        );
        expect(decoration.gradient, isNotNull);
      }
    });

    testWidgets('keeps the hairline border', (tester) async {
      final decoration = await pumpAndReadDecoration(tester);

      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      final side = (decoration.border! as Border).top;
      expect(side.width, 0.5);
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
              margin: const EdgeInsets.all(24),
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
        contains(const EdgeInsets.all(24)),
      );
    });
  });
}
