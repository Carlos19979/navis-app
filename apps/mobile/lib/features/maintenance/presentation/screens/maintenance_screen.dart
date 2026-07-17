import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/split_sheet.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
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
          actions: [
            IconButton(
              icon: const Icon(Icons.insights_rounded),
              tooltip: l.costTitle,
              onPressed: () async {
                if (!ref.read(isProProvider)) {
                  final ok = await showPaywall(context, ref,
                      reason: l.paywallReasonCostAnalytics);
                  if (!ok || !context.mounted) return;
                }
                if (context.mounted) {
                  unawaited(context.push('/boats/$boatId/costs'));
                }
              },
            ),
          ],
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
      MaintenanceStatus.overdue => (AppColors.red, Icons.error_rounded),
      MaintenanceStatus.dueSoon => (AppColors.amber, Icons.schedule_rounded),
      MaintenanceStatus.pending => (
          AppColors.amber,
          Icons.help_outline_rounded
        ),
      MaintenanceStatus.ok => (AppColors.green, Icons.check_circle_rounded),
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
  if (ref.read(isProProvider)) return 10;
  final limit = ref.read(accountProvider).valueOrNull?.attachmentLimit ?? 1;
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

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.boatId});
  final String boatId;

  bool _canEdit(WidgetRef ref) =>
      ref
          .watch(boatProvider(boatId))
          .valueOrNull
          ?.permissions
          .canManageMaintenance ??
      true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tasksAsync = ref.watch(maintenanceTasksProvider(boatId));
    final canEdit = _canEdit(ref);

    return Stack(
      children: [
        tasksAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
          error: (e, _) => NavisErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(maintenanceTasksProvider(boatId)),
          ),
          data: (tasks) {
            final logs =
                ref.watch(maintenanceLogsProvider(boatId)).valueOrNull ??
                    const <MaintenanceLog>[];
            final orphans = logs.where((x) => x.taskId == null).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _sectionHeader(context, l.maintenancePlanTitle),
                if (canEdit) _SuggestedChips(boatId: boatId, tasks: tasks),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(l.noMaintenanceTasks,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.txtSecondary)),
                  ),
                for (final t in tasks) _taskCard(context, ref, t, canEdit),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _sectionHeaderText(
                            context, l.maintenanceOtherTitle)),
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: l.recordService,
                        onPressed: () =>
                            _editMaintenance(context, ref, tasks: tasks),
                      ),
                  ],
                ),
                if (orphans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.maintenanceHistoryEmpty,
                        style: TextStyle(
                            color: context.txtSecondary, fontSize: 13)),
                  )
                else
                  for (final m in orphans)
                    _logCard(context, ref, m, canEdit, tasks),
              ],
            );
          },
        ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: NavisGradientFab(
              icon: Icons.add,
              tooltip: l.addTask,
              onPressed: () => _editTask(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _sectionHeaderText(context, text),
      );

  Widget _sectionHeaderText(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
            color: context.txtPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700),
      );

  Widget _taskCard(
      BuildContext context, WidgetRef ref, MaintenanceTask t, bool canEdit) {
    final l = AppLocalizations.of(context)!;
    final (color, _) = _taskVisuals(context, t.status);
    final subtitle = _taskSubtitle(l, t);
    return NavisCard(
      onTap: () => _taskDetail(context, ref, t, canEdit),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: context.txtSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_taskStatusLabel(l, t),
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _logCard(BuildContext context, WidgetRef ref, MaintenanceLog m,
      bool canEdit, List<MaintenanceTask> tasks) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      onTap: canEdit
          ? () => _editMaintenance(context, ref, existing: m, tasks: tasks)
          : null,
      child: Row(
        children: [
          const Icon(Icons.build, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.type,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600)),
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
                      const Icon(Icons.attach_file,
                          size: 14, color: AppColors.cyan),
                      const SizedBox(width: 2),
                      Text(l.invoiceLabel,
                          style: const TextStyle(
                              color: AppColors.cyan, fontSize: 12)),
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
            Text('${m.cost!.toStringAsFixed(0)} €',
                style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Future<void> _taskDetail(
      BuildContext context, WidgetRef ref, MaintenanceTask t, bool canEdit) {
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
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
                        child: Text(t.name,
                            style: TextStyle(
                                color: context.txtPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _editTask(context, ref, existing: t);
                          },
                        ),
                    ],
                  ),
                  if (_taskSubtitle(l, t).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_taskSubtitle(l, t),
                        style: TextStyle(
                            color: context.txtSecondary, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.maintenanceHistoryEmpty,
                          style: TextStyle(color: context.txtSecondary)),
                    )
                  else
                    for (final m in history)
                      _logCard(context, ref, m, canEdit, [t]),
                  const SizedBox(height: 12),
                  if (canEdit)
                    NavisButton(
                      label: l.recordService,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _editMaintenance(context, ref,
                            presetTaskId: t.id, tasks: [t]);
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

  Future<void> _editTask(BuildContext context, WidgetRef ref,
      {MaintenanceTask? existing}) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final monthsCtrl =
        TextEditingController(text: existing?.intervalMonths?.toString() ?? '');
    final hoursCtrl = TextEditingController(
        text: existing?.intervalHours?.toStringAsFixed(0) ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
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
              Text(existing == null ? l.addTask : l.editTask,
                  style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
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
                  child: Text(l.delete,
                      style: const TextStyle(color: AppColors.red)),
                ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    final body = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'interval_months': monthsCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(monthsCtrl.text.trim()),
      'interval_hours': hoursCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(hoursCtrl.text.trim()),
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

  Future<void> _editMaintenance(BuildContext context, WidgetRef ref,
      {MaintenanceLog? existing,
      String? presetTaskId,
      List<MaintenanceTask> tasks = const []}) async {
    final l = AppLocalizations.of(context)!;
    final typeCtrl = TextEditingController(text: existing?.type ?? '');
    final hoursCtrl =
        TextEditingController(text: existing?.engineHours?.toString() ?? '');
    final costCtrl =
        TextEditingController(text: existing?.cost?.toStringAsFixed(0) ?? '');
    final providerCtrl = TextEditingController(text: existing?.provider ?? '');
    var date = existing?.performedAt ?? DateTime.now();
    String? invoiceUrl = existing?.invoiceUrl;
    var photoUrls = List<String>.of(existing?.photoUrls ?? const []);
    // Only keep a selected task id that still exists in the list.
    final taskIds = tasks.map((t) => t.id).toSet();
    var selectedTaskId = existing?.taskId ?? presetTaskId;
    if (selectedTaskId != null && !taskIds.contains(selectedTaskId)) {
      selectedTaskId = null;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
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
                Text(existing == null ? l.recordService : l.edit,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (tasks.isNotEmpty) ...[
                  Text(l.taskField,
                      style:
                          TextStyle(color: context.txtSecondary, fontSize: 12)),
                  DropdownButton<String?>(
                    value: selectedTaskId,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String?>(
                        child: Text(l.noTaskOption),
                      ),
                      for (final t in tasks)
                        DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => selectedTaskId = v),
                  ),
                  const SizedBox(height: 10),
                ],
                NavisTextField(
                  controller: typeCtrl,
                  label: l.maintenanceTypeHint,
                ),
                const SizedBox(height: 10),
                NavisTextField(
                  controller: hoursCtrl,
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
                  onChanged: (u) => setState(() => photoUrls = u),
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
                          .deleteLog(boatId, existing.id);
                      ref.invalidate(maintenanceLogsProvider(boatId));
                      ref.invalidate(maintenanceTasksProvider(boatId));
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

    if (saved != true || typeCtrl.text.trim().isEmpty) return;
    final body = <String, dynamic>{
      'task_id': selectedTaskId,
      'type': typeCtrl.text.trim(),
      'performed_at': _isoDate(date),
      'engine_hours': hoursCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(hoursCtrl.text.trim()),
      'cost': costCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(costCtrl.text.trim()),
      'provider':
          providerCtrl.text.trim().isEmpty ? null : providerCtrl.text.trim(),
      'invoice_url': invoiceUrl,
      'photo_urls': photoUrls,
    };
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (existing == null) {
        await repo.addLog(boatId, body);
      } else {
        await repo.updateLog(boatId, existing.id, body);
      }
      ref.invalidate(maintenanceLogsProvider(boatId));
      ref.invalidate(maintenanceTasksProvider(boatId));
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, l.couldNotSave);
      }
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

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.boatId});
  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final expensesAsync = ref.watch(expensesProvider(boatId));
    final summaryAsync = ref.watch(expenseSummaryProvider(boatId));
    final splits =
        ref.watch(boatSplitSummaryProvider(boatId)).valueOrNull ?? const {};

    return Stack(
      children: [
        expensesAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
          error: (e, _) => NavisErrorWidget(
            message: e.toString(),
            onRetry: () {
              ref.invalidate(expensesProvider(boatId));
              ref.invalidate(expenseSummaryProvider(boatId));
            },
          ),
          data: (items) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (summaryAsync.valueOrNull case final s?)
                  NavisCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.totalSpent,
                            style: TextStyle(color: context.txtSecondary)),
                        const SizedBox(height: 4),
                        Text('${s.total.toStringAsFixed(0)} €',
                            style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final e in s.totals.entries)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_categoryLabel(l, e.key),
                                    style:
                                        TextStyle(color: context.txtSecondary)),
                                Text('${e.value.toStringAsFixed(0)} €',
                                    style:
                                        TextStyle(color: context.txtPrimary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: NavisEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: l.noExpensesRecorded,
                    ),
                  ),
                for (final e in items)
                  NavisCard(
                    onTap: (ref
                                .watch(boatProvider(boatId))
                                .valueOrNull
                                ?.permissions
                                .canManageExpenses ??
                            true)
                        ? () => _editExpense(context, ref, existing: e)
                        : null,
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
                                  style: TextStyle(
                                      color: context.txtSecondary,
                                      fontSize: 13)),
                              if (splits[e.id] case final s?) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.groups,
                                        size: 14,
                                        color: s.mySettled
                                            ? AppColors.green
                                            : AppColors.cyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.mySettled
                                          ? l.splitSettled
                                          : (s.myShare != null
                                              ? l.splitYouOwe(
                                                  s.myShare!.round())
                                              : l.splitSharedAmong(s.count)),
                                      style: TextStyle(
                                          color: s.mySettled
                                              ? AppColors.green
                                              : AppColors.cyan,
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
                                            color: AppColors.cyan,
                                            fontSize: 12)),
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
                            if (!ref.read(isProProvider)) {
                              final ok = await showPaywall(context, ref,
                                  reason: l.paywallReasonShared);
                              if (!ok || !context.mounted) return;
                            }
                            if (context.mounted) {
                              await showSplitSheet(
                                context,
                                ref,
                                boatId: boatId,
                                expenseId: e.id,
                                amount: e.amount,
                                title: _categoryLabel(l, e.category),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (ref
                .watch(boatProvider(boatId))
                .valueOrNull
                ?.permissions
                .canManageExpenses ??
            true)
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

  Future<void> _editExpense(BuildContext context, WidgetRef ref,
      {Expense? existing}) async {
    final l = AppLocalizations.of(context)!;
    var category = existing?.category ?? '';
    final amountCtrl =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
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
                ),
                const SizedBox(height: 10),
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
    final body = <String, dynamic>{
      'category': category,
      'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
      'incurred_on': _isoDate(date),
      'invoice_url': invoiceUrl,
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
