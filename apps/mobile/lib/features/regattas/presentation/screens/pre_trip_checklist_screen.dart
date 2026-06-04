import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
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

/// Mandatory pre-departure safety checklist. When all items are checked the
/// skipper can complete the checklist and start recording the trip/regatta.
class PreTripChecklistScreen extends ConsumerStatefulWidget {
  const PreTripChecklistScreen({
    required this.tripId,
    this.groupId,
    super.key,
  });

  final String tripId;
  final String? groupId;

  @override
  ConsumerState<PreTripChecklistScreen> createState() =>
      _PreTripChecklistScreenState();
}

class _PreTripChecklistScreenState
    extends ConsumerState<PreTripChecklistScreen> {
  List<ChecklistItem>? _items;
  bool _busy = false;

  RegattaRepository get _repo => ref.read(regattaRepositoryProvider);

  bool get _allChecked =>
      _items != null && _items!.isNotEmpty && _items!.every((i) => i.isChecked);

  Future<void> _toggle(ChecklistItem item, bool value) async {
    setState(() {
      _items = _items!
          .map((i) => i.id == item.id ? i.copyWith(isChecked: value) : i)
          .toList();
    });
    try {
      await _repo.setChecklistItem(widget.tripId, item.id, value);
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
        backgroundColor: AppColors.darkSurface,
        title: const Text('Añadir ítem',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
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
    try {
      final item = await _repo.addChecklistItem(widget.tripId, label);
      setState(() => _items = [...?_items, item]);
    } catch (_) {
      if (!mounted) return;
      NavisSnackbar.error(context, 'No se pudo añadir');
    }
  }

  Future<void> _remove(ChecklistItem item) async {
    final prev = _items;
    setState(() => _items = _items!.where((i) => i.id != item.id).toList());
    try {
      await _repo.removeChecklistItem(widget.tripId, item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = prev);
      NavisSnackbar.error(context, 'No se pudo eliminar');
    }
  }

  Future<void> _completeAndStart() async {
    setState(() => _busy = true);
    try {
      await _repo.completeChecklist(widget.tripId);
      await _repo.start(widget.tripId);
      if (widget.groupId != null) {
        ref.invalidate(groupRegattasProvider(widget.groupId!));
      }
      ref.invalidate(regattaProvider(widget.tripId));
      if (!mounted) return;
      NavisSnackbar.success(context, '¡Buen viaje! Grabación iniciada');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(context, 'No se pudo iniciar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(regattaChecklistProvider(widget.tripId));

    // Seed local state from the provider the first time it loads.
    if (_items == null && async.hasValue) {
      _items = List.of(async.value!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: 'Checklist de seguridad',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.textPrimary),
            tooltip: 'Añadir ítem',
            onPressed: _addItem,
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: async.when(
            loading: () => const NavisLoading(),
            error: (e, _) => NavisErrorWidget(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(regattaChecklistProvider(widget.tripId)),
            ),
            data: (_) {
              final items = _items ?? const <ChecklistItem>[];
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
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppColors.textSecondary),
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
                        if (!_allChecked)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Marca todos los ítems de seguridad para zarpar.',
                              style: TextStyle(
                                  color: AppColors.amber, fontSize: 13),
                            ),
                          ),
                        NavisButton(
                          label: 'Completar y zarpar',
                          icon: Icons.sailing,
                          isLoading: _busy,
                          isDisabled: _busy || !_allChecked,
                          onPressed: _completeAndStart,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
