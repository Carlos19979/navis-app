import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

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
  const TripCompletionDialog({
    super.key,
    this.distanceNm,
    this.duration,
    this.avgSpeed,
  });

  final double? distanceNm;
  final Duration? duration;
  final double? avgSpeed;

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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: AppColors.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Complete Trip',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
                if (widget.distanceNm != null ||
                    widget.duration != null ||
                    widget.avgSpeed != null) ...[
                  const SizedBox(height: 16),
                  _buildSummaryPills(),
                ],
                const SizedBox(height: 20),
                Form(
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
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) {
                            return 'Enter a valid number';
                          }
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
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) {
                            return 'Enter a valid number';
                          }
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NavisButton(
                        label: 'Cancel',
                        variant: NavisButtonVariant.secondary,
                        compact: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NavisButton(
                        label: 'Save Trip',
                        icon: Icons.check,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPills() {
    return Row(
      children: [
        if (widget.distanceNm != null)
          _SummaryPill(
            icon: Icons.straighten,
            value: '${widget.distanceNm!.toStringAsFixed(1)} NM',
          ),
        if (widget.duration != null)
          _SummaryPill(
            icon: Icons.schedule,
            value:
                '${widget.duration!.inHours}h ${widget.duration!.inMinutes % 60}m',
          ),
        if (widget.avgSpeed != null)
          _SummaryPill(
            icon: Icons.speed,
            value: '${widget.avgSpeed!.toStringAsFixed(1)} kn',
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
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    Navigator.of(context).pop(data);
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.cyan),
            const SizedBox(width: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
