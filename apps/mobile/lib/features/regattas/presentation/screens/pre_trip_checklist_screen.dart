import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/config/checklist_preference.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Pre-departure safety checklist.
///
/// In both modes the checklist is optional — the crew can set sail without
/// ticking every item (a safety hint is shown when items remain). It is a
/// recommendation, not a hard gate.
///
/// Two modes:
/// - Regatta ([tripId] set): items are persisted to the trip. Starting marks
///   the checklist as acknowledged and begins recording the regatta's trip.
/// - Boat ([boatId] set, [tripId] null): a local checklist shown before
///   starting a solo trip recording. Items are not persisted.
///
/// In boat mode this screen is also the gate for starting a trip: it is the
/// single entry point every caller uses (`/boats/:id/precheck`), so it is where
/// [PreTripChecklistMode] is honoured. Before build 5 the checklist was
/// mandatory on every trip; now it either asks once ("Review checklist" /
/// "Skip"), opens straight away, or steps aside, depending on the remembered
/// choice. The choice can be reset from Settings.
class PreTripChecklistScreen extends ConsumerStatefulWidget {
  const PreTripChecklistScreen({
    this.tripId,
    this.groupId,
    this.boatId,
    this.departurePort,
    super.key,
  }) : assert(tripId != null || boatId != null,
            'Either tripId (regatta) or boatId (solo trip) is required');

  final String? tripId;
  final String? groupId;
  final String? boatId;

  /// Optional pre-selected departure port, carried into the recording screen
  /// (e.g. when starting a regatta from an event).
  final String? departurePort;

  @override
  ConsumerState<PreTripChecklistScreen> createState() =>
      _PreTripChecklistScreenState();
}

