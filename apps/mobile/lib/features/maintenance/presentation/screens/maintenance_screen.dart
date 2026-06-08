import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const NavisAppBar(
          title: 'Mantenimiento y gastos',
          showBack: true,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Mantenimiento'),
              Tab(text: 'Gastos'),
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
              return const NavisEmptyState(
                icon: Icons.build_outlined,
                message: 'Sin registros de mantenimiento',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final m = logs[i];
                return NavisCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.build, color: AppColors.cyan),
                    title: Text(m.type,
                        style: TextStyle(color: context.txtPrimary)),
                    subtitle: Text(
                      [
                        _fmtDate(m.performedAt),
                        if (m.engineHours != null) '${m.engineHours} h',
                        if (m.provider != null) m.provider!,
                      ].join(' · '),
                      style: TextStyle(color: context.txtSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.cost != null)
                          Text('${m.cost!.toStringAsFixed(0)} €',
                              style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700)),
                        if (ref
                                .watch(boatProvider(boatId))
                                .valueOrNull
                                ?.isOwner ??
                            true)
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: context.txtSecondary),
                            onPressed: () async {
                              await ref
                                  .read(maintenanceRepositoryProvider)
                                  .deleteLog(boatId, m.id);
                              ref.invalidate(maintenanceLogsProvider(boatId));
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (ref.watch(boatProvider(boatId)).valueOrNull?.isOwner ?? true)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.cyanGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () => _addMaintenance(context, ref),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addMaintenance(BuildContext context, WidgetRef ref) async {
    final typeCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    var date = DateTime.now();

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
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuevo mantenimiento',
                  style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tipo (ej. cambio de aceite)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Horas de motor (opc.)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Coste € (opc.)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: providerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Proveedor (opc.)'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fecha: ${_fmtDate(date)}',
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
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.cyan),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || typeCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(maintenanceRepositoryProvider).addLog(boatId, {
        'type': typeCtrl.text.trim(),
        'performed_at': _isoDate(date),
        if (hoursCtrl.text.trim().isNotEmpty)
          'engine_hours': double.tryParse(hoursCtrl.text.trim()),
        if (costCtrl.text.trim().isNotEmpty)
          'cost': double.tryParse(costCtrl.text.trim()),
        if (providerCtrl.text.trim().isNotEmpty)
          'provider': providerCtrl.text.trim(),
      });
      ref.invalidate(maintenanceLogsProvider(boatId));
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, 'No se pudo guardar');
      }
    }
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.boatId});
  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(boatId));
    final summaryAsync = ref.watch(expenseSummaryProvider(boatId));

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
                        Text('Total gastado',
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
                                Text(e.key,
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
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: NavisEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Sin gastos registrados',
                    ),
                  ),
                for (final e in items)
                  NavisCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.euro, color: AppColors.cyan),
                      title: Text(e.category,
                          style: TextStyle(color: context.txtPrimary)),
                      subtitle: Text(_fmtDate(e.incurredOn),
                          style: TextStyle(color: context.txtSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${e.amount.toStringAsFixed(0)} €',
                              style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700)),
                          if (ref
                                  .watch(boatProvider(boatId))
                                  .valueOrNull
                                  ?.isOwner ??
                              true)
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: context.txtSecondary),
                              onPressed: () async {
                                await ref
                                    .read(maintenanceRepositoryProvider)
                                    .deleteExpense(boatId, e.id);
                                ref.invalidate(expensesProvider(boatId));
                                ref.invalidate(expenseSummaryProvider(boatId));
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (ref.watch(boatProvider(boatId)).valueOrNull?.isOwner ?? true)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.cyanGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () => _addExpense(context, ref),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final categoryCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var date = DateTime.now();
    const categories = [
      'combustible',
      'amarre',
      'seguro',
      'reparación',
      'limpieza',
      'otros'
    ];

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
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuevo gasto',
                  style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: categoryCtrl.text == c,
                      onSelected: (_) => setState(() => categoryCtrl.text = c),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Importe €'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fecha: ${_fmtDate(date)}',
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
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.cyan),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true ||
        categoryCtrl.text.trim().isEmpty ||
        amountCtrl.text.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(maintenanceRepositoryProvider).addExpense(boatId, {
        'category': categoryCtrl.text.trim(),
        'amount': double.tryParse(amountCtrl.text.trim()) ?? 0,
        'incurred_on': _isoDate(date),
      });
      ref.invalidate(expensesProvider(boatId));
      ref.invalidate(expenseSummaryProvider(boatId));
    } catch (_) {
      if (context.mounted) {
        NavisSnackbar.error(context, 'No se pudo guardar');
      }
    }
  }
}
