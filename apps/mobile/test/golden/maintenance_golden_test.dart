@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
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
      id: 't-expired',
      name: 'Anodes',
      status: MaintenanceStatus.expired,
      nextDueDays: -3,
    ),
    makeMaintenanceTask(
      id: 't-critical',
      name: 'Filters',
      status: MaintenanceStatus.critical,
      nextDueDays: 5,
    ),
    makeMaintenanceTask(
      id: 't-warning',
      name: 'Coolant',
      status: MaintenanceStatus.warning,
      nextDueDays: 60,
    ),
    makeMaintenanceTask(id: 't-ok', name: 'Impeller'),
    makeOneOffTask(),
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
          // The owner's view: without this the harness renders the read-only
          // member screen, which is missing the Done button the tab is about.
          boatPermissionsProvider.overrideWith(
            (ref, id) async => const BoatPermissions.all(),
          ),
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
