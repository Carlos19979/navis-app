import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _departurePortController = TextEditingController();
  final _arrivalPortController = TextEditingController();
  final _engineHoursController = TextEditingController();
  final _fuelController = TextEditingController();
  final _crewController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final trip =
        await ref.read(tripProvider(widget.tripId).future);
    _departurePortController.text = trip.departurePort;
    _arrivalPortController.text = trip.arrivalPort ?? '';
    _engineHoursController.text =
        trip.engineHours?.toStringAsFixed(1) ?? '';
    _fuelController.text =
        trip.fuelConsumedL?.toStringAsFixed(1) ?? '';
    _crewController.text = trip.crewMembers?.join(', ') ?? '';
    _notesController.text = trip.notes ?? '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _departurePortController.dispose();
    _arrivalPortController.dispose();
    _engineHoursController.dispose();
    _fuelController.dispose();
    _crewController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trip =
          await ref.read(tripProvider(widget.tripId).future);
      final crewText = _crewController.text.trim();
      final crewList = crewText.isEmpty
          ? <String>[]
          : crewText.split(',').map((s) => s.trim()).toList();

      final updated = trip.copyWith(
        departurePort: _departurePortController.text.trim(),
        arrivalPort: _arrivalPortController.text.trim().isEmpty
            ? null
            : _arrivalPortController.text.trim(),
        engineHours:
            double.tryParse(_engineHoursController.text.trim()),
        fuelConsumedL:
            double.tryParse(_fuelController.text.trim()),
        crewMembers: crewList.isEmpty ? null : crewList,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final repo = ref.read(tripRepositoryProvider);
      await repo.updateTrip(updated);
      ref.invalidate(tripProvider(widget.tripId));
      ref.invalidate(boatTripsProvider(trip.boatId));

      if (mounted) {
        NavisSnackbar.success(context, 'Trip updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(context, 'Failed to update trip');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: NavisLoading(),
        ),
      );
    }

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const NavisAppBar(
          title: 'Edit Trip',
          showBack: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavisCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _departurePortController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Departure Port',
                          prefixIcon: Icon(Icons.flight_takeoff),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Please enter the departure port';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _arrivalPortController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Arrival Port (optional)',
                          prefixIcon: Icon(Icons.flight_land),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NavisCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _engineHoursController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Engine Hours (optional)',
                          prefixIcon: Icon(Icons.engineering),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value.trim()) ==
                                null) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fuelController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Used (liters, optional)',
                          prefixIcon: Icon(Icons.local_gas_station),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value.trim()) ==
                                null) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NavisCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _crewController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText:
                              'Crew Members (comma-separated)',
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: Icon(Icons.notes),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                NavisButton(
                  label: 'Update Trip',
                  onPressed: _onSave,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
