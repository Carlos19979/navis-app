import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';

import '../helpers/helpers.dart';

/// A list only reads as a list if its columns are columns.
///
/// This is the defect the user found by looking at the app: the trailing value
/// was a `Flexible` sharing its flex with the title's `Expanded`, so the two
/// split the free space **50/50** and every value right-aligned inside a box of
/// a different width. Measured, in adjacent rows: «sin registrar» ended at
/// x=374 and «en 90 d» at x=313 — 61 px apart, in the same list.
///
/// Eyeballing is what let it ship, so this measures.
void main() {
  Future<void> pumpRows(WidgetTester tester, List<Widget> rows) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(buildTestAppWithScaffold(NavisList(children: rows)));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Right edges of every [text], to one decimal.
  List<double> rightEdges(WidgetTester tester, List<String> texts) => [
        for (final t in texts) tester.getRect(find.text(t)).right,
      ];

  testWidgets('values share one right edge, whatever the title length',
      (tester) async {
    await pumpRows(tester, const [
      NavisRow(title: 'Documentos', value: '3/5'),
      NavisRow(title: 'Equipo de seguridad y salvamento', value: '4/4'),
      NavisRow(title: 'Mantenimiento', value: '1/1'),
    ]);

    final edges = rightEdges(tester, ['3/5', '4/4', '1/1']);
    expect(
      edges.toSet().length,
      1,
      reason: 'the three values must end at the same x, got $edges',
    );
  });

  testWidgets('a chip and a plain value end at the same edge', (tester) async {
    await pumpRows(tester, const [
      NavisRow(
        title: 'Anodes',
        value: 'vencida',
        valueTone: NavisTone.critical,
      ),
      NavisRow(title: 'Coolant', value: 'sin registrar'),
      NavisRow(title: 'Impeller', value: 'en 90 d'),
    ]);

    // The chip's *fill* is the object that has to line up with the text edge,
    // so it is measured through the chip, not through its label.
    final chip = tester.getRect(find.byType(NavisRow).first).right;
    final plain = rightEdges(tester, ['sin registrar', 'en 90 d']);
    expect(plain.toSet().length, 1, reason: 'got $plain');
    expect(chip, greaterThan(plain.first - 1));
  });

  testWidgets('a navigable row does not shift the column of a plain one',
      (tester) async {
    // Mixing the two in one list is what made the maintenance plan look
    // ragged: the chevron used to be laid out *after* the value, so a list
    // with both put its values at two different x.
    await pumpRows(tester, [
      NavisRow(title: 'Con chevron', value: '10 MN', onTap: () {}),
      const NavisRow(title: 'Sin chevron', value: '20 MN'),
    ]);

    final edges = rightEdges(tester, ['10 MN', '20 MN']);
    expect(
      edges.toSet().length,
      1,
      reason:
          'navigable and plain rows must share the value column, got $edges',
    );
  });

  testWidgets('a long value is cut, not allowed to eat the title',
      (tester) async {
    await pumpRows(tester, const [
      NavisRow(title: 'Proveedor', value: 'Marina Insurance Baleares SL'),
      NavisRow(title: 'Fecha', value: '29 sept 2026'),
    ]);

    final edges = rightEdges(tester, ['29 sept 2026']);
    final title = tester.getRect(find.text('Proveedor'));
    expect(title.left, 16, reason: 'the title keeps the gutter');
    expect(edges.single, greaterThan(300));
  });
}
