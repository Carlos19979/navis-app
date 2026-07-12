import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Opens the expense-split sheet for one expense.
Future<void> showSplitSheet(
  BuildContext context,
  WidgetRef ref, {
  required String boatId,
  required String expenseId,
  required double amount,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.dialogSurface,
    builder: (_) => _SplitSheet(
      boatId: boatId,
      expenseId: expenseId,
      amount: amount,
      title: title,
    ),
  );
}

class _Person {
  _Person(this.userId, this.name);
  final String userId;
  final String name;
  final controller = TextEditingController();
  String? splitId;
  bool settled = false;
}

class _SplitSheet extends ConsumerStatefulWidget {
  const _SplitSheet({
    required this.boatId,
    required this.expenseId,
    required this.amount,
    required this.title,
  });

  final String boatId;
  final String expenseId;
  final double amount;
  final String title;

  @override
  ConsumerState<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends ConsumerState<_SplitSheet> {
  List<_Person> _people = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final p in _people) {
      p.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(sharedRepositoryProvider);
    try {
      final members = await ref.read(boatMembersProvider(widget.boatId).future);
      final existing = await repo.listSplits(widget.boatId, widget.expenseId);

      final myId = supabaseClient.auth.currentUser?.id;
      final people = <_Person>[
        if (myId != null) _Person(myId, l.bookingYou),
        for (final m in members) _Person(m.userId, m.name),
      ];
      // Seed from existing splits, else leave blank.
      for (final p in people) {
        final match = existing.where((s) => s.userId == p.userId);
        if (match.isNotEmpty) {
          final s = match.first;
          p.controller.text = s.shareAmount.toStringAsFixed(2);
          p.splitId = s.id;
          p.settled = s.settled;
        }
      }
      if (mounted) {
        setState(() {
          _people = people;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _splitEqually() {
    if (_people.isEmpty) return;
    final share = widget.amount / _people.length;
    setState(() {
      for (final p in _people) {
        p.controller.text = share.toStringAsFixed(2);
      }
    });
  }

  double get _assigned => _people.fold(
        0,
        (sum, p) => sum + (double.tryParse(p.controller.text.trim()) ?? 0),
      );

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final shares = <String, double>{};
    for (final p in _people) {
      final v = double.tryParse(p.controller.text.trim()) ?? 0;
      if (v > 0) shares[p.userId] = v;
    }
    try {
      await ref
          .read(sharedRepositoryProvider)
          .setSplits(widget.boatId, widget.expenseId, shares);
      ref.invalidate(expenseSplitsProvider(
          (boatId: widget.boatId, expenseId: widget.expenseId)));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        NavisSnackbar.error(context, l.somethingWentWrong);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final assigned = _assigned;
    final matches = (assigned - widget.amount).abs() < 0.01;

    return Padding(
      padding: EdgeInsets.only(
        left: Dimens.spaceLg,
        right: Dimens.spaceLg,
        top: Dimens.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Dimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.splitTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.title} · ${widget.amount.toStringAsFixed(0)} €',
            style: TextStyle(fontSize: 13, color: context.txtSecondary),
          ),
          const SizedBox(height: Dimens.spaceMd),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _splitEqually,
                icon: const Icon(Icons.balance, size: 18),
                label: Text(l.splitEqually),
              ),
            ),
            for (final p in _people) _personRow(p, l),
            const SizedBox(height: Dimens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.splitAssigned,
                    style: TextStyle(color: context.txtSecondary)),
                Text(
                  '${assigned.toStringAsFixed(0)} / ${widget.amount.toStringAsFixed(0)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: matches ? AppColors.green : AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceMd),
            NavisButton(
              label: l.save,
              isLoading: _busy,
              onPressed: _save,
            ),
          ],
        ],
      ),
    );
  }

  Widget _personRow(_Person p, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.name.isEmpty ? l.bookingCrew : p.name,
              style: TextStyle(color: context.txtPrimary),
            ),
          ),
          if (p.splitId != null)
            IconButton(
              tooltip: l.splitSettled,
              icon: Icon(
                p.settled ? Icons.check_circle : Icons.radio_button_unchecked,
                color: p.settled ? AppColors.green : context.txtSecondary,
                size: 20,
              ),
              onPressed: () async {
                final next = !p.settled;
                setState(() => p.settled = next);
                try {
                  await ref.read(sharedRepositoryProvider).settleSplit(
                      widget.boatId, widget.expenseId, p.splitId!, next);
                } catch (_) {
                  if (mounted) setState(() => p.settled = !next);
                }
              },
            ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: p.controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(suffixText: '€', isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}
