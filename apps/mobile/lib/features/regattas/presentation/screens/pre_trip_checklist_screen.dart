import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
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

  bool get _isLocal => widget.tripId == null;

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
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dialogSurface,
        title: Text(l.addItem, style: TextStyle(color: context.txtPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.txtPrimary),
          decoration: InputDecoration(hintText: l.descriptionLabel),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(l.cancel)),
          TextButton(
              onPressed: () => context.pop(controller.text.trim()),
              child: Text(l.add)),
        ],
      ),
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
        '/boats/${regatta.boatId}/record'
        '?tripId=${widget.tripId}&regatta=true',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(context, AppLocalizations.of(context)!.couldNotStart);
    }
  }

  /// Boat: no persistence — just go straight to recording (auto-start).
  void _startSoloTrip() {
    final port = widget.departurePort;
    final portQuery = (port != null && port.isNotEmpty)
        ? '&port=${Uri.encodeComponent(port)}'
        : '';
    context.pushReplacement(
      '/boats/${widget.boatId}/record?autostart=true$portQuery',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: l.safetyChecklist,
        showBack: true,
        actions: [
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
                        activeColor: AppColors.green,
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
                    style:
                        const TextStyle(color: AppColors.amber, fontSize: 13),
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
