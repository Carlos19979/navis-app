import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/crew_chips_field.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
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
  final _notesController = TextEditingController();
  List<String> _crew = [];
  final List<String> _crewSuggestions = const [];
  bool _isLoading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  /// A number as the user would type it: «3», not «3.0»; «3.5» stays «3.5».
  static String _editable(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  Future<void> _loadTrip() async {
    final trip = await ref.read(tripProvider(widget.tripId).future);
    _departurePortController.text = trip.departurePort;
    _arrivalPortController.text = trip.arrivalPort ?? '';
    // Seeded for *editing*, so the decimal point stays (that is what
    // `double.parse` reads) but a whole number is not padded to «3.0» — the
    // form should hand back what the user typed, not a formatter's idea of it.
    _engineHoursController.text = _editable(trip.engineHours);
    _fuelController.text = _editable(trip.fuelConsumedL);
    _crew = List.of(trip.crewMembers ?? const []);
    _notesController.text = trip.notes ?? '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _departurePortController.dispose();
    _arrivalPortController.dispose();
    _engineHoursController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trip = await ref.read(tripProvider(widget.tripId).future);
      final crewList = List<String>.of(_crew);

      final updated = trip.copyWith(
        departurePort: _departurePortController.text.trim(),
        arrivalPort: _arrivalPortController.text.trim().isEmpty
            ? null
            : _arrivalPortController.text.trim(),
        engineHours: double.tryParse(_engineHoursController.text.trim()),
        fuelConsumedL: double.tryParse(_fuelController.text.trim()),
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
        NavisSnackbar.success(
            context, AppLocalizations.of(context)!.tripUpdated);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(
            context, AppLocalizations.of(context)!.failedToUpdateTrip);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Optional, but a number if filled in.
  String? _optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null
        ? AppLocalizations.of(context)!.validNumber
        : null;
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

    final l = AppLocalizations.of(context)!;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.editTrip,
          showBack: true,
        ),
        body: SingleChildScrollView(
          padding: Insets.screenWithNav,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grouped by heading instead of by card. Three stacked cards
                // put a frame around every pair of fields, and the fields are
                // already framed — so the form read as six nested boxes.
                NavisSectionHeader(label: l.tripRoute),
                const SizedBox(height: Dimens.spaceSm),
                NavisTextField(
                  controller: _departurePortController,
                  label: l.departurePort,
                  prefixIcon: Icons.sailing_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.pleaseEnterDeparturePort
                      : null,
                ),
                const SizedBox(height: Dimens.spaceMd),
                NavisTextField(
                  controller: _arrivalPortController,
                  label: l.arrivalPortOptional,
                  prefixIcon: Icons.anchor_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: Dimens.spaceXl),
                NavisSectionHeader(label: l.engineSectionTitle),
                const SizedBox(height: Dimens.spaceSm),
                NavisTextField(
                  controller: _engineHoursController,
                  label: l.engineHoursOptional,
                  prefixIcon: Icons.engineering_rounded,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _optionalNumber,
                ),
                const SizedBox(height: Dimens.spaceMd),
                NavisTextField(
                  controller: _fuelController,
                  label: l.fuelUsedOptional,
                  prefixIcon: Icons.local_gas_station_rounded,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _optionalNumber,
                ),
                const SizedBox(height: Dimens.spaceXl),
                NavisSectionHeader(label: l.crew),
                const SizedBox(height: Dimens.spaceSm),
                CrewChipsField(
                  label: l.crewMembers,
                  initial: _crew,
                  suggestions: _crewSuggestions,
                  onChanged: (crew) => _crew = crew,
                ),
                const SizedBox(height: Dimens.spaceMd),
                NavisTextField(
                  controller: _notesController,
                  label: l.notesOptional,
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: Dimens.spaceXxl),
                NavisButton(
                  label: l.updateTrip,
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
