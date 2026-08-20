import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/features/maintenance/presentation/maintenance_format.dart';
import 'package:navis_mobile/features/maintenance/presentation/widgets/invoice_field.dart';

import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/split_sheet.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/core/utils/money_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
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
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

/// The boat's expense ledger.
///
/// The second half of the old maintenance-and-expenses screen, now at
/// `/boats/:id/expenses`. Splitting it also gave cost intelligence somewhere
/// honest to send «see the expenses» to.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key, required this.boatId});

  final String boatId;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
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

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.expensesTab,
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.build_outlined),
              tooltip: l.maintenanceTab,
              onPressed: () => context.push(Routes.boatMaintenance(boatId)),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: expensesAsync.when(
            loading: () => const NavisShimmer(itemCount: 4, itemHeight: 84),
            error: (e, _) => NavisErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(expensesProvider(boatId)),
            ),
            data: (items) => _content(context, l, items, splits, canManage),
          ),
        ),
        floatingActionButton: canManage
            ? NavisGradientFab(
                icon: Icons.add,
                tooltip: l.newExpense,
                onPressed: () => _editExpense(context, ref),
              )
            : null,
      ),
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
            label: Text(categoryLabel(l, c)),
            selected: _category == c,
            onSelected: (sel) => setState(() => _category = sel ? c : null),
          ),
      ],
    );
  }

  Widget _periodTotal(BuildContext context, AppLocalizations l, double total) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.expensesPeriodTotal.toUpperCase(),
          style: NavisType.overline.copyWith(color: context.inkMuted),
        ),
        const SizedBox(height: Dimens.spaceXs),
        // Through Money: the ledger printed «1420 €» by hand, so it lost the
        // thousands separator and put the symbol on the wrong side of the
        // number in every locale that leads with it.
        Text(
          Money.format(locale, total),
          style: NavisType.numeral.copyWith(color: context.ink),
        ),
      ],
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    return [
      NavisList(
        padding: EdgeInsets.zero,
        children: [
          for (final m in months)
            NavisRow(
              title: expenseMonthName(context, _period.year, m),
              value: Money.format(locale, byMonth[m]!),
              onTap: () => setState(() => _period = _period.withMonth(m)),
            ),
        ],
      ),
    ];
  }

  /// One entry in the ledger.
  ///
  /// A row with a hairline under it instead of a filled card: a month of
  /// expenses was thirty framed boxes, and the amount — the thing being read —
  /// carried the same weight as the frame around it.
  Widget _expenseCard(
    BuildContext context,
    AppLocalizations l,
    Expense e,
    Map<String, ExpenseSplitSummary> splits,
    bool canManage,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final split = splits[e.id];

    final meta = <String>[
      NavisDateUtils.formatDateShort(e.incurredOn),
      if (e.liters != null)
        l.expenseLitersSummary(
          Measure.decimal(
            locale,
            e.liters!,
            digits: e.liters! % 1 == 0 ? 0 : 1,
          ),
          // Number only: the string already ends in «€/L». Third time this
          // trap has bitten in this redesign — «0,8 m m», «142 NM NM», and
          // now «1,66 € €/L».
          Measure.decimal(
            locale,
            e.pricePerLiter ?? (e.amount / e.liters!),
            digits: 2,
          ),
        ),
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: InkWell(
        onTap: canManage ? () => _editExpense(context, ref, existing: e) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel(l, e.category),
                      style: NavisType.title3.copyWith(color: context.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: NavisType.caption.copyWith(
                        color: context.inkMuted,
                      ),
                    ),
                    if (split != null || e.invoiceUrl != null) ...[
                      const SizedBox(height: Dimens.spaceXs),
                      Row(
                        children: [
                          if (split != null) ...[
                            Icon(
                              Icons.groups_rounded,
                              size: Dimens.iconSm,
                              color: split.mySettled
                                  ? context.positive
                                  : context.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              split.mySettled
                                  ? l.splitSettled
                                  : (split.myShare != null
                                      ? l.splitYouOwe(split.myShare!.round())
                                      : l.splitSharedAmong(split.count)),
                              style: NavisType.caption.copyWith(
                                color: split.mySettled
                                    ? context.positive
                                    : context.inkMuted,
                              ),
                            ),
                            const SizedBox(width: Dimens.spaceMd),
                          ],
                          if (e.invoiceUrl != null) ...[
                            Icon(
                              Icons.attach_file_rounded,
                              size: Dimens.iconSm,
                              color: context.inkMuted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              l.invoiceLabel,
                              style: NavisType.caption.copyWith(
                                color: context.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Dimens.spaceMd),
              Text(
                Money.format(locale, e.amount),
                style: NavisType.title2.copyWith(color: context.ink),
              ),
              IconButton(
                icon: Icon(
                  Icons.groups_outlined,
                  size: Dimens.iconMd,
                  color: context.inkMuted,
                ),
                tooltip: l.splitTitle,
                onPressed: () async {
                  // Splitting is available on every tier (viral hook) — no
                  // paywall here.
                  await showSplitSheet(
                    context,
                    ref,
                    boatId: boatId,
                    expenseId: e.id,
                    amount: e.amount,
                    title: categoryLabel(l, e.category),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editExpense(BuildContext context, WidgetRef ref,
      {Expense? existing}) async {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
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
                        label: Text(categoryLabel(l, c)),
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
                        l.pricePerLiterValue(
                          Measure.decimal(locale, a / li, digits: 2),
                        ),
                        style: NavisType.label.copyWith(
                          color: context.inkMuted,
                        ),
                      ),
                    );
                  }),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.dateWithValue(fmtDate(date)),
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
                InvoiceField(
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
      'incurred_on': isoDate(date),
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
