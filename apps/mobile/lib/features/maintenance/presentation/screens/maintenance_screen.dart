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
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Empty (or unparseable) input means "not set" — null, never zero, so an
/// interval or a cost the user left blank is cleared server-side.
int? _parseInt(String s) => int.tryParse(s.trim());

double? _parseDouble(String s) => double.tryParse(s.trim());

/// The plan entry a service belongs to when its name says so (case- and
/// whitespace-insensitive). Typing the name of an existing entry means the
/// same job, so the service must count as servicing it.
MaintenanceTask? _taskByName(List<MaintenanceTask> tasks, String name) {
  final needle = name.trim().toLowerCase();
  for (final t in tasks) {
    if (t.name.trim().toLowerCase() == needle) return t;
  }
  return null;
}

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

/// A suggested maintenance task template (name + default interval).
typedef _TaskTemplate = ({String name, int? months, double? hours});

List<_TaskTemplate> _taskTemplates(AppLocalizations l) => [
      (name: l.taskEngineOil, months: null, hours: 100),
      (name: l.taskFilters, months: null, hours: 100),
      (name: l.taskAnodes, months: 12, hours: null),
      (name: l.taskAntifouling, months: 12, hours: null),
      (name: l.taskImpeller, months: 24, hours: 200),
      (name: l.taskCoolant, months: 24, hours: null),
    ];

(Color, IconData) _taskVisuals(BuildContext context, MaintenanceStatus s) =>
    switch (s) {
      MaintenanceStatus.overdue => (context.critical, Icons.error_rounded),
      MaintenanceStatus.dueSoon => (context.caution, Icons.schedule_rounded),
      MaintenanceStatus.pending => (
          context.caution,
          Icons.help_outline_rounded
        ),
      MaintenanceStatus.ok => (context.positive, Icons.check_circle_rounded),
      MaintenanceStatus.none => (context.txtSecondary, Icons.history_rounded),
    };

/// "in X d" / "in Y h" for whichever limit is nearer.
String? _dueLabel(AppLocalizations l, MaintenanceTask t) {
  final days = t.nextDueDays;
  final hrs = t.hoursUntilDue;
  if (hrs != null && (days == null || hrs < days)) {
    return l.readinessMaintInHours(hrs.round());
  }
  if (days != null) return l.maintenanceInDays(days);
  return null;
}

/// How many photos a maintenance log may hold for the current user: Free
/// mirrors the server AttachmentLimit (1), Pro gets the hard cap (10).
int _logPhotoCap(WidgetRef ref) {
  final limit = ref.read(effectiveTierProvider).attachmentLimit;
  return limit < 0 ? 10 : limit;
}

String _taskStatusLabel(AppLocalizations l, MaintenanceTask t) =>
    switch (t.status) {
      MaintenanceStatus.overdue => l.readinessMaintOverdue,
      MaintenanceStatus.dueSoon => _dueLabel(l, t) ?? l.maintenanceDueSoonLabel,
      MaintenanceStatus.pending => l.readinessMaintPending,
      MaintenanceStatus.ok => _dueLabel(l, t) ?? '',
      MaintenanceStatus.none => l.maintenanceNoInterval,
    };

/// The interval + last-done summary shown under a task.
String _taskSubtitle(AppLocalizations l, MaintenanceTask t) {
  final parts = <String>[];
  if (t.intervalMonths != null) {
    parts.add(l.maintenanceEveryMonths(t.intervalMonths!));
  }
  if (t.intervalHours != null) {
    parts.add(l.maintenanceEveryHours(t.intervalHours!.round()));
  }
  if (t.lastPerformedAt != null) {
    parts.add(l.maintenanceLastDone(_fmtDate(t.lastPerformedAt!)));
  }
  return parts.join(' · ');
}

/// Reading order of the plan: what is late first, then what is close, then
/// the rest. Sorting server-side would need a second query per status.
int _urgencyRank(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.overdue => 0,
      MaintenanceStatus.dueSoon => 1,
      MaintenanceStatus.pending => 2,
      MaintenanceStatus.ok => 3,
      MaintenanceStatus.none => 4,
    };

