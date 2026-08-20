@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/expenses_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

class _MockMaintenanceRepository extends Mock
    implements MaintenanceRepository {}

/// The expense ledger, its own route since the maintenance screen was split.
/// Worth a baseline because it is where the money is read: the amounts go
/// through `Money`, and a separator or symbol bug shows up here first.
void main() {
  setUpAll(loadTestFonts);

  // The ledger opens on the current month, so the fixtures have to land there.
  final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 12);
  final expenses = [
    makeExpense(
      id: 'e-1',
      category: 'combustible',
      amount: 248.4,
      liters: 150,
      incurredOn: thisMonth,
    ),
    makeExpense(
      id: 'e-2',
      category: 'amarre',
      amount: 1450,
      incurredOn: thisMonth,
    ),
    makeExpense(
      id: 'e-3',
      category: 'reparación',
      amount: 320,
      incurredOn: thisMonth,
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('expenses — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const ExpensesScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          maintenanceRepositoryProvider
              .overrideWithValue(_MockMaintenanceRepository()),
          expensesProvider.overrideWith((ref, id) async => expenses),
          expenseSummaryProvider.overrideWith(
            (ref, id) async => const ExpenseSummary(totals: {}, total: 0),
          ),
          boatSplitSummaryProvider.overrideWith(
            (ref, id) async => const <String, ExpenseSplitSummary>{},
          ),
        ],
      );
      await expectLater(
        find.byType(ExpensesScreen),
        matchesGoldenFile(goldenPath('expenses', brightness)),
      );
    });
  }
}
