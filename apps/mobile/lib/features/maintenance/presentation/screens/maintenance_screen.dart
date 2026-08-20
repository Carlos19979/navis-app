import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/features/maintenance/presentation/maintenance_format.dart';
import 'package:navis_mobile/features/maintenance/presentation/widgets/invoice_field.dart';
import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/core/utils/money_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

/// The boat's maintenance plan and its service history.
///
/// Its own route since this phase. It used to be the first of two tabs in a
/// 1.698-line screen holding maintenance *and* expenses — 26 actions in one
/// file, and neither half linkable: a notification about an overdue service
/// could only open «maintenance and expenses» and hope the user found the tab.
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

/// The plan status as a system tone, so the dot, the chip and the readiness
/// screen all say the same thing about the same task.
NavisTone _taskTone(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.overdue => NavisTone.critical,
      MaintenanceStatus.dueSoon => NavisTone.caution,
      MaintenanceStatus.pending => NavisTone.caution,
      MaintenanceStatus.ok => NavisTone.positive,
      MaintenanceStatus.none => NavisTone.neutral,
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
    parts.add(l.maintenanceLastDone(fmtDate(t.lastPerformedAt!)));
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
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key, required this.boatId});

  final String boatId;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
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

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.maintenanceTab,
          showBack: true,
          actions: [
            // The ledger is a sibling now, not a tab: one tap either way, and
            // both are linkable.
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: l.expensesTab,
              onPressed: () => context.push(Routes.boatExpenses(boatId)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: tasksAsync.when(
            loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
            error: (e, _) => NavisErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(maintenanceTasksProvider(boatId)),
            ),
            data: (tasks) => _content(context, l, tasks, canEdit),
          ),
        ),
        floatingActionButton: canEdit
            ? NavisGradientFab(
                icon: Icons.add,
                tooltip: l.recordService,
                onPressed: () => _editMaintenance(
                  context,
                  tasks: tasksAsync.valueOrNull ?? const [],
                ),
              )
            : null,
      ),
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
      padding: Insets.screenWithNav,
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
            _taskRow(context, t, canEdit, tasks),
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

  Widget _sectionHeader(BuildContext context, String text) =>
      NavisSectionHeader(label: text);

  /// A plan entry.
  ///
  /// Row with a status chip rather than a card whose right-hand text was tinted
  /// by state: on the light canvas «due soon» in amber text was the brown this
  /// redesign had to remove, and a page of cards each with its own coloured
  /// caption had no hierarchy left for the overdue one.
  Widget _taskRow(
    BuildContext context,
    MaintenanceTask t,
    bool canEdit,
    List<MaintenanceTask> tasks,
  ) {
    final l = AppLocalizations.of(context)!;
    final subtitle = _taskSubtitle(l, t);
    final status = _taskStatusLabel(l, t);

    return NavisRow(
      icon: Icons.circle,
      iconColor: context.toneAccent(_taskTone(t.status)),
      title: t.name,
      subtitle: subtitle.isEmpty ? null : subtitle,
      value: status.isEmpty ? null : status,
      // A chip only for what is actually late or close: «ok» and «no interval»
      // are states, not urgencies, and three filled pills in a row is noise.
      valueTone: switch (t.status) {
        MaintenanceStatus.overdue => NavisTone.critical,
        MaintenanceStatus.dueSoon => NavisTone.caution,
        _ => null,
      },
      onTap: () => _taskDetail(context, t, canEdit, tasks),
      showChevron: false,
    );
  }

  /// One service in the history.
  Widget _logCard(
    BuildContext context,
    MaintenanceLog m,
    bool canEdit,
    List<MaintenanceTask> tasks,
  ) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final meta = [
      NavisDateUtils.formatDateShort(m.performedAt),
      if (m.engineHours != null)
        // No decimal: the model stores whole hours, so «120,0 h» was
        // precision the reading does not have.
        '${Measure.decimal(locale, m.engineHours!.toDouble(), digits: 0)} h',
      if (m.provider != null) m.provider!,
      if (m.invoiceUrl != null) l.invoiceLabel,
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: InkWell(
        onTap: canEdit
            ? () => _editMaintenance(context, existing: m, tasks: tasks)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.type,
                          style: NavisType.title3.copyWith(
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (m.cost != null) ...[
                    const SizedBox(width: Dimens.spaceMd),
                    Text(
                      // Through Money, like every other amount in the app.
                      Money.format(locale, m.cost!),
                      style: NavisType.title2.copyWith(color: context.ink),
                    ),
                  ],
                ],
              ),
              if (m.photoUrls.isNotEmpty) ...[
                const SizedBox(height: Dimens.spaceSm),
                NavisPhotoThumbRow(urls: m.photoUrls, signed: true),
              ],
            ],
          ),
        ),
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
        'interval_months': parseInt(monthsCtrl.text),
        'interval_hours': parseDouble(hoursCtrl.text),
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
                    l.dateWithValue(fmtDate(date)),
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
                InvoiceField(
                  url: invoiceUrl,
                  onPicked: (u) => setSheetState(() => invoiceUrl = u),
                ),
                const SizedBox(height: 8),
                NavisPhotoStrip(
                  label: l.photosLabel,
                  urls: photoUrls,
                  signed: true,
                  maxPhotos: _logPhotoCap(ref),
                  onLimitReached: () => showPaywall(
                    ctx,
                    ref,
                    reason: l.paywallReasonLogPhotos,
                    requiredTier: PlanTier.plus,
                  ),
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
    final months = parseInt(monthsCtrl.text);
    final everyHours = parseDouble(everyHoursCtrl.text);
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
        'performed_at': isoDate(date),
        'engine_hours': parseDouble(engineCtrl.text),
        'cost': parseDouble(costCtrl.text),
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
