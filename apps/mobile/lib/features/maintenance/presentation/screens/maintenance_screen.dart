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
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
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

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.boatId});
  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final logsAsync = ref.watch(maintenanceLogsProvider(boatId));
    return Stack(
      children: [
        logsAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
          error: (e, _) => NavisErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(maintenanceLogsProvider(boatId)),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return NavisEmptyState(
                icon: Icons.build_outlined,
                message: l.noMaintenanceRecords,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final m = logs[i];
                final canEdit = ref
                        .watch(boatProvider(boatId))
                        .valueOrNull
                        ?.permissions
                        .canManageMaintenance ??
                    true;
                return NavisCard(
                  onTap: canEdit
                      ? () => _editMaintenance(context, ref, existing: m)
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
                              style: TextStyle(
                                  color: context.txtSecondary, fontSize: 13),
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
              },
            );
          },
        ),
        if (ref
                .watch(boatProvider(boatId))
                .valueOrNull
                ?.permissions
                .canManageMaintenance ??
            true)
          Positioned(
            right: 16,
            bottom: 16,
            child: NavisGradientFab(
              icon: Icons.add,
              tooltip: l.newMaintenance,
              onPressed: () => _editMaintenance(context, ref),
            ),
          ),
      ],
    );
  }

  Future<void> _editMaintenance(BuildContext context, WidgetRef ref,
      {MaintenanceLog? existing}) async {
    final l = AppLocalizations.of(context)!;
    final typeCtrl = TextEditingController(text: existing?.type ?? '');
    final hoursCtrl =
        TextEditingController(text: existing?.engineHours?.toString() ?? '');
    final costCtrl =
        TextEditingController(text: existing?.cost?.toStringAsFixed(0) ?? '');
    final providerCtrl = TextEditingController(text: existing?.provider ?? '');
    var date = existing?.performedAt ?? DateTime.now();
    String? invoiceUrl = existing?.invoiceUrl;

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
                Text(existing == null ? l.newMaintenance : l.edit,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
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
    };
    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (existing == null) {
        await repo.addLog(boatId, body);
      } else {
        await repo.updateLog(boatId, existing.id, body);
      }
      ref.invalidate(maintenanceLogsProvider(boatId));
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, l.couldNotSave);
      }
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
