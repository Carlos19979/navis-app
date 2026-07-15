@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

class _MockMaintenanceRepository extends Mock
    implements MaintenanceRepository {}

void main() {
  setUpAll(loadTestFonts);

  final tasks = [
    makeMaintenanceTask(
      id: 't-overdue',
      name: 'Anodes',
      status: MaintenanceStatus.overdue,
      nextDueDays: -3,
    ),
    makeMaintenanceTask(
      id: 't-due-soon',
      name: 'Filters',
      status: MaintenanceStatus.dueSoon,
      nextDueDays: 5,
    ),
    makeMaintenanceTask(
      id: 't-pending',
      name: 'Coolant',
      status: MaintenanceStatus.pending,
      nextDueDays: null,
    ),
    makeMaintenanceTask(id: 't-ok', name: 'Impeller'),
  ];

  final logs = [makeMaintenanceLog()];

  for (final brightness in Brightness.values) {
    testWidgets('maintenance — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const MaintenanceScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          boatProvider.overrideWith((ref, id) async => makeBoat(id: id)),
          maintenanceRepositoryProvider
              .overrideWithValue(_MockMaintenanceRepository()),
          maintenanceTasksProvider.overrideWith((ref, id) async => tasks),
          maintenanceLogsProvider.overrideWith((ref, id) async => logs),
          expensesProvider.overrideWith((ref, id) async => const <Expense>[]),
          expenseSummaryProvider.overrideWith(
            (ref, id) async => const ExpenseSummary(totals: {}, total: 0),
          ),
          boatSplitSummaryProvider.overrideWith(
            (ref, id) async => const <String, ExpenseSplitSummary>{},
          ),
        ],
      );
      await expectLater(
        find.byType(MaintenanceScreen),
        matchesGoldenFile(goldenPath('maintenance', brightness)),
      );
    });
  }
}
