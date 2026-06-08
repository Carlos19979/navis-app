import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/widgets/departure_port_picker.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class ScheduleRegattaScreen extends ConsumerStatefulWidget {
  const ScheduleRegattaScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ScheduleRegattaScreen> createState() =>
      _ScheduleRegattaScreenState();
}

class _ScheduleRegattaScreenState extends ConsumerState<ScheduleRegattaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _boatId;
  String? _departurePort;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Boat? _boatById(List<Boat> boats) {
    for (final b in boats) {
      if (b.id == _boatId) return b;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (!mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_boatId == null) {
      NavisSnackbar.error(context, 'Selecciona un barco');
      return;
    }
    if (_departurePort == null || _departurePort!.isEmpty) {
      NavisSnackbar.error(context, 'Selecciona el puerto de salida');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(regattaRepositoryProvider).schedule(
            groupId: widget.groupId,
            boatId: _boatId!,
            departurePort: _departurePort!,
            title: _titleController.text.trim(),
            scheduledAt: _scheduledAt,
          );
      ref.invalidate(groupRegattasProvider(widget.groupId));
      if (!mounted) return;
      NavisSnackbar.success(context, 'Regata programada');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NavisSnackbar.error(context, 'No se pudo programar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final boatsAsync = ref.watch(boatsProvider);
    final boats = boatsAsync.valueOrNull ?? const <Boat>[];
    final selectedBoat = _boatById(boats);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const NavisAppBar(title: 'Programar regata', showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _field(_titleController, 'Título (p. ej. Regata de primavera)'),
                const SizedBox(height: 20),
                const _Label('Barco'),
                const SizedBox(height: 8),
                boatsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.cyan)),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: AppColors.red)),
                  data: (boats) => Column(
                    children: boats
                        .map((b) => NavisCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              borderColor:
                                  _boatId == b.id ? AppColors.cyan : null,
                              onTap: () => setState(() {
                                _boatId = b.id;
                                _departurePort = null;
                              }),
                              child: Row(
                                children: [
                                  const Icon(Icons.sailing,
                                      color: AppColors.cyan),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(b.name,
                                        style: TextStyle(
                                            color: context.txtPrimary)),
                                  ),
                                  if (_boatId == b.id)
                                    const Icon(Icons.check_circle,
                                        color: AppColors.cyan, size: 20),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const _Label('Puerto de salida'),
                const SizedBox(height: 8),
                if (selectedBoat == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Selecciona un barco primero.',
                        style: TextStyle(color: context.txtSecondary)),
                  )
                else
                  DeparturePortPicker(
                    key: ValueKey(selectedBoat.id),
                    boat: selectedBoat,
                    onChanged: (name) => setState(() => _departurePort = name),
                  ),
                const SizedBox(height: 20),
                NavisCard(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: AppColors.cyan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fecha: ${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year} '
                          '${_scheduledAt.hour.toString().padLeft(2, '0')}:'
                          '${_scheduledAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: context.txtPrimary),
                        ),
                      ),
                      Icon(Icons.edit, color: context.txtSecondary, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                NavisButton(
                  label: 'Programar regata',
                  isLoading: _saving,
                  isDisabled: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: context.txtPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.txtSecondary),
        filled: true,
        fillColor: context.glassBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.glassBorderColor, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600),
    );
  }
}
