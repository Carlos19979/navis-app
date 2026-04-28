import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class TripCompletionData {
  const TripCompletionData({
    this.arrivalPort,
    this.engineHours,
    this.fuelConsumedL,
    this.crewMembers,
    this.notes,
  });

  final String? arrivalPort;
  final double? engineHours;
  final double? fuelConsumedL;
  final List<String>? crewMembers;
  final String? notes;
}

class TripCompletionDialog extends StatefulWidget {
  const TripCompletionDialog({super.key});

  @override
  State<TripCompletionDialog> createState() => _TripCompletionDialogState();
}

class _TripCompletionDialogState extends State<TripCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _arrivalPortCtrl = TextEditingController();
  final _engineHoursCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _crewCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _arrivalPortCtrl.dispose();
    _engineHoursCtrl.dispose();
    _fuelCtrl.dispose();
    _crewCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete Trip'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _arrivalPortCtrl,
                decoration: const InputDecoration(
                  labelText: 'Arrival Port',
                  prefixIcon: Icon(Icons.anchor),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _engineHoursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Engine Hours',
                  prefixIcon: Icon(Icons.engineering),
                  suffixText: 'h',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fuelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fuel Used',
                  prefixIcon: Icon(Icons.local_gas_station),
                  suffixText: 'L',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _crewCtrl,
                decoration: const InputDecoration(
                  labelText: 'Crew Members',
                  prefixIcon: Icon(Icons.group),
                  hintText: 'Comma-separated names',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
          ),
          child: const Text('Save Trip'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final crew = _crewCtrl.text.trim().isEmpty
        ? null
        : _crewCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    final data = TripCompletionData(
      arrivalPort: _arrivalPortCtrl.text.trim().isEmpty
          ? null
          : _arrivalPortCtrl.text.trim(),
      engineHours: double.tryParse(_engineHoursCtrl.text),
      fuelConsumedL: double.tryParse(_fuelCtrl.text),
      crewMembers: crew,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    Navigator.of(context).pop(data);
  }
}