List<MaintenanceTask> _sortedTasks(List<MaintenanceTask> tasks) {
  final out = List<MaintenanceTask>.of(tasks);
  out.sort((a, b) {
    final rank = _urgencyRank(a.status).compareTo(_urgencyRank(b.status));
    if (rank != 0) return rank;
    final ad = a.nextDueDays ?? 1 << 30;
    final bd = b.nextDueDays ?? 1 << 30;
    if (ad != bd) return ad.compareTo(bd);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

/// How many services the history shows before the "see all" row.
const _historyPreview = 5;

/// The maintenance tab has ONE primary action: record what you did. A plan
/// entry is not something you create separately — it is a service you told us
/// repeats, so "record service" carries an optional interval and creates (or
/// updates) the task itself. Two peer lists with two different add buttons,
/// plus an "other records" bucket that only meant "logs I failed to link",
/// was the confusion this replaces.
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
              tooltip: l.recordService,
              onPressed: () => _editMaintenance(
                context,
                tasks: tasksAsync.valueOrNull ?? const [],
              ),
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
    // One history for the whole boat: a service linked to a plan entry used to
    // be visible only inside that entry, so the owner had two places to look.
    final history = List<MaintenanceLog>.of(logs)
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final shown = _allHistory || history.length <= _historyPreview
        ? history
        : history.take(_historyPreview).toList();

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
        if (tasks.isEmpty) ...[
          // Nothing planned yet: the suggestions ARE the plan section.
          if (canEdit) _SuggestedChips(boatId: boatId, tasks: tasks),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l.noMaintenanceTasks,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.txtSecondary),
            ),
          ),
        ] else ...[
          _sectionHeader(context, l.maintenanceUpcomingTitle),
          for (final t in _sortedTasks(tasks))
            _taskCard(context, t, canEdit, tasks),
        ],
        const SizedBox(height: 16),
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
          for (final m in shown) _logCard(context, m, canEdit, tasks),
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

  Widget _taskCard(
    BuildContext context,
    MaintenanceTask t,
    bool canEdit,
    List<MaintenanceTask> tasks,
  ) {
    final l = AppLocalizations.of(context)!;
    final (color, _) = _taskVisuals(context, t.status);
    final subtitle = _taskSubtitle(l, t);
    final caption = TextStyle(color: context.txtSecondary, fontSize: 13);
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _taskDetail(context, t, canEdit, tasks),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _taskStatusLabel(l, t),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logCard(
    BuildContext context,
    MaintenanceLog m,
    bool canEdit,
    List<MaintenanceTask> tasks,
  ) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: canEdit
          ? () => _editMaintenance(context, existing: m, tasks: tasks)
          : null,
      child: Row(
        children: [
          Icon(Icons.build, color: context.accent),
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
                      Icon(
                        Icons.attach_file,
                        size: 14,
                        color: context.accent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l.invoiceLabel,
                        style: TextStyle(
                          color: context.accent,
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
              style: TextStyle(
                color: context.accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _taskDetail(
    BuildContext context,
    MaintenanceTask t,
    bool canEdit,
    List<MaintenanceTask> tasks,
  ) {
    final l = AppLocalizations.of(context)!;
    final caption = TextStyle(color: context.txtSecondary, fontSize: 13);
    final subtitle = _taskSubtitle(l, t);
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
            final history =
                (r.watch(maintenanceLogsProvider(boatId)).valueOrNull ??
                        const <MaintenanceLog>[])
                    .where((x) => x.taskId == t.id)
                    .toList();
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.name,
                          style: TextStyle(
                            color: context.txtPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: l.editTask,
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _editTask(context, t);
                          },
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: caption),
                  ],
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l.maintenanceHistoryEmpty,
                        style: TextStyle(color: context.txtSecondary),
                      ),
                    )
                  else
                    for (final m in history)
                      _logCard(context, m, canEdit, tasks),
                  const SizedBox(height: 12),
                  if (canEdit)
                    NavisButton(
                      label: l.recordService,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _editMaintenance(
                          context,
                          presetTaskId: t.id,
                          tasks: tasks,
                        );
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

  /// Rename / re-schedule / delete an existing plan entry. Creating one is not
  /// here on purpose: a plan entry is born from a recorded service (or a
  /// suggestion chip), never from a separate "add task" form.
  Future<void> _editTask(BuildContext context, MaintenanceTask existing) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing.name);
    final monthsCtrl =
        TextEditingController(text: existing.intervalMonths?.toString() ?? '');
    final hoursCtrl = TextEditingController(
      text: existing.intervalHours?.toStringAsFixed(0) ?? '',
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.editTask,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              NavisTextField(controller: nameCtrl, label: l.taskName),
              const SizedBox(height: 10),
              NavisTextField(
                controller: monthsCtrl,
                keyboardType: TextInputType.number,
                label: l.taskIntervalMonthsLabel,
              ),
              const SizedBox(height: 10),
              NavisTextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                label: l.taskIntervalHoursLabel,
              ),
              const SizedBox(height: 12),
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
                      .deleteTask(boatId, existing.id);
                  ref.invalidate(maintenanceTasksProvider(boatId));
                  ref.invalidate(maintenanceLogsProvider(boatId));
                  if (ctx.mounted) Navigator.of(ctx).pop(false);
                },
                child: Text(
                  l.delete,
                  style: TextStyle(color: context.critical),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      await repo.updateTask(boatId, existing.id, {
        'name': nameCtrl.text.trim(),
        'interval_months': _parseInt(monthsCtrl.text),
        'interval_hours': _parseDouble(hoursCtrl.text),
      });
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }

  /// The single write flow of the tab: what was done, when, what it cost —
  /// and, optionally, how often it repeats. The interval is what turns the
  /// service into a plan entry, so the user never meets "task" as a concept.
  Future<void> _editMaintenance(
    BuildContext context, {
    MaintenanceLog? existing,
    String? presetTaskId,
    List<MaintenanceTask> tasks = const [],
  }) async {
    final l = AppLocalizations.of(context)!;
    final caption = TextStyle(color: context.txtSecondary, fontSize: 12);
    // The maintenance-due cron is Plus+ (`CanUseMaintenanceSchedules`), while
    // creating the plan entry is free. So Free keeps the plan and the in-app
    // due state — it just must not be promised a reminder nobody will send.
    final canRemind = ref.read(effectiveTierProvider).canMaintenanceSchedules;
    final typeCtrl = TextEditingController(text: existing?.type ?? '');
    final engineCtrl =
        TextEditingController(text: existing?.engineHours?.toString() ?? '');
    final costCtrl =
        TextEditingController(text: existing?.cost?.toStringAsFixed(0) ?? '');
    final providerCtrl = TextEditingController(text: existing?.provider ?? '');
    var date = existing?.performedAt ?? DateTime.now();
    String? invoiceUrl = existing?.invoiceUrl;
    var photoUrls = List<String>.of(existing?.photoUrls ?? const []);

    MaintenanceTask? taskById(String? id) {
      for (final t in tasks) {
        if (t.id == id) return t;
      }
      return null;
    }

    // A stale task id (the entry was deleted meanwhile) resolves to null.
    // `linked` is reassigned from the sheet, so the setup reads `initial`:
    // a local captured by a closure cannot be type-promoted.
    final initial = taskById(existing?.taskId ?? presetTaskId);
    var linked = initial;
    final monthsCtrl = TextEditingController(
      text: initial?.intervalMonths?.toString() ?? '',
    );
    final everyHoursCtrl = TextEditingController(
      text: initial?.intervalHours?.toStringAsFixed(0) ?? '',
    );

    // Linking to a plan entry also names the service and shows the entry's
    // current interval, so one tap fills three fields.
    void selectTask(MaintenanceTask? t) {
      linked = t;
      monthsCtrl.text = t?.intervalMonths?.toString() ?? '';
      everyHoursCtrl.text = t?.intervalHours?.toStringAsFixed(0) ?? '';
      if (t != null) typeCtrl.text = t.name;
    }

    if (initial != null && typeCtrl.text.trim().isEmpty) {
      typeCtrl.text = initial.name;
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
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? l.recordService : l.edit,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                // Tapping a plan entry both names the service and links it —
                // the old dropdown asked for the link as a separate decision.
                if (tasks.isNotEmpty) ...[
                  Text(l.maintenancePartOfPlan, style: caption),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tasks)
                        ChoiceChip(
                          label: Text(t.name),
                          selected: linked?.id == t.id,
                          onSelected: (on) => setSheetState(
                            () => selectTask(on ? t : null),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                NavisTextField(
                  controller: typeCtrl,
                  label: l.maintenanceWhatWasDone,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l.dateWithValue(_fmtDate(date)),
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
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
                Divider(color: context.glassBorderColor),
                const SizedBox(height: 4),
                Text(
                  l.maintenanceRepeatEvery,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: NavisTextField(
                        controller: monthsCtrl,
                        keyboardType: TextInputType.number,
                        label: l.maintenanceIntervalMonths,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NavisTextField(
                        controller: everyHoursCtrl,
                        keyboardType: TextInputType.number,
                        label: l.maintenanceIntervalHours,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  canRemind
                      ? l.maintenanceRepeatHint
                      : l.maintenanceRepeatHintFree,
                  style: caption,
                ),
                if (!canRemind)
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
                          .deleteLog(boatId, existing.id);
                      ref.invalidate(maintenanceLogsProvider(boatId));
                      ref.invalidate(maintenanceTasksProvider(boatId));
                      if (ctx.mounted) Navigator.of(ctx).pop(false);
                    },
                    child: Text(
                      l.delete,
                      style: TextStyle(color: context.critical),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final type = typeCtrl.text.trim();
    if (saved != true || type.isEmpty) return;
    final months = _parseInt(monthsCtrl.text);
    final everyHours = _parseDouble(everyHoursCtrl.text);
    final repo = ref.read(maintenanceRepositoryProvider);
    final task = linked;
    try {
      final typedInterval = months != null || everyHours != null;
      var taskId = task?.id;
      if (task != null) {
        // Linked from a chip: the fields came prefilled with this entry's
        // schedule, so whatever they hold now is the intent — empty included.
        if (months != task.intervalMonths || everyHours != task.intervalHours) {
          await repo.updateTask(boatId, task.id, {
            'name': task.name,
            'interval_months': months,
            'interval_hours': everyHours,
          });
        }
      } else {
        final match = _taskByName(tasks, type);
        if (match != null) {
          taskId = match.id;
          // Here empty means "said nothing", not "clear the schedule" — the
          // fields were never prefilled, so they must not wipe the entry.
          if (typedInterval &&
              (months != match.intervalMonths ||
                  everyHours != match.intervalHours)) {
            await repo.updateTask(boatId, match.id, {
              'name': match.name,
              'interval_months': months,
              'interval_hours': everyHours,
            });
          }
        } else if (typedInterval) {
          // "Repeats every ..." on an unlinked service IS how a plan entry
          // is created — no separate form, no second trip through the UI.
          final created = await repo.addTask(boatId, {
            'name': type,
            'interval_months': months,
            'interval_hours': everyHours,
          });
          taskId = created.id;
        }
      }
      final provider = providerCtrl.text.trim();
      final body = <String, dynamic>{
        'task_id': taskId,
        'type': type,
        'performed_at': _isoDate(date),
        'engine_hours': _parseDouble(engineCtrl.text),
        'cost': _parseDouble(costCtrl.text),
        'provider': provider.isEmpty ? null : provider,
        'invoice_url': invoiceUrl,
        'photo_urls': photoUrls,
      };
      if (existing == null) {
        await repo.addLog(boatId, body);
      } else {
        await repo.updateLog(boatId, existing.id, body);
      }
      ref.invalidate(maintenanceLogsProvider(boatId));
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      // The plan entry may have been written before the log failed. Refetch so
      // a retry sees it and links to it instead of creating a twin.
      ref.invalidate(maintenanceTasksProvider(boatId));
      ref.invalidate(maintenanceLogsProvider(boatId));
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }
}

/// A row of tappable chips that quick-add common maintenance tasks not yet on
/// the boat's plan.
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
            child: _emptyPeriod(l, items),
          )
        else if (_period.isWholeYear)
          ..._monthBreakdown(context, l, scoped)
        else
          for (final e in scoped)
            _expenseCard(context, l, e, splits, canManage),
      ],
    );
  }

  /// An empty *period* is not an empty ledger.
  ///
  /// This is the one empty state in the app whose way out is not «add one»: the
  /// entries may well exist, just not in the month being looked at. So the
  /// action widens the window to somewhere that has something — the whole year
  /// first, and failing that the most recent year with any entry at all.
  Widget _emptyPeriod(AppLocalizations l, List<Expense> items) {
    if (items.isEmpty) {
      // Genuinely nothing, ever. Then «add one» *is* the answer.
      return NavisEmptyState(
        icon: Icons.receipt_long_outlined,
        message: l.noExpensesRecorded,
        actionLabel: l.newExpense,
        onAction: () => _editExpense(context, ref),
      );
    }

    final wider = _widerPeriodWithData(items);
    return NavisEmptyState(
      icon: Icons.receipt_long_outlined,
      message: l.expensesNoneInPeriod,
      description: l.expensesEmptyPeriodDescription,
      actionLabel: wider == null ? null : l.seeAllExpenses,
      onAction: wider == null ? null : () => setState(() => _period = wider),
    );
  }

  /// The nearest period that actually holds something: this year in full, else
  /// the most recent year with an entry. Null when the current period is
  /// already the whole of the only year with data.
  ExpensePeriod? _widerPeriodWithData(List<Expense> items) {
    if (!_period.isWholeYear) {
      final year = ExpensePeriod.wholeYear(_period.year);
      if (items.any((e) => year.contains(e.incurredOn))) return year;
    }
    final years = items.map((e) => e.incurredOn.year).toSet().toList()..sort();
    for (final year in years.reversed) {
      if (year != _period.year || !_period.isWholeYear) {
        return ExpensePeriod.wholeYear(year);
      }
    }
    return null;
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
              style: TextStyle(
                  color: context.accent,
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
                  style: TextStyle(
                      color: context.accent, fontWeight: FontWeight.w800)),
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
          Icon(Icons.euro, color: context.accent),
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
                    style: TextStyle(color: context.accent, fontSize: 12),
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
                              s.mySettled ? context.positive : context.accent),
                      const SizedBox(width: 4),
                      Text(
                        s.mySettled
                            ? l.splitSettled
                            : (s.myShare != null
                                ? l.splitYouOwe(s.myShare!.round())
                                : l.splitSharedAmong(s.count)),
                        style: TextStyle(
                            color:
                                s.mySettled ? context.positive : context.accent,
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
                      Icon(Icons.attach_file, size: 14, color: context.accent),
                      const SizedBox(width: 2),
                      Text(l.invoiceLabel,
                          style:
                              TextStyle(color: context.accent, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${e.amount.toStringAsFixed(0)} €',
              style: TextStyle(
                  color: context.accent,
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
                        style: TextStyle(
                          color: context.accent,
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
                        style: TextStyle(color: context.critical)),
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
        Icon(Icons.receipt_long, color: context.accent, size: 18),
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
          icon: Icon(Icons.close, size: 18, color: context.critical),
          tooltip: l.remove,
          onPressed: () => widget.onPicked(null),
        ),
      ],
    );
  }
}
