import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';

import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/split_sheet.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/widgets/expense_period_picker.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_status_badge.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Empty (or unparseable) input means "not set" — null, never zero, so an
/// interval or a cost the user left blank is cleared server-side.
int? _parseInt(String s) => int.tryParse(s.trim());

double? _parseDouble(String s) => double.tryParse(s.trim());

/// The interval a periodic task falls back to when the owner named one but left
/// the "how often" blank. A yearly service is the safe guess for a boat, and it
/// beats rejecting the form over a field the API cannot do without.
const _defaultIntervalMonths = 12;

/// Maps an expense category API value to its localized display label.
String _categoryLabel(AppLocalizations l, String category) =>
    switch (category) {
      'combustible' => l.expenseCategoryFuel,
      'amarre' => l.expenseCategoryMooring,
      'seguro' => l.expenseCategoryInsurance,
      'reparación' => l.expenseCategoryRepair, // i18n-exempt: API value
      'limpieza' => l.expenseCategoryCleaning,
      'otros' => l.expenseCategoryOther,
      _ => category,
    };

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.maintenanceAndExpenses,
          showBack: true,
          // No cost-intelligence shortcut here: it is a section of the boat's
          // detail screen, where everything about the boat now lives. Two
          // entry points to one screen was duplication.
          bottom: TabBar(
            tabs: [
              Tab(text: l.maintenanceTab),
              Tab(text: l.expensesTab),
            ],
          ),
        ),
        body: GradientBackground(
          child: SafeArea(
            top: false,
            child: TabBarView(
              children: [
                _MaintenanceTab(boatId: boatId),
                _ExpensesTab(boatId: boatId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A suggested task template: what it is, and how often it comes back. Every
/// suggestion carries a month interval so the task it creates has a date from
/// the start — a suggestion that only knew engine hours used to produce a task
/// that could never warn on an engine nobody logs hours for.
typedef _TaskTemplate = ({String name, int months, double? hours});

List<_TaskTemplate> _taskTemplates(AppLocalizations l) => [
      (name: l.taskEngineOil, months: 12, hours: 100),
      (name: l.taskFilters, months: 12, hours: 100),
      (name: l.taskAnodes, months: 12, hours: null),
      (name: l.taskAntifouling, months: 12, hours: null),
      (name: l.taskImpeller, months: 24, hours: 200),
      (name: l.taskCoolant, months: 24, hours: null),
    ];

/// Colour + label for a task's state, in the documents palette: an owner reads
/// "Vencido" the same way on an oil change as on an insurance policy.
(Color, String) _statusPill(AppLocalizations l, MaintenanceStatus s) =>
    switch (s) {
      MaintenanceStatus.expired => (AppColors.red, l.expired),
      MaintenanceStatus.critical => (AppColors.red, l.critical),
      MaintenanceStatus.warning => (AppColors.amber, l.warning),
      MaintenanceStatus.ok => (AppColors.green, l.valid),
      MaintenanceStatus.unscheduled => (
          AppColors.cyan,
          l.maintenanceKindOneOff
        ),
    };

/// How many photos a history entry may hold for the current user: Free mirrors
/// the server AttachmentLimit (1), paid plans get the hard cap (10).
int _logPhotoCap(WidgetRef ref) {
  final limit = ref.read(effectiveTierProvider).attachmentLimit;
  return limit < 0 ? 10 : limit;
}

/// Beyond three months out, the exact date says more than "in 300 days".
const _relativeWindowDays = 90;

/// When the task is next due, in the words that carry the most information:
/// how long is left while that is a number worth reading, the date otherwise.
String? _dueLabel(AppLocalizations l, MaintenanceTask t) {
  final days = t.nextDueDays;
  if (days != null) {
    if (days < 0) return l.maintenanceOverdueBy(-days);
    if (days <= _relativeWindowDays) return l.maintenanceInDays(days);
    return l.maintenanceNextDue(_fmtDate(t.nextDueDate!));
  }
  final hours = t.hoursUntilDue;
  if (hours != null) return l.readinessMaintInHours(hours.round());
  return null;
}

/// The one-line summary under a task's name: how often it repeats and when it
/// is next due, or — for a one-off job — how much history it has.
String _taskSubtitle(AppLocalizations l, MaintenanceTask t) {
  final parts = <String>[];
  if (t.isPeriodic) {
    if (t.intervalMonths != null) {
      parts.add(l.maintenanceEveryMonths(t.intervalMonths!));
    }
    if (t.intervalHours != null) {
      parts.add(l.maintenanceEveryHours(t.intervalHours!.round()));
    }
    final due = _dueLabel(l, t);
    if (due != null) parts.add(due);
  } else if (t.timesDone > 0) {
    parts.add(l.maintenanceTimesDone(t.timesDone));
    if (t.lastPerformedAt != null) {
      parts.add(l.maintenanceLastDone(_fmtDate(t.lastPerformedAt!)));
    }
  } else {
    parts.add(l.maintenanceNeverDone);
  }
  return parts.join(' · ');
}

/// Reading order within the schedule: what is late first, then what is close.
/// The API already sorts by due date, but a task driven only by engine hours has
/// no date to sort by and would otherwise sink below everything.
int _severity(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.expired => 0,
      MaintenanceStatus.critical => 1,
      MaintenanceStatus.warning => 2,
      MaintenanceStatus.ok => 3,
      MaintenanceStatus.unscheduled => 4,
    };

List<MaintenanceTask> _sortedTasks(List<MaintenanceTask> tasks) {
  final out = List<MaintenanceTask>.of(tasks);
  out.sort((a, b) {
    final bySeverity = _severity(a.status).compareTo(_severity(b.status));
    if (bySeverity != 0) return bySeverity;
    final ad = a.nextDueDays ?? 1 << 30;
    final bd = b.nextDueDays ?? 1 << 30;
    if (ad != bd) return ad.compareTo(bd);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

/// How many entries the boat-wide history shows before the "see all" row.
const _historyPreview = 5;

/// The maintenance tab manages **tasks**, and nothing else.
///
/// A task is a job on the boat: either periodic — it carries the date it is next
/// due, expires like a document and rolls forward when you mark it done — or
/// one-off, a job that just keeps a history. Confirming a task is one button, so
/// nobody creates a "service" as a separate object, guesses which plan entry it
/// belongs to, or types an interval twice. That second object, and the nine-field
/// form that came with it, is what this replaces.
class _MaintenanceTab extends ConsumerStatefulWidget {
  const _MaintenanceTab({required this.boatId});

  final String boatId;

  @override
  ConsumerState<_MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<_MaintenanceTab> {
  bool _allHistory = false;

  String get boatId => widget.boatId;

  /// Fail-closed: reads the permissions endpoint, not the (cacheable, possibly
  /// stale) boat entity, and treats loading/error as "not granted". Assuming
  /// "allowed" while we do not know is what let a member fill in a whole form
  /// and only then lose it to a 403 on save.
  bool get _canEdit => ref
      .watch(boatPermissionsProvider(boatId))
      .grants(BoatPermissionArea.manageMaintenance);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tasksAsync = ref.watch(maintenanceTasksProvider(boatId));
    final canEdit = _canEdit;

    return Stack(
      children: [
        tasksAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
          error: (e, _) => NavisErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(maintenanceTasksProvider(boatId)),
          ),
          data: (tasks) => _content(context, l, tasks, canEdit),
        ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: NavisGradientFab(
              icon: Icons.add,
              tooltip: l.maintenanceNewTask,
              onPressed: () => _editTask(context),
            ),
          ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l,
    List<MaintenanceTask> tasks,
    bool canEdit,
  ) {
    final logs = ref.watch(maintenanceLogsProvider(boatId)).valueOrNull ??
        const <MaintenanceLog>[];
    final history = List<MaintenanceLog>.of(logs)
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final shown = _allHistory || history.length <= _historyPreview
        ? history
        : history.take(_historyPreview).toList();

    final periodic = _sortedTasks(tasks.where((t) => t.isPeriodic).toList());
    final oneOff = _sortedTasks(tasks.where((t) => !t.isPeriodic).toList());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // A read-only member gets the padlock and the reason, not a screen
        // that is silently missing its buttons.
        if (!canEdit) ...[
          BlockedActionCard(
            reason: permissionReason(l, BoatPermissionArea.manageMaintenance),
            compact: true,
            onRetry: () => ref.invalidate(boatPermissionsProvider(boatId)),
          ),
          const SizedBox(height: 12),
        ],
        if (tasks.isEmpty)
          _empty(context, l, canEdit)
        else ...[
          if (periodic.isNotEmpty) ...[
            _sectionHeader(context, l.maintenanceScheduleTitle),
            for (final t in periodic) _taskCard(context, t, canEdit),
            const SizedBox(height: 8),
          ],
          if (oneOff.isNotEmpty) ...[
            _sectionHeader(context, l.maintenanceOneOffTitle),
            for (final t in oneOff) _taskCard(context, t, canEdit),
            const SizedBox(height: 8),
          ],
          if (canEdit) _SuggestedChips(boatId: boatId, tasks: tasks),
        ],
        const SizedBox(height: 8),
        _sectionHeader(context, l.maintenanceHistoryTitle),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.maintenanceHistoryEmpty,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
          )
        else ...[
          for (final m in shown) _logCard(context, m, canEdit),
          if (history.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _allHistory = true),
                child: Text(l.maintenanceSeeAll),
              ),
            ),
        ],
      ],
    );
  }

  /// Nothing planned yet: the suggestions ARE the first step, so the empty
  /// state hands over a plan instead of only naming the problem.
  Widget _empty(BuildContext context, AppLocalizations l, bool canEdit) {
    return Column(
      children: [
        NavisEmptyState(
          icon: Icons.build_circle_outlined,
          message: l.noMaintenanceTasks,
          description: l.maintenanceEmptyDescription,
          actionLabel: canEdit ? l.maintenanceNewTask : null,
          onAction: canEdit ? () => _editTask(context) : null,
        ),
        const SizedBox(height: 16),
        if (canEdit) _SuggestedChips(boatId: boatId, tasks: const []),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.txtPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _taskCard(BuildContext context, MaintenanceTask t, bool canEdit) {
    final l = AppLocalizations.of(context)!;
    final (color, label) = _statusPill(l, t.status);
    final subtitle = _taskSubtitle(l, t);
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _taskDetail(context, t, canEdit),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          color: context.txtPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (t.isPeriodic)
                      NavisStatusBadge(
                        label: label,
                        color: color,
                        glow: t.status.needsAttention,
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: t.status.needsAttention
                          ? color
                          : context.txtSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // The whole point of the rework: confirming the job is one button on
          // the card, and it both records the history and moves the date.
          if (canEdit) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _completeTask(context, t),
              icon: const Icon(Icons.check_rounded, size: Dimens.iconSm),
              label: Text(l.maintenanceDone),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cyan,
                minimumSize: const Size(0, Dimens.minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logCard(BuildContext context, MaintenanceLog m, bool canEdit) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: canEdit ? () => _editLog(context, m) : null,
      child: Row(
        children: [
          const Icon(Icons.build, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.type,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _fmtDate(m.performedAt),
                    if (m.engineHours != null) '${m.engineHours} h',
                    if (m.provider != null) m.provider!,
                  ].join(' · '),
                  style: TextStyle(color: context.txtSecondary, fontSize: 13),
                ),
                if (m.invoiceUrl != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: AppColors.cyan,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l.invoiceLabel,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (m.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  NavisPhotoThumbRow(urls: m.photoUrls, signed: true),
                ],
              ],
            ),
          ),
          if (m.cost != null) ...[
            const SizedBox(width: 8),
            Text(
              '${m.cost!.toStringAsFixed(0)} €',
              style: const TextStyle(
                color: AppColors.cyan,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A task's own page: when it is due, and every time it has been carried out
  /// — the history the owner asked for, per task rather than only boat-wide.
  Future<void> _taskDetail(
    BuildContext context,
    MaintenanceTask t,
    bool canEdit,
  ) {
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Consumer(
          builder: (ctx, r, _) {
            // Re-read the task so the sheet reflects a completion done from
            // inside it (the date moves, the badge turns green).
            final current =
                (r.watch(maintenanceTasksProvider(boatId)).valueOrNull ??
                            const <MaintenanceTask>[])
                        .where((x) => x.id == t.id)
                        .firstOrNull ??
                    t;
            final history = (r
                        .watch(maintenanceLogsProvider(boatId))
                        .valueOrNull ??
                    const <MaintenanceLog>[])
                .where((x) => x.taskId == current.id)
                .toList()
              ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
            final (color, label) = _statusPill(l, current.status);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.name,
                          style: TextStyle(
                            color: context.txtPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (current.isPeriodic)
                        NavisStatusBadge(label: label, color: color),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit, size: Dimens.iconSm),
                          tooltip: l.editTask,
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _editTask(context, existing: current);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _taskSubtitle(l, current),
                    style: TextStyle(color: context.txtSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.maintenanceTaskHistoryTitle,
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l.maintenanceHistoryEmpty,
                        style: TextStyle(color: context.txtSecondary),
                      ),
                    )
                  else
                    for (final m in history) _logCard(context, m, canEdit),
                  const SizedBox(height: 12),
                  if (canEdit)
                    NavisButton(
                      label: l.maintenanceMarkDone,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _completeTask(context, current);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Create or edit a task. Everything the owner has to decide is here — what it
  /// is, whether it comes back, and when it is next due — and nothing else.
  Future<void> _editTask(
    BuildContext context, {
    MaintenanceTask? existing,
  }) async {
    final l = AppLocalizations.of(context)!;
    final caption = TextStyle(color: context.txtSecondary, fontSize: 12);
    // The due-reminder cron is Plus+ (`CanUseMaintenanceSchedules`), while
    // keeping the schedule is free. Free owners get the plan and the in-app due
    // state — they just must not be promised a push nobody will send.
    final canRemind = ref.read(effectiveTierProvider).canMaintenanceSchedules;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final monthsCtrl = TextEditingController(
      text: existing?.intervalMonths?.toString() ?? '',
    );
    final hoursCtrl = TextEditingController(
      text: existing?.intervalHours?.toStringAsFixed(0) ?? '',
    );
    var kind = existing?.kind ?? MaintenanceKind.periodic;
    var due = existing?.nextDueDate;
    // Until the owner picks a date, it follows the interval: saying "every 12
    // months" is enough to get a task that expires a year from today.
    var dueTouched = existing?.nextDueDate != null;
    var advanced = existing?.intervalHours != null;

    DateTime? suggestedDue() {
      final months = _parseInt(monthsCtrl.text);
      if (months == null) return null;
      return DateTime.now().add(Duration(days: 30 * months));
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final effectiveDue = dueTouched ? due : suggestedDue();
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? l.maintenanceNewTask : l.editTask,
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NavisTextField(controller: nameCtrl, label: l.taskName),
                  const SizedBox(height: 12),
                  // One decision, made once: does this come back or not.
                  SegmentedButton<MaintenanceKind>(
                    segments: [
                      ButtonSegment(
                        value: MaintenanceKind.periodic,
                        label: Text(l.maintenanceKindPeriodic),
                        icon: const Icon(Icons.event_repeat, size: 16),
                      ),
                      ButtonSegment(
                        value: MaintenanceKind.oneOff,
                        label: Text(l.maintenanceKindOneOff),
                        icon: const Icon(Icons.build, size: 16),
                      ),
                    ],
                    selected: {kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setSheetState(() => kind = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kind == MaintenanceKind.periodic
                        ? (canRemind
                            ? l.maintenanceKindPeriodicHint
                            : l.maintenanceKindPeriodicHintFree)
                        : l.maintenanceKindOneOffHint,
                    style: caption,
                  ),
                  if (kind == MaintenanceKind.periodic && !canRemind)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => showPaywall(
                          ctx,
                          ref,
                          reason: l.paywallReasonMaintenanceReminders,
                          requiredTier: PlanTier.plus,
                        ),
                        child: Text(l.maintenanceRemindersPlus),
                      ),
                    ),
                  if (kind == MaintenanceKind.periodic) ...[
                    const SizedBox(height: 12),
                    NavisTextField(
                      controller: monthsCtrl,
                      keyboardType: TextInputType.number,
                      label: l.taskIntervalMonthsLabel,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.maintenanceNextDueLabel,
                        style: TextStyle(color: context.txtSecondary),
                      ),
                      subtitle: Text(
                        effectiveDue == null
                            ? l.maintenanceNextDueUnset
                            : _fmtDate(effectiveDue),
                        style: TextStyle(
                          color: context.txtPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: effectiveDue ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            due = picked;
                            dueTouched = true;
                          });
                        }
                      },
                    ),
                    // Engine hours are the secondary limit: they only ever bring
                    // a service forward, so they stay folded away for the owners
                    // (most of them) who service by the calendar.
                    TextButton.icon(
                      onPressed: () =>
                          setSheetState(() => advanced = !advanced),
                      icon: Icon(
                        advanced ? Icons.expand_less : Icons.expand_more,
                        size: Dimens.iconSm,
                      ),
                      label: Text(l.maintenanceAdvanced),
                    ),
                    if (advanced) ...[
                      NavisTextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        label: l.taskIntervalHoursLabel,
                      ),
                      const SizedBox(height: 4),
                      Text(l.maintenanceHoursHint, style: caption),
                    ],
                  ],
                  const SizedBox(height: 16),
                  NavisButton(
                    label: l.save,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                  if (existing != null)
                    TextButton(
                      onPressed: () async {
                        final ok = await NavisConfirmDialog.show(
                          ctx,
                          title: l.delete,
                          message: l.deleteConfirm,
                          confirmLabel: l.delete,
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref
                            .read(maintenanceRepositoryProvider)
                            .deleteTask(boatId, existing.id);
                        ref.invalidate(maintenanceTasksProvider(boatId));
                        ref.invalidate(maintenanceLogsProvider(boatId));
                        if (ctx.mounted) Navigator.of(ctx).pop(false);
                      },
                      child: Text(
                        l.delete,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    if (saved != true || name.isEmpty) return;
    final periodic = kind == MaintenanceKind.periodic;
    final months = _parseInt(monthsCtrl.text);
    // Read the field whether or not the section is open: folding "advanced"
    // away is a change of view, not a request to clear the hours limit.
    final hours = _parseDouble(hoursCtrl.text);
    // A periodic task with no interval at all cannot roll forward, and the API
    // rejects it: default to a year rather than bouncing the owner back.
    final effectiveMonths = periodic && months == null && hours == null
        ? _defaultIntervalMonths
        : months;
    final effectiveDue = dueTouched
        ? due
        : (effectiveMonths == null
            ? null
            : DateTime.now().add(Duration(days: 30 * effectiveMonths)));

    final body = <String, dynamic>{
      'name': name,
      'kind': kind.api,
      'interval_months': periodic ? effectiveMonths : null,
      'interval_hours': periodic ? hours : null,
      'next_due_date':
          periodic && effectiveDue != null ? _isoDate(effectiveDue) : null,
    };
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (existing == null) {
        await repo.addTask(boatId, body);
      } else {
        await repo.updateTask(boatId, existing.id, body);
      }
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }

  /// Mark a task as carried out. Prefilled with today, so the honest answer to
  /// "when?" is one tap away; the cost, the yard and the photos are there for
  /// whoever wants them and in nobody's way otherwise.
  Future<void> _completeTask(BuildContext context, MaintenanceTask t) async {
    final l = AppLocalizations.of(context)!;
    var date = DateTime.now();
    final engineCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    String? invoiceUrl;
    var photoUrls = <String>[];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.name,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l.maintenancePerformedOn(_fmtDate(date)),
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                ),
                NavisTextField(
                  controller: engineCtrl,
                  keyboardType: TextInputType.number,
                  label: l.engineHoursOptional,
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  label: l.costOptional,
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: providerCtrl,
                  label: l.providerOptional,
                ),
                const SizedBox(height: 10),
                _InvoiceField(
                  url: invoiceUrl,
                  onPicked: (u) => setSheetState(() => invoiceUrl = u),
                ),
                const SizedBox(height: 8),
                NavisPhotoStrip(
                  label: l.photosLabel,
                  urls: photoUrls,
                  signed: true,
                  maxPhotos: _logPhotoCap(ref),
                  onLimitReached: () =>
                      showPaywall(ctx, ref, reason: l.paywallReasonLogPhotos),
                  upload: (file) {
                    final userId = supabaseClient.auth.currentUser?.id;
                    if (userId == null) {
                      throw StateError('not signed in');
                    }
                    return ref
                        .read(storageServiceProvider)
                        .uploadMaintenancePhoto(userId: userId, file: file);
                  },
                  onChanged: (u) => setSheetState(() => photoUrls = u),
                ),
                const SizedBox(height: 16),
                NavisButton(
                  label: l.save,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;
    final provider = providerCtrl.text.trim();
    try {
      final updated =
          await ref.read(maintenanceRepositoryProvider).completeTask(
        boatId,
        t.id,
        {
          'performed_at': _isoDate(date),
          'engine_hours': _parseDouble(engineCtrl.text),
          'cost': _parseDouble(costCtrl.text),
          'provider': provider.isEmpty ? null : provider,
          'invoice_url': invoiceUrl,
          'photo_urls': photoUrls,
        },
      );
      ref.invalidate(maintenanceTasksProvider(boatId));
      ref.invalidate(maintenanceLogsProvider(boatId));
      // Say where the task landed: the reset is the part worth confirming.
      if (context.mounted) {
        NavisSnackbar.success(
          context,
          updated.nextDueDate == null
              ? l.maintenanceDoneSaved
              : l.maintenanceDoneRolled(_fmtDate(updated.nextDueDate!)),
        );
      }
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }

  /// Correct or remove one history entry. It is a record of something that
  /// happened, so there is nothing to schedule here — only what it cost, who
  /// did it and the evidence.
  Future<void> _editLog(BuildContext context, MaintenanceLog m) async {
    final l = AppLocalizations.of(context)!;
    final engineCtrl =
        TextEditingController(text: m.engineHours?.toString() ?? '');
    final costCtrl =
        TextEditingController(text: m.cost?.toStringAsFixed(0) ?? '');
    final providerCtrl = TextEditingController(text: m.provider ?? '');
    var date = m.performedAt;
    String? invoiceUrl = m.invoiceUrl;
    var photoUrls = List<String>.of(m.photoUrls);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.type,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l.maintenancePerformedOn(_fmtDate(date)),
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                ),
                NavisTextField(
                  controller: engineCtrl,
                  keyboardType: TextInputType.number,
                  label: l.engineHoursOptional,
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  label: l.costOptional,
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: providerCtrl,
                  label: l.providerOptional,
                ),
                const SizedBox(height: 10),
                _InvoiceField(
                  url: invoiceUrl,
                  onPicked: (u) => setSheetState(() => invoiceUrl = u),
                ),
                const SizedBox(height: 8),
                NavisPhotoStrip(
                  label: l.photosLabel,
                  urls: photoUrls,
                  signed: true,
                  maxPhotos: _logPhotoCap(ref),
                  onLimitReached: () =>
                      showPaywall(ctx, ref, reason: l.paywallReasonLogPhotos),
                  upload: (file) {
                    final userId = supabaseClient.auth.currentUser?.id;
                    if (userId == null) {
                      throw StateError('not signed in');
                    }
                    return ref
                        .read(storageServiceProvider)
                        .uploadMaintenancePhoto(userId: userId, file: file);
                  },
                  onChanged: (u) => setSheetState(() => photoUrls = u),
                ),
                const SizedBox(height: 16),
                NavisButton(
                  label: l.save,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await NavisConfirmDialog.show(
                      ctx,
                      title: l.delete,
                      message: l.deleteConfirm,
                      confirmLabel: l.delete,
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref
                        .read(maintenanceRepositoryProvider)
                        .deleteLog(boatId, m.id);
                    ref.invalidate(maintenanceLogsProvider(boatId));
                    ref.invalidate(maintenanceTasksProvider(boatId));
                    if (ctx.mounted) Navigator.of(ctx).pop(false);
                  },
                  child: Text(
                    l.delete,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;
    final provider = providerCtrl.text.trim();
    try {
      await ref.read(maintenanceRepositoryProvider).updateLog(boatId, m.id, {
        'task_id': m.taskId,
        'type': m.type,
        'performed_at': _isoDate(date),
        'engine_hours': _parseDouble(engineCtrl.text),
        'cost': _parseDouble(costCtrl.text),
        'provider': provider.isEmpty ? null : provider,
        'invoice_url': invoiceUrl,
        'photo_urls': photoUrls,
      });
      ref.invalidate(maintenanceLogsProvider(boatId));
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }
}

/// Tappable chips that add a common service to the boat's schedule in one tap,
/// interval and due date included.
class _SuggestedChips extends ConsumerWidget {
  const _SuggestedChips({required this.boatId, required this.tasks});

  final String boatId;
  final List<MaintenanceTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final existing = tasks.map((t) => t.name.toLowerCase()).toSet();
    final available = _taskTemplates(l)
        .where((t) => !existing.contains(t.name.toLowerCase()))
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.suggestedTasksLabel,
              style: TextStyle(color: context.txtSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in available)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(t.name),
                  onPressed: () => _add(context, ref, t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, _TaskTemplate t) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(maintenanceRepositoryProvider).addTask(boatId, {
        'name': t.name,
        'kind': MaintenanceKind.periodic.api,
        'interval_months': t.months,
        'interval_hours': t.hours,
      });
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }
}

class _ExpensesTab extends ConsumerStatefulWidget {
  const _ExpensesTab({required this.boatId});
  final String boatId;

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  // The month (or whole year) the ledger is showing. One value instead of an
  // enum plus a loose anchor DateTime kept consistent by hand.
  ExpensePeriod _period = ExpensePeriod.current();
  // null = all categories.
  String? _category;

  String get boatId => widget.boatId;

  bool _inScope(Expense e) {
    if (_category != null && e.category != _category) return false;
    return _period.contains(e.incurredOn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final expensesAsync = ref.watch(expensesProvider(boatId));
    final splits =
        ref.watch(boatSplitSummaryProvider(boatId)).valueOrNull ?? const {};
    final canManage = ref
        .watch(boatPermissionsProvider(boatId))
        .grants(BoatPermissionArea.manageExpenses);

    return Stack(
      children: [
        expensesAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
          error: (e, _) => NavisErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(expensesProvider(boatId)),
          ),
          data: (items) => _content(context, l, items, splits, canManage),
        ),
        if (canManage)
          Positioned(
            right: 16,
            bottom: 16,
            child: NavisGradientFab(
              icon: Icons.add,
              tooltip: l.newExpense,
              onPressed: () => _editExpense(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l,
    List<Expense> items,
    Map<String, ExpenseSplitSummary> splits,
    bool canManage,
  ) {
    // Category chips come from all-time data so the filter is stable.
    final categories = {for (final e in items) e.category}.toList()..sort();
    final scoped = items.where(_inScope).toList()
      ..sort((a, b) => b.incurredOn.compareTo(a.incurredOn));
    final total = scoped.fold<double>(0, (s, e) => s + e.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Blocked with a reason before any work is done, not a 403 on save.
        if (!canManage) ...[
          BlockedActionCard(
            reason: permissionReason(l, BoatPermissionArea.manageExpenses),
            compact: true,
            onRetry: () => ref.invalidate(boatPermissionsProvider(boatId)),
          ),
          const SizedBox(height: 12),
        ],
        _periodBar(l),
        const SizedBox(height: 12),
        if (categories.isNotEmpty) _categoryChips(l, categories),
        const SizedBox(height: 12),
        _periodTotal(context, l, total),
        const SizedBox(height: 8),
        if (scoped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: NavisEmptyState(
              icon: Icons.receipt_long_outlined,
              message: l.expensesNoneInPeriod,
            ),
          )
        else if (_period.isWholeYear)
          ..._monthBreakdown(context, l, scoped)
        else
          for (final e in scoped)
            _expenseCard(context, l, e, splits, canManage),
      ],
    );
  }

  /// The period control: one tap opens the month/year picker.
  ///
  /// Replaces the Month/Year segmented toggle plus `‹ ›` arrows, which needed
  /// one tap per step — twelve to reach the same month a year back.
  Widget _periodBar(AppLocalizations l) {
    return Row(
      children: [
        ExpensePeriodSelector(
          period: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _categoryChips(AppLocalizations l, List<String> categories) {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: Text(l.expensesFilterAll),
          selected: _category == null,
          onSelected: (_) => setState(() => _category = null),
        ),
        for (final c in categories)
          FilterChip(
            label: Text(_categoryLabel(l, c)),
            selected: _category == c,
            onSelected: (sel) => setState(() => _category = sel ? c : null),
          ),
      ],
    );
  }

  Widget _periodTotal(BuildContext context, AppLocalizations l, double total) {
    return NavisCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.expensesPeriodTotal,
              style: TextStyle(color: context.txtSecondary)),
          Text('${total.toStringAsFixed(0)} €',
              style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// Year mode: one tappable subtotal row per month that has expenses.
  List<Widget> _monthBreakdown(
    BuildContext context,
    AppLocalizations l,
    List<Expense> yearItems,
  ) {
    final byMonth = <int, double>{};
    for (final e in yearItems) {
      byMonth[e.incurredOn.month] =
          (byMonth[e.incurredOn.month] ?? 0) + e.amount;
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final m in months)
        NavisCard(
          margin: const EdgeInsets.only(bottom: 12),
          onTap: () => setState(() {
            _period = _period.withMonth(m);
          }),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(expenseMonthName(context, _period.year, m),
                  style: TextStyle(
                      color: context.txtPrimary, fontWeight: FontWeight.w600)),
              Text('${byMonth[m]!.toStringAsFixed(0)} €',
                  style: const TextStyle(
                      color: AppColors.cyan, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
    ];
  }

  Widget _expenseCard(
    BuildContext context,
    AppLocalizations l,
    Expense e,
    Map<String, ExpenseSplitSummary> splits,
    bool canManage,
  ) {
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: canManage ? () => _editExpense(context, ref, existing: e) : null,
      child: Row(
        children: [
          const Icon(Icons.euro, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryLabel(l, e.category),
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_fmtDate(e.incurredOn),
                    style:
                        TextStyle(color: context.txtSecondary, fontSize: 13)),
                if (e.liters != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.expenseLitersSummary(
                      e.liters! % 1 == 0
                          ? e.liters!.toStringAsFixed(0)
                          : e.liters!.toStringAsFixed(1),
                      (e.pricePerLiter ?? (e.amount / e.liters!))
                          .toStringAsFixed(2),
                    ),
                    style: const TextStyle(color: AppColors.cyan, fontSize: 12),
                  ),
                ],
                if (splits[e.id] case final s?) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups,
                          size: 14,
                          color:
                              s.mySettled ? AppColors.green : AppColors.cyan),
                      const SizedBox(width: 4),
                      Text(
                        s.mySettled
                            ? l.splitSettled
                            : (s.myShare != null
                                ? l.splitYouOwe(s.myShare!.round())
                                : l.splitSharedAmong(s.count)),
                        style: TextStyle(
                            color:
                                s.mySettled ? AppColors.green : AppColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                if (e.invoiceUrl != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file,
                          size: 14, color: AppColors.cyan),
                      const SizedBox(width: 2),
                      Text(l.invoiceLabel,
                          style: const TextStyle(
                              color: AppColors.cyan, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${e.amount.toStringAsFixed(0)} €',
              style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          IconButton(
            icon: Icon(Icons.groups_outlined,
                size: 20, color: context.txtSecondary),
            tooltip: l.splitTitle,
            onPressed: () async {
              // Expense splitting is available on all tiers (viral hook) — no paywall.
              await showSplitSheet(
                context,
                ref,
                boatId: boatId,
                expenseId: e.id,
                amount: e.amount,
                title: _categoryLabel(l, e.category),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editExpense(BuildContext context, WidgetRef ref,
      {Expense? existing}) async {
    final l = AppLocalizations.of(context)!;
    var category = existing?.category ?? '';
    final amountCtrl =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final litersCtrl = TextEditingController(
      text: existing?.liters == null
          ? ''
          : (existing!.liters! % 1 == 0
              ? existing.liters!.toStringAsFixed(0)
              : existing.liters!.toStringAsFixed(2)),
    );
    var date = existing?.incurredOn ?? DateTime.now();
    String? invoiceUrl = existing?.invoiceUrl;
    const categories = [
      'combustible',
      'amarre',
      'seguro',
      'reparación', // i18n-exempt: API value
      'limpieza',
      'otros'
    ];
    // Seed the free-text field only when the saved category is a custom one
    // (not one of the quick-pick chips).
    final customCtrl = TextEditingController(
      text: categories.contains(category) ? '' : category,
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? l.newExpense : l.editExpense,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.categoryLabel,
                    style: TextStyle(color: context.txtSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(_categoryLabel(l, c)),
                        selected: category == c,
                        onSelected: (_) => setState(() {
                          category = c;
                          customCtrl.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: customCtrl,
                  label: l.customCategory,
                  hint: l.customCategoryHint,
                  onChanged: (v) => setState(() => category = v.trim()),
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  label: l.amountEur,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                // Fuel expenses can record litres so cost intelligence derives
                // a real €/L (the amount alone lost the quantity).
                if (category == 'combustible') ...[
                  NavisTextField(
                    controller: litersCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: l.expenseLitersLabel,
                    onChanged: (_) => setState(() {}),
                  ),
                  Builder(builder: (_) {
                    final a = double.tryParse(amountCtrl.text.trim());
                    final li = double.tryParse(litersCtrl.text.trim());
                    if (a == null || li == null || li <= 0) {
                      return const SizedBox(height: 10);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 10),
                      child: Text(
                        l.pricePerLiterValue((a / li).toStringAsFixed(2)),
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.dateWithValue(_fmtDate(date)),
                      style: TextStyle(color: context.txtPrimary)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
                _InvoiceField(
                  url: invoiceUrl,
                  onPicked: (u) => setState(() => invoiceUrl = u),
                ),
                const SizedBox(height: 12),
                NavisButton(
                  label: l.save,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      final ok = await NavisConfirmDialog.show(
                        ctx,
                        title: l.delete,
                        message: l.deleteConfirm,
                        confirmLabel: l.delete,
                        destructive: true,
                      );
                      if (!ok) return;
                      await ref
                          .read(maintenanceRepositoryProvider)
                          .deleteExpense(boatId, existing.id);
                      ref.invalidate(expensesProvider(boatId));
                      ref.invalidate(expenseSummaryProvider(boatId));
                      if (ctx.mounted) Navigator.of(ctx).pop(false);
                    },
                    child: Text(l.delete,
                        style: const TextStyle(color: AppColors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || category.isEmpty || amountCtrl.text.trim().isEmpty) {
      return;
    }
    // Litres only make sense for fuel; a parseable positive value is sent,
    // otherwise null (which also clears a previously-set value on edit).
    final liters = category == 'combustible'
        ? double.tryParse(litersCtrl.text.trim())
        : null;
    final body = <String, dynamic>{
      'category': category,
      'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
      'incurred_on': _isoDate(date),
      'invoice_url': invoiceUrl,
      'liters': (liters != null && liters > 0) ? liters : null,
    };
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (existing == null) {
        await repo.addExpense(boatId, body);
      } else {
        await repo.updateExpense(boatId, existing.id, body);
      }
      ref.invalidate(expensesProvider(boatId));
      ref.invalidate(expenseSummaryProvider(boatId));
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, l.couldNotSave);
      }
    }
  }
}

/// Attach / view / remove an invoice (image) for a maintenance or expense entry.
class _InvoiceField extends ConsumerStatefulWidget {
  const _InvoiceField({required this.url, required this.onPicked});

  final String? url;
  final ValueChanged<String?> onPicked;

  @override
  ConsumerState<_InvoiceField> createState() => _InvoiceFieldState();
}

class _InvoiceFieldState extends ConsumerState<_InvoiceField> {
  bool _uploading = false;

  Future<void> _pick() async {
    final l = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.chooseFromGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(storageServiceProvider)
          .uploadInvoice(userId: userId, file: File(picked.path));
      widget.onPicked(url);
    } catch (_) {
      if (mounted) NavisSnackbar.error(context, l.couldNotUploadInvoice);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_uploading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (widget.url == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(l.attachInvoice),
        ),
      );
    }
    return Row(
      children: [
        const Icon(Icons.receipt_long, color: AppColors.cyan, size: 18),
        const SizedBox(width: 8),
        Text(l.invoiceAttached, style: TextStyle(color: context.txtPrimary)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: l.view,
          onPressed: () async {
            // Private bucket: exchange the stored URL for a signed one.
            final signed = await ref
                .read(storageServiceProvider)
                .signedDocumentUrl(widget.url!);
            if (signed != null) {
              await launchUrl(Uri.parse(signed),
                  mode: LaunchMode.externalApplication);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: AppColors.red),
          tooltip: l.remove,
          onPressed: () => widget.onPicked(null),
        ),
      ],
    );
  }
}