class _PreTripChecklistScreenState
    extends ConsumerState<PreTripChecklistScreen> {
  List<ChecklistItem>? _items;
  bool _busy = false;
  int _localCounter = 0;

  /// Boat mode only: whether the checklist itself may be shown. Until the
  /// remembered choice is read (and the prompt answered) the body stays empty,
  /// so someone who skips never sees the list flash by.
  bool _checklistOpen = false;

  bool get _isLocal => widget.tripId == null;

  @override
  void initState() {
    super.initState();
    if (_isLocal) {
      // Needs a frame: it reads localizations and may show a dialog.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLocalChecklist();
      });
    }
  }

  /// Applies the remembered [PreTripChecklistMode] on entering the boat-mode
  /// screen: open the checklist, skip to recording, or ask.
  Future<void> _openLocalChecklist() async {
    switch (ref.read(preTripChecklistModeProvider)) {
      case PreTripChecklistMode.review:
        setState(() => _checklistOpen = true);
      case PreTripChecklistMode.skip:
        _startSoloTrip();
      case PreTripChecklistMode.ask:
        final answer = await _askAboutChecklist();
        if (!mounted) return;
        if (answer == null) {
          // Dismissed: they did not decide to sail, so do not start a trip.
          if (context.canPop()) context.pop();
          return;
        }
        if (answer.remember) {
          ref.read(preTripChecklistModeProvider.notifier).set(
                answer.review
                    ? PreTripChecklistMode.review
                    : PreTripChecklistMode.skip,
              );
        }
        if (answer.review) {
          setState(() => _checklistOpen = true);
        } else {
          _startSoloTrip();
        }
    }
  }

  Future<({bool review, bool remember})?> _askAboutChecklist() {
    return showDialog<({bool review, bool remember})>(
      context: context,
      builder: (_) => const _ChecklistPromptDialog(),
    );
  }

  RegattaRepository get _repo => ref.read(regattaRepositoryProvider);

  bool get _allChecked =>
      _items != null && _items!.isNotEmpty && _items!.every((i) => i.isChecked);

  List<ChecklistItem> _defaultItems() {
    final l = AppLocalizations.of(context)!;
    final labels = [
      l.checklistLifejackets,
      l.checklistFlares,
      l.checklistVhf,
      l.checklistFuel,
      l.checklistBilgePump,
      l.checklistFirstAid,
      l.checklistAnchor,
      l.checklistNavLights,
      l.checklistWeather,
      l.checklistFloatPlan,
    ];
    return [
      for (var i = 0; i < labels.length; i++)
        ChecklistItem(
          id: 'local-$i',
          label: labels[i],
          isChecked: false,
          position: i,
        ),
    ];
  }

  Future<void> _toggle(ChecklistItem item, bool value) async {
    setState(() {
      _items = _items!
          .map((i) => i.id == item.id ? i.copyWith(isChecked: value) : i)
          .toList();
    });
    if (_isLocal) return;
    try {
      await _repo.setChecklistItem(widget.tripId!, item.id, value);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _items!
            .map((i) => i.id == item.id ? i.copyWith(isChecked: !value) : i)
            .toList();
      });
      NavisSnackbar.error(
          context, AppLocalizations.of(context)!.couldNotUpdate);
    }
  }

  Future<void> _addItem() async {
    final l = AppLocalizations.of(context)!;
    final label = await NavisInputDialog.show(
      context,
      title: l.addItem,
      hintText: l.descriptionLabel,
      confirmLabel: l.add,
    );
    if (label == null || label.isEmpty) return;
    if (_isLocal) {
      setState(() => _items = [
            ...?_items,
            ChecklistItem(
              id: 'local-new-${_localCounter++}',
              label: label,
              isChecked: false,
              position: (_items?.length ?? 0),
            ),
          ]);
      return;
    }
    try {
      final item = await _repo.addChecklistItem(widget.tripId!, label);
      setState(() => _items = [...?_items, item]);
    } catch (_) {
      if (!mounted) return;
      NavisSnackbar.error(context, AppLocalizations.of(context)!.couldNotAdd);
    }
  }

  Future<void> _remove(ChecklistItem item) async {
    final prev = _items;
    setState(() => _items = _items!.where((i) => i.id != item.id).toList());
    if (_isLocal) return;
    try {
      await _repo.removeChecklistItem(widget.tripId!, item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = prev);
      NavisSnackbar.error(
          context, AppLocalizations.of(context)!.couldNotDelete);
    }
  }

  /// Regatta: persist + start the planned trip, then open recording.
  Future<void> _completeAndStart() async {
    setState(() => _busy = true);
    try {
      await _repo.completeChecklist(widget.tripId!);
      final regatta = await _repo.start(widget.tripId!);
      if (widget.groupId != null) {
        ref.invalidate(groupRegattasProvider(widget.groupId!));
      }
      ref.invalidate(regattaProvider(widget.tripId!));
      if (!mounted) return;
      context.pushReplacement(
        Routes.boatRecord(
          regatta.boatId,
          tripId: widget.tripId,
          regatta: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(context, AppLocalizations.of(context)!.couldNotStart);
    }
  }

  /// Boat: no persistence — just go straight to recording (auto-start).
  void _startSoloTrip() {
    context.pushReplacement(
      Routes.boatRecord(
        widget.boatId!,
        autostart: true,
        port: widget.departurePort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(
        title: l.safetyChecklist,
        showBack: true,
        actions: [
          if (!_isLocal || _checklistOpen)
            IconButton(
              icon: Icon(Icons.add, color: context.txtPrimary),
              tooltip: l.addItem,
              onPressed: _addItem,
            ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(child: _isLocal ? _buildLocal() : _buildRegatta()),
      ),
    );
  }

  Widget _buildLocal() {
    // Waiting on the remembered choice / the prompt: nothing to show yet.
    if (!_checklistOpen) return const SizedBox.shrink();
    _items ??= _defaultItems();
    return _content(
      items: _items!,
      primaryLabel: AppLocalizations.of(context)!.startTrip,
      showSkipHint: false,
      onPrimary: _startSoloTrip,
    );
  }

  Widget _buildRegatta() {
    final async = ref.watch(regattaChecklistProvider(widget.tripId!));
    if (_items == null && async.hasValue) {
      _items = List.of(async.value!);
    }
    return async.when(
      loading: () => const NavisLoading(),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(regattaChecklistProvider(widget.tripId!)),
      ),
      data: (_) => _content(
        items: _items ?? const <ChecklistItem>[],
        primaryLabel: _allChecked
            ? AppLocalizations.of(context)!.completeAndSail
            : AppLocalizations.of(context)!.sailAnyway,
        showSkipHint: !_allChecked,
        onPrimary: _completeAndStart,
      ),
    );
  }

  Widget _content({
    required List<ChecklistItem> items,
    required String primaryLabel,
    required bool showSkipHint,
    required VoidCallback onPrimary,
  }) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              for (final item in items)
                NavisCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.isChecked,
                        activeColor: context.positive,
                        onChanged: (v) => _toggle(item, v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: item.isChecked
                                ? context.txtSecondary
                                : context.txtPrimary,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: context.txtSecondary),
                        tooltip: AppLocalizations.of(context)!.delete,
                        onPressed: () => _remove(item),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            children: [
              if (showSkipHint)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppLocalizations.of(context)!.checklistSkipHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.caution, fontSize: 13),
                  ),
                ),
              NavisButton(
                label: primaryLabel,
                icon: Icons.sailing,
                isLoading: _busy,
                isDisabled: _busy,
                onPressed: onPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asked once when a trip starts: review the safety checklist or skip it.
///
/// Returns `(review, remember)`, or null when dismissed. [remember] persists
/// the answer as the new [PreTripChecklistMode] so the question is not repeated
/// on every trip.
class _ChecklistPromptDialog extends StatefulWidget {
  const _ChecklistPromptDialog();

  @override
  State<_ChecklistPromptDialog> createState() => _ChecklistPromptDialogState();
}

class _ChecklistPromptDialogState extends State<_ChecklistPromptDialog> {
  bool _remember = false;

  void _answer({required bool review}) {
    Navigator.of(context).pop((review: review, remember: _remember));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: context.dialogSurface,
      title:
          Text(l.safetyChecklist, style: TextStyle(color: context.txtPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.checklistPromptQuestion,
            style: TextStyle(color: context.txtSecondary),
          ),
          const SizedBox(height: Dimens.spaceSm),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            activeColor: context.accent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l.rememberMyChoice,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _answer(review: false),
          child: Text(l.skipChecklist),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.accent),
          onPressed: () => _answer(review: true),
          child: Text(l.reviewChecklist),
        ),
      ],
    );
  }
}
