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
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_status_badge.dart';

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
          boatPermissionsProvider.overrideWith(
            (ref, id) async => const BoatPermissions.none(),
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

  group('MaintenanceScreen task states', () {
    testWidgets('each tier gets the documents badge and its due wording',
        (tester) async {
      setPhoneSize(tester);
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
        // Factory defaults: status ok, next due in 90 days.
        makeMaintenanceTask(id: 't-ok', name: 'Impeller'),
      ];
      await tester.pumpWidget(buildSubject(tasks: () async => tasks));
      await pumpScreen(tester);

      // The same words a document uses, so the two screens read alike.
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      // The due wording sits in the subtitle, next to the interval.
      expect(find.textContaining('3 d overdue'), findsOneWidget);
      expect(find.textContaining('in 5 d'), findsOneWidget);
      expect(find.textContaining('in 60 d'), findsOneWidget);
    });

    // Past three months, "in 300 days" says less than the date itself.
    testWidgets('a far-off task shows its date, not a day count',
        (tester) async {
      setPhoneSize(tester);
      final task = makeMaintenanceTask(
        nextDueDays: 300,
        nextDueDate: DateTime(2027, 3, 15),
      );
      await tester.pumpWidget(buildSubject(tasks: () async => [task]));
      await pumpScreen(tester);

      expect(find.textContaining('next 15/03/2027'), findsOneWidget);
      expect(find.textContaining('in 300 d'), findsNothing);
    });

    testWidgets('a one-off job has its own section and no badge',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          tasks: () async => [makeMaintenanceTask(), makeOneOffTask()],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Recurring services'), findsOneWidget);
      expect(find.text('One-off jobs'), findsOneWidget);
      expect(find.text('Bilge pump'), findsOneWidget);
      // Nothing to expire against, so no status pill at all.
      expect(find.byType(NavisStatusBadge), findsOneWidget);
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
      // A suggestion now carries a month interval too, so the task it creates
      // has a date to expire against even on an engine nobody logs hours for.
      expect(body['kind'], 'periodic');
      expect(body['interval_months'], 12);
      expect(body['interval_hours'], 100);
    });
  });

  group('MaintenanceScreen member permissions', () {
    testWidgets('canEdit=false hides the FAB, the chips and Done',
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
      expect(find.text('Done'), findsNothing);
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
          expenses: () async => [makeExpense()],
          canManage: false,
        ),
      );
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.byType(NavisGradientFab), findsNothing);
      expect(find.byType(BlockedActionCard), findsOneWidget);
      // Splitting writes expense_splits, guarded by the same flag.
      expect(find.byTooltip('Split expense'), findsNothing);

      await drain(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('MaintenanceScreen task sheet', () {
    testWidgets('creates a recurring task with an interval and a due date',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeMaintenanceTask());
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);

      expect(find.text('Task name'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text('One-off'), findsOneWidget);
      expect(find.text('Every (months)'), findsOneWidget);
      expect(find.text('Next due'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Antifouling',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Every (months)'),
        '12',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['name'], 'Antifouling');
      expect(body['kind'], 'periodic');
      expect(body['interval_months'], 12);
      // Saying "every 12 months" is enough: the date follows the interval, so
      // the task can warn from the day it is created.
      expect(body['next_due_date'], isNotNull);
    });

    testWidgets('a one-off task is saved without any schedule', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeOneOffTask());
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Bilge pump',
      );
      await tester.tap(find.text('One-off'));
      await pumpScreen(tester);

      // Picking one-off takes the whole schedule off the form.
      expect(find.text('Every (months)'), findsNothing);
      expect(find.text('Next due'), findsNothing);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['kind'], 'one_off');
      expect(body['interval_months'], isNull);
      expect(body['next_due_date'], isNull);
    });

    // Engine hours only ever bring a service forward, so they stay folded away
    // for the owners who service by the calendar.
    testWidgets('engine hours live behind Advanced', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeMaintenanceTask());
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);

      expect(find.text('Every (engine hours)'), findsNothing);

      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      await pumpScreen(tester);

      expect(find.text('Every (engine hours)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Engine oil',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Every (engine hours)'),
        '100',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['interval_hours'], 100);
    });

    // The API cannot store a recurring task with nothing to roll by, and the
    // owner should not be bounced back for leaving one field empty.
    testWidgets('a recurring task with no interval falls back to a year',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.addTask(boatId, any()))
          .thenAnswer((_) async => makeMaintenanceTask());
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Life raft service',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(() => mockRepo.addTask(boatId, captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['interval_months'], 12);
      expect(body['next_due_date'], isNotNull);
    });
  });

  group('MaintenanceScreen marking a task done', () {
    testWidgets('Done records the job and reports the new date',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.completeTask(boatId, 'task-1', any())).thenAnswer(
        (_) async => makeMaintenanceTask(nextDueDate: DateTime(2027, 8, 21)),
      );
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Done'));
      await pumpScreen(tester);

      // Prefilled with today: one tap on Save is the whole flow.
      expect(find.textContaining('Carried out on'), findsOneWidget);
      expect(find.text('Cost € (opt.)'), findsOneWidget);
      // The form no longer asks what was done, nor how often it repeats.
      expect(find.text('What was done? (e.g. oil change)'), findsNothing);
      expect(find.text('Every (months)'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cost € (opt.)'),
        '180',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(
        () => mockRepo.completeTask(boatId, 'task-1', captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(body['cost'], 180);
      expect(body['performed_at'], isNotNull);
      // Where the task landed is the part worth confirming.
      expect(find.textContaining('next on 21/08/2027'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('the task detail sheet lists that task\'s own history',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          tasks: () async => [makeMaintenanceTask(timesDone: 2)],
          logs: () async => [
            makeMaintenanceLog(id: 'l1', type: 'Oil change', taskId: 'task-1'),
            makeMaintenanceLog(id: 'l2', type: 'Hull job', taskId: 'other'),
          ],
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Engine oil change'));
      await pumpScreen(tester);

      expect(find.text('Times carried out'), findsOneWidget);
      expect(find.text('Mark as done'), findsOneWidget);
      // Only this task's entries — the boat-wide list behind the sheet still
      // holds the other one, so scope the check to the sheet itself.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Oil change')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Hull job')),
        findsNothing,
      );

      await drain(tester);
    });

    testWidgets('a failed completion keeps the sheet\'s work in a snackbar',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.completeTask(boatId, 'task-1', any()))
          .thenThrow(Exception('boom'));
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Done'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      expect(find.text('Could not save'), findsOneWidget);

      await drain(tester);
    });
  });

  group('MaintenanceScreen reminder gating', () {
    testWidgets('Free is told reminders are a Plus feature', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(pro: false));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);
      await tester.ensureVisible(find.text('Get reminded with Navis Plus'));

      // The cron is Plus+, so Free must not read a promise of a reminder.
      expect(find.text('Get reminded with Navis Plus'), findsOneWidget);
      expect(find.textContaining('we warn you'), findsNothing);
    });

    testWidgets('a paid plan keeps the reminder promise', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New service'));
      await pumpScreen(tester);

      expect(find.text('Get reminded with Navis Plus'), findsNothing);
      expect(find.textContaining('we warn you'), findsOneWidget);
    });
  });

  group('MaintenanceScreen history', () {
    testWidgets('lists every entry, whichever task it belongs to',
        (tester) async {
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

      // The boat-wide history stands next to each task's own: a service used
      // to be visible only inside its plan entry.
      expect(find.text('History'), findsOneWidget);
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

    testWidgets('the completion sheet has the photo strip and sends photo_urls',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.completeTask(boatId, 'task-1', any()))
          .thenAnswer((_) async => makeMaintenanceTask());
      await tester.pumpWidget(
        buildSubject(tasks: () async => [makeMaintenanceTask()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Done'));
      await pumpScreen(tester);

      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(NavisPhotoStrip), findsOneWidget);
      expect(find.byTooltip('Add Photo'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final body = verify(
        () => mockRepo.completeTask(boatId, 'task-1', captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(body['photo_urls'], isA<List<String>>());

      await drain(tester);
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

      // Open the history-entry sheet from the log card, then try to add a
      // second photo: Free's AttachmentLimit (1) is already used up.
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

    testWidgets('picking another month drops this month\'s expense',
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
