import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Pre-departure safety checklist.
///
/// Two modes:
/// - Regatta ([tripId] set): items are persisted; all must be checked to
///   complete the checklist and start recording the regatta's trip.
/// - Boat ([boatId] set, [tripId] null): a local, skippable checklist shown
///   before starting a solo trip recording. Items are not persisted.
class PreTripChecklistScreen extends ConsumerStatefulWidget {
  const PreTripChecklistScreen({
    this.tripId,
    this.groupId,
    this.boatId,
    super.key,
  }) : assert(tripId != null || boatId != null,
            'Either tripId (regatta) or boatId (solo trip) is required');

  final String? tripId;
  final String? groupId;
  final String? boatId;

  @override
  ConsumerState<PreTripChecklistScreen> createState() =>
      _PreTripChecklistScreenState();
}

class _PreTripChecklistScreenState
    extends ConsumerState<PreTripChecklistScreen> {
  static const _defaultSafetyItems = [
    'Chalecos salvavidas para toda la tripulación',
    'Bengalas y señales pirotécnicas en vigor',
    'Radio VHF operativa',
    'Nivel de combustible suficiente',
    'Bomba de achique funcionando',
    'Botiquín de primeros auxilios',
    'Ancla y cabos en buen estado',
    'Luces de navegación operativas',
    'Previsión meteorológica revisada',
    'Plan de navegación compartido en tierra',
  ];

  List<ChecklistItem>? _items;
  bool _busy = false;
  int _localCounter = 0;

  bool get _isLocal => widget.tripId == null;

  RegattaRepository get _repo => ref.read(regattaRepositoryProvider);

  bool get _allChecked =>
      _items != null && _items!.isNotEmpty && _items!.every((i) => i.isChecked);

  List<ChecklistItem> _defaultItems() {
    return [
      for (var i = 0; i < _defaultSafetyItems.length; i++)
        ChecklistItem(
          id: 'local-$i',
          label: _defaultSafetyItems[i],
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
      NavisSnackbar.error(context, 'No se pudo actualizar');
    }
  }

  Future<void> _addItem() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dialogSurface,
        title: Text('Añadir ítem', style: TextStyle(color: context.txtPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.txtPrimary),
          decoration: const InputDecoration(hintText: 'Descripción'),
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => context.pop(controller.text.trim()),
              child: const Text('Añadir')),
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
      NavisSnackbar.error(context, 'No se pudo añadir');
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
      NavisSnackbar.error(context, 'No se pudo eliminar');
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
      NavisSnackbar.error(context, 'No se pudo iniciar');
    }
  }

  /// Boat: no persistence — just go straight to recording (auto-start).
  void _startSoloTrip() {
    context.pushReplacement('/boats/${widget.boatId}/record?autostart=true');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: 'Checklist de seguridad',
        showBack: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: context.txtPrimary),
            tooltip: 'Añadir ítem',
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
      primaryLabel: 'Empezar viaje',
      gated: false,
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
        primaryLabel: 'Completar y zarpar',
        gated: true,
        onPrimary: _completeAndStart,
      ),
    );
  }

  Widget _content({
    required List<ChecklistItem> items,
    required String primaryLabel,
    required bool gated,
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
                        tooltip: 'Eliminar',
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
              if (gated && !_allChecked)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Marca todos los ítems de seguridad para zarpar.',
                    style: TextStyle(color: AppColors.amber, fontSize: 13),
                  ),
                ),
              NavisButton(
                label: primaryLabel,
                icon: Icons.sailing,
                isLoading: _busy,
                isDisabled: _busy || (gated && !_allChecked),
                onPressed: onPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
