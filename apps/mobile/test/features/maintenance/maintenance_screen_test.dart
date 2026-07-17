// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/helpers.dart';

class _MockMaintenanceRepository extends Mock
    implements MaintenanceRepository {}

class _MockStorageService extends Mock implements StorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const boatId = 'boat-1';

  late _MockMaintenanceRepository mockRepo;
  late _MockStorageService mockStorage;

  setUp(() {
    mockRepo = _MockMaintenanceRepository();
    mockStorage = _MockStorageService();
    // Signed resolution "offline": photo thumbnails render the placeholder
    // instead of fetching a network image.
    when(() => mockStorage.signedDocumentUrl(any()))
        .thenAnswer((_) async => null);
  });

  Widget buildSubject({
    Future<List<MaintenanceTask>> Function()? tasks,
    Future<List<MaintenanceLog>> Function()? logs,
    Future<List<Expense>> Function()? expenses,
    ExpenseSummary? summary,
    Map<String, ExpenseSplitSummary> splits = const {},
    bool canManage = true,
    bool pro = true,
  }) {
    return buildTestApp(
      const MaintenanceScreen(boatId: boatId),
      overrides: [
        ...planOverrides(pro: pro),
        storageServiceProvider.overrideWithValue(mockStorage),
        maintenanceRepositoryProvider.overrideWithValue(mockRepo),
        maintenanceTasksProvider.overrideWith(
          (ref, id) => tasks?.call() ?? Future.value(<MaintenanceTask>[]),
        ),
        maintenanceLogsProvider.overrideWith(
          (ref, id) => logs?.call() ?? Future.value(<MaintenanceLog>[]),
        ),
        expensesProvider.overrideWith(
          (ref, id) => expenses?.call() ?? Future.value(<Expense>[]),
        ),
        expenseSummaryProvider.overrideWith(
          (ref, id) async =>
              summary ?? const ExpenseSummary(totals: {}, total: 0),
        ),
        boatSplitSummaryProvider.overrideWith((ref, id) async => splits),
        if (!canManage)
          boatProvider.overrideWith(
            (ref, id) async => makeBoat(id: id).copyWith(
              isOwner: false,
              permissions: const BoatPermissions(
                canManageMaintenance: false,
                canManageExpenses: false,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> openExpensesTab(WidgetTester tester) async {
    await tester.tap(find.text('Expenses'));
    // One frame to start the tab transition, one to finish it (the page is
    // built lazily during the animation) and one for the async providers.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  group('MaintenanceScreen maintenance tab async states', () {
    testWidgets('loading shows shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<MaintenanceTask>>();
      await tester.pumpWidget(buildSubject(tasks: () => completer.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavisShimmer), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(tasks: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
    });

    testWidgets('empty shows the no-tasks message and suggested chips',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('No maintenance tasks yet'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('Engine oil'), findsOneWidget);
      expect(find.text('Antifouling'), findsOneWidget);
      expect(find.text('No services recorded yet'), findsOneWidget);
    });

    testWidgets('populated shows the task cards', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      expect(find.text('Engine oil change'), findsOneWidget);
      expect(find.text('No maintenance tasks yet'), findsNothing);
    });
  });

  group('MaintenanceScreen task status labels', () {
    testWidgets('renders each status tier with its label', (tester) async {
      setPhoneSize(tester);
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
        // Factory defaults: status ok, next due in 90 days.
        makeMaintenanceTask(id: 't-ok', name: 'Impeller'),
      ];
      await tester.pumpWidget(buildSubject(tasks: () async => tasks));
      await pumpScreen(tester);

      expect(find.text('overdue'), findsOneWidget);
      expect(find.text('in 5 d'), findsOneWidget);
      expect(find.text('not logged yet'), findsOneWidget);
      expect(find.text('in 90 d'), findsOneWidget);
    });

    testWidgets('hours-until-due wins over days when nearer', (tester) async {
      setPhoneSize(tester);
      final task = makeMaintenanceTask(
        status: MaintenanceStatus.dueSoon,
        nextDueDays: 30,
        hoursUntilDue: 12,
      );
      await tester.pumpWidget(buildSubject(tasks: () async => [task]));
      await pumpScreen(tester);

      expect(find.text('in 12 h'), findsOneWidget);
      expect(find.text('in 30 d'), findsNothing);
    });
  });

  group('MaintenanceScreen suggested chips', () {
    testWidgets('hidden when every template task already exists',
        (tester) async {
      setPhoneSize(tester);
      final names = [
        'Engine oil',
        'Filters',
        'Anodes',
        'Antifouling',
        'Impeller',
        'Coolant',
      ];
      final tasks = [
        for (final (i, name) in names.indexed)
          makeMaintenanceTask(id: 'task-$i', name: name),
      ];
      await tester.pumpWidget(buildSubject(tasks: () async => tasks));
      await pumpScreen(tester);

      expect(find.text('Suggested'), findsNothing);
    });

    testWidgets('tapping a chip adds the template task', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Engine oil'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['name'], 'Engine oil');
      expect(body['interval_hours'], 100);
    });
  });

  group('MaintenanceScreen member permissions', () {
    testWidgets('canEdit=false hides FAB, chips and record-service icon',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          tasks: () async => [makeMaintenanceTask()],
          canManage: false,
        ),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisGradientFab), findsNothing);
      expect(find.byTooltip('Record service'), findsNothing);
      expect(find.text('Suggested'), findsNothing);
    });

    testWidgets('canManageExpenses=false hides the expenses FAB',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [makeExpense()],
          canManage: false,
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.byType(NavisGradientFab), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('MaintenanceScreen sheets', () {
    testWidgets('record-service sheet opens with fields and saves a log',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      expect(find.text('Record service'), findsOneWidget);
      expect(find.text('Type (e.g. oil change)'), findsOneWidget);
      expect(find.text('Engine Hours (optional)'), findsOneWidget);
      expect(find.text('Cost € (opt.)'), findsOneWidget);
      expect(find.text('Provider (opt.)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type (e.g. oil change)'),
        'Oil change',
      );
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['type'], 'Oil change');
    });

    testWidgets('add-task sheet opens from the FAB and saves a task',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Add task'));
      await pumpScreen(tester);

      expect(find.text('Add task'), findsWidgets);
      expect(find.text('Task name'), findsOneWidget);
      expect(find.text('Every (months)'), findsOneWidget);
      expect(find.text('Every (engine hours)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Rigging check',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Every (months)'),
        '12',
      );
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['name'], 'Rigging check');
      expect(body['interval_months'], 12);
    });
  });

  group('MaintenanceScreen log photos', () {
    testWidgets('log card renders photo thumbnails', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          logs: () async => [
            makeMaintenanceLog(photoUrls: const [
              'https://x.test/impeller.jpg',
              'https://x.test/anode.jpg',
            ]),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisPhotoThumbRow), findsOneWidget);
      expect(find.byType(NavisPhotoThumb), findsNWidgets(2));
    });

    testWidgets(
        'record-service sheet has the photo strip and saves '
        'photo_urls', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(NavisPhotoStrip), findsOneWidget);
      expect(find.byTooltip('Add Photo'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type (e.g. oil change)'),
        'Impeller swap',
      );
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['type'], 'Impeller swap');
      expect(body['photo_urls'], isA<List<String>>());
    });

    testWidgets('Free plan: adding beyond one photo shows the paywall',
        (tester) async {
      setPhoneSize(tester);
      final log = makeMaintenanceLog(
        photoUrls: const ['https://x.test/one.jpg'],
      );
      await tester.pumpWidget(
        buildSubject(pro: false, logs: () async => [log]),
      );
      await pumpScreen(tester);

      // Open the edit sheet from the log card, then try to add a second
      // photo: Free's AttachmentLimit (1) is already used up.
      await tester.tap(find.text('engine_service'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.byTooltip('Add Photo'));
      await tester.tap(find.byTooltip('Add Photo'));
      await pumpScreen(tester);

      expectPaywall();
      // The source picker never opened.
      expect(find.text('Take Photo'), findsNothing);

      await drain(tester);
    });
  });

  group('MaintenanceScreen expenses tab', () {
    // The ledger defaults to the current month, so fixtures must land there.
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 15);

    testWidgets('loading shows shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<Expense>>();
      await tester.pumpWidget(buildSubject(expenses: () => completer.future));
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.byType(NavisShimmer), findsWidgets);

      await drain(tester);
    });

    testWidgets('error shows error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(expenses: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('empty shows the no-expenses state', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.text('No expenses in this period'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('populated shows expense cards with category labels',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [
            makeExpense(
                id: 'e-1',
                category: 'combustible',
                amount: 86,
                incurredOn: thisMonth),
            makeExpense(
                id: 'e-2',
                category: 'amarre',
                amount: 300,
                incurredOn: thisMonth),
            makeExpense(
                id: 'e-3',
                category: 'winch service',
                amount: 50,
                incurredOn: thisMonth),
          ],
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.text('Fuel'), findsWidgets);
      expect(find.text('Mooring'), findsWidgets);
      // Custom categories pass through unmapped.
      expect(find.text('winch service'), findsWidgets);
      expect(find.text('86 €'), findsOneWidget);
      expect(find.text('300 €'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('period total sums the current month', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [
            makeExpense(id: 'e-1', amount: 500, incurredOn: thisMonth),
            makeExpense(id: 'e-2', amount: 450, incurredOn: thisMonth),
            // A prior-year expense is outside the current month → excluded.
            makeExpense(id: 'e-old', amount: 999, incurredOn: DateTime(2020)),
          ],
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.text('Period total'), findsOneWidget);
      expect(find.text('950 €'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('year view breaks down per-month subtotals', (tester) async {
      setPhoneSize(tester);
      final year = DateTime.now().year;
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [
            makeExpense(id: 'a', amount: 100, incurredOn: DateTime(year, 3, 5)),
            makeExpense(id: 'b', amount: 60, incurredOn: DateTime(year, 3, 9)),
            makeExpense(id: 'c', amount: 40, incurredOn: DateTime(year, 8, 2)),
          ],
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      // Switch to Year mode.
      await tester.tap(find.text('Year'));
      await tester.pump(const Duration(milliseconds: 400));

      // March subtotal = 160, August = 40, year total = 200.
      expect(find.text('160 €'), findsOneWidget);
      expect(find.text('40 €'), findsOneWidget);
      expect(find.text('200 €'), findsOneWidget); // period total

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('split badges show settled / you-owe / shared variants',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [
            makeExpense(id: 'e-settled', incurredOn: thisMonth),
            makeExpense(id: 'e-owe', category: 'amarre', incurredOn: thisMonth),
            makeExpense(
                id: 'e-shared', category: 'limpieza', incurredOn: thisMonth),
          ],
          splits: const {
            'e-settled': ExpenseSplitSummary(
              count: 2,
              myShare: 40,
              mySettled: true,
            ),
            'e-owe': ExpenseSplitSummary(
              count: 2,
              myShare: 25,
              mySettled: false,
            ),
            'e-shared': ExpenseSplitSummary(
              count: 3,
              myShare: null,
              mySettled: false,
            ),
          },
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('You owe 25 €'), findsOneWidget);
      expect(find.text('Split among 3'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('category chip filters the list and total', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async => [
            makeExpense(
                id: 'f',
                category: 'combustible',
                amount: 80,
                incurredOn: thisMonth),
            makeExpense(
                id: 'm',
                category: 'amarre',
                amount: 300,
                incurredOn: thisMonth),
          ],
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      // All → total 380.
      expect(find.text('380 €'), findsOneWidget);

      // Filter to Fuel → total 80, mooring card gone.
      await tester.tap(find.widgetWithText(FilterChip, 'Fuel'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('80 €'), findsWidgets);
      expect(find.text('300 €'), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('prev-month chevron moves out of the current month',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          expenses: () async =>
              [makeExpense(id: 'e', amount: 120, incurredOn: thisMonth)],
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      // Shows in both the card and the period-total row.
      expect(find.text('120 €'), findsNWidgets(2));

      // Step back one month → this month's expense drops out.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.text('120 €'), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
