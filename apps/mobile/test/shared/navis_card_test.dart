import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// NavisCard is the base card of the app, so a `BackdropFilter` inside it cost
/// one blur pass per card per frame (ten of them in a ten-row list) for an
/// effect that is invisible over the app's smooth gradient background. These
/// tests pin the fix: no blur, same translucent gradient and hairline border.
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

    testWidgets('keeps a translucent gradient, not the opaque card look',
        (tester) async {
      for (final brightness in Brightness.values) {
        final decoration = await pumpAndReadDecoration(
          tester,
          brightness: brightness,
        );

        final gradient = decoration.gradient! as LinearGradient;
        expect(
          gradient.colors.every((c) => c.a < 1.0),
          isTrue,
          reason: 'the background must still show through the card',
        );
        // The opaque variant (solid colour + drop shadow) would change the
        // look; removing the blur must not turn the card into it.
        expect(decoration.color, isNull);
        expect(decoration.boxShadow, isNull);
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
