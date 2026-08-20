// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/expenses_screen.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import 'package:navis_mobile/features/maintenance/presentation/widgets/expense_period_picker.dart';

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
    bool ledger = false,
  }) {
    return buildTestApp(
      ledger
          ? const ExpensesScreen(boatId: boatId)
          : const MaintenanceScreen(boatId: boatId),
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
          boatPermissionsProvider.overrideWith(
            (ref, id) async => const BoatPermissions.none(),
          ),
      ],
    );
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
    testWidgets('hidden once the plan has any entry', (tester) async {
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
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeMaintenanceTask());
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
      // Blocked with a reason, not silently stripped of its buttons.
      expect(find.byType(BlockedActionCard), findsOneWidget);
      expect(find.text('Action unavailable'), findsOneWidget);
    });

    testWidgets('canManageExpenses=false hides the expenses FAB',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          ledger: true,
          expenses: () async => [makeExpense()],
          canManage: false,
        ),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisGradientFab), findsNothing);
      expect(find.byType(BlockedActionCard), findsOneWidget);
      // Splitting writes expense_splits, guarded by the same flag.
      expect(find.byTooltip('Split expense'), findsNothing);

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
      expect(find.text('What was done? (e.g. oil change)'), findsOneWidget);
      expect(find.text('Engine hours (optional)'), findsOneWidget);
      expect(find.text('Cost € (opt.)'), findsOneWidget);
      expect(find.text('Provider (opt.)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        'Oil change',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['type'], 'Oil change');
    });

    testWidgets('an interval turns the service into a plan entry',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeMaintenanceTask(id: 'new-task'));
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        'Antifouling',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Months'), '12');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      // The plan entry is created from the service, not from a second form.
      final task = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(task['name'], 'Antifouling');
      expect(task['interval_months'], 12);

      // ...and the log is linked to it in the same save.
      final log = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(log['type'], 'Antifouling');
      expect(log['task_id'], 'new-task');
    });

    testWidgets('no interval leaves the service unlinked', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        'Bilge pump',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.addTask(any(), any()));
      final log = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(log['task_id'], isNull);
    });

    testWidgets('picking a plan chip links the service to it', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      // The chip names the service and links it in one tap.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Engine oil change'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final log = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(log['type'], 'Engine oil change');
      expect(log['task_id'], 'task-1');
    });
  });

  group('MaintenanceScreen plan matching', () {
    testWidgets('a service named like a plan entry links to it',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(
          tasks: () async =>
              [makeMaintenanceTask(id: 'task-9', name: 'Antifouling')],
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        '  antifouling ',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      // No twin entry, and the plan's schedule is left alone: the interval
      // fields were never prefilled, so empty means "said nothing".
      verifyNever(() => mockRepo.addTask(any(), any()));
      verifyNever(() => mockRepo.updateTask(any(), any(), any()));
      final log = verify(() => mockRepo.addLog(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(log['task_id'], 'task-9');
    });

    testWidgets('typing an interval on a matched entry reschedules it',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addLog(boatId, any())).thenAnswer((_) async {});
      when(() => mockRepo.updateTask(boatId, any(), any()))
          .thenAnswer((_) async {});
      await tester.pumpWidget(
        buildSubject(
          // The factory already schedules it every 12 months.
          tasks: () async =>
              [makeMaintenanceTask(id: 'task-9', name: 'Antifouling')],
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        'Antifouling',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Months'), '24');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.addTask(any(), any()));
      final body = verify(
        () => mockRepo.updateTask(boatId, 'task-9', captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(body['interval_months'], 24);
    });
  });

  group('MaintenanceScreen reminder gating', () {
    testWidgets('Free is told reminders are a Plus feature', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(pro: false));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.text('Get reminded with Navis Plus'));

      // The cron is Plus+, so Free must not read a promise of a reminder.
      expect(find.text('Get reminded with Navis Plus'), findsOneWidget);
      expect(
        find.textContaining('we remind you when it is due'),
        findsNothing,
      );
    });

    testWidgets('a paid plan keeps the reminder promise', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Record service'));
      await pumpScreen(tester);

      expect(find.text('Get reminded with Navis Plus'), findsNothing);
      expect(
        find.textContaining('we remind you when it is due'),
        findsOneWidget,
      );
    });
  });

  group('MaintenanceScreen history', () {
    testWidgets('lists linked services too', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          tasks: () async => [makeMaintenanceTask()],
          logs: () async => [
            makeMaintenanceLog(id: 'l1', type: 'Oil change', taskId: 'task-1'),
            makeMaintenanceLog(id: 'l2', type: 'Bilge pump'),
          ],
        ),
      );
      await pumpScreen(tester);

      // Both kinds share one history: a linked service used to be visible
      // only inside its plan entry.
      // Tracked uppercase, like every section heading in the app.
      expect(find.text('HISTORY'), findsOneWidget);
      expect(find.text('Oil change'), findsOneWidget);
      expect(find.text('Bilge pump'), findsOneWidget);
      // "Other records" is gone as a concept.
      expect(find.text('Other records'), findsNothing);
    });

    testWidgets('long history collapses behind See all', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          logs: () async => [
            for (var i = 0; i < 7; i++)
              makeMaintenanceLog(
                id: 'l$i',
                type: 'Service $i',
                performedAt: DateTime(2026, 1, i + 1),
              ),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('See all'), findsOneWidget);

      await tester.ensureVisible(find.text('See all'));
      await tester.tap(find.text('See all'));
      await pumpScreen(tester);

      expect(find.text('See all'), findsNothing);
    });

    testWidgets('short history shows no See all row', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(logs: () async => [makeMaintenanceLog()]),
      );
      await pumpScreen(tester);

      expect(find.text('See all'), findsNothing);
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
      expect(find.byTooltip('Add photo'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'What was done? (e.g. oil change)'),
        'Impeller swap',
      );
      await tester.ensureVisible(find.text('Save'));
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
      await tester.tap(find.text('Engine service'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.byTooltip('Add photo'));
      await tester.tap(find.byTooltip('Add photo'));
      await pumpScreen(tester);

      expectPaywall();
      // The source picker never opened.
      expect(find.text('Take photo'), findsNothing);

      await drain(tester);
    });
  });

  group('MaintenanceScreen expenses tab', () {
    // The ledger defaults to the current month, so fixtures must land there.
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 15);

    testWidgets('loading shows shimmer', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<List<Expense>>();
      await tester.pumpWidget(
          buildSubject(ledger: true, expenses: () => completer.future));
      await pumpScreen(tester);

      expect(find.byType(NavisShimmer), findsWidgets);

      await drain(tester);
    });

    testWidgets('error shows error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
            ledger: true, expenses: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a ledger with nothing in it offers adding one',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(
        ledger: true,
      ));
      await pumpScreen(tester);

      // Not "none in this period": that implies there are some elsewhere, and
      // it left the only truly empty state in the app without a way out.
      expect(find.text('No expenses recorded'), findsOneWidget);
      expect(find.text('New expense'), findsWidgets);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an empty period offers widening it, not adding',
        (tester) async {
      setPhoneSize(tester);
      // Entries exist, just not in the month the ledger opens on. Widening is
      // the answer; "add one" would be advice to duplicate what is already
      // there.
      final lastYear = DateTime(DateTime.now().year - 1, 6, 12);
      await tester.pumpWidget(
        buildSubject(
          ledger: true,
          expenses: () async => [makeExpense(incurredOn: lastYear)],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.text('See the whole history'), findsOneWidget);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('populated shows expense cards with category labels',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          ledger: true,
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
          ledger: true,
          expenses: () async => [
            makeExpense(id: 'e-1', amount: 500, incurredOn: thisMonth),
            makeExpense(id: 'e-2', amount: 450, incurredOn: thisMonth),
            // A prior-year expense is outside the current month → excluded.
            makeExpense(id: 'e-old', amount: 999, incurredOn: DateTime(2020)),
          ],
        ),
      );
      await pumpScreen(tester);

      // The label is an overline now, and the amount goes through Money — so
      // it carries the locale's grouping and symbol placement (tests run in
      // English: «€950.00»).
      expect(find.text('PERIOD TOTAL'), findsOneWidget);
      expect(find.textContaining('950'), findsWidgets);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('year view breaks down per-month subtotals', (tester) async {
      setPhoneSize(tester);
      final year = DateTime.now().year;
      await tester.pumpWidget(
        buildSubject(
          ledger: true,
          expenses: () async => [
            makeExpense(id: 'a', amount: 100, incurredOn: DateTime(year, 3, 5)),
            makeExpense(id: 'b', amount: 60, incurredOn: DateTime(year, 3, 9)),
            makeExpense(id: 'c', amount: 40, incurredOn: DateTime(year, 8, 2)),
          ],
        ),
      );
      await pumpScreen(tester);

      // Year mode is reached through the period picker now: the Month/Year
      // segmented toggle was replaced by one tappable label.
      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Whole year'));
      await tester.pumpAndSettle();

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
          ledger: true,
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
          ledger: true,
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

    testWidgets('picking another month drops this month\'s expense',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          ledger: true,
          expenses: () async =>
              [makeExpense(id: 'e', amount: 120, incurredOn: thisMonth)],
        ),
      );
      await pumpScreen(tester);

      // Shows in both the card and the period-total row.
      expect(find.text('120 €'), findsNWidgets(2));

      // Jump to a different month through the picker (the ‹ › chevrons were
      // replaced: reaching last summer took twelve taps).
      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();
      final otherMonth = thisMonth.month == 1 ? 'Feb' : 'Jan';
      await tester.tap(find.text(otherMonth));
      await tester.pumpAndSettle();

      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.text('120 €'), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
