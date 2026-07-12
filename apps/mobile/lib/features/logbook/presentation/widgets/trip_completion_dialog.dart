import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/presentation/screens/map_picker_screen.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/shared/widgets/crew_chips_field.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

class TripCompletionData {
  const TripCompletionData({
    this.departurePort,
    this.arrivalPort,
    this.engineHours,
    this.fuelConsumedL,
    this.crewMembers,
    this.notes,
  });

  final String? departurePort;
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
    this.nearbyPorts = const [],
    this.startLat,
    this.startLon,
    this.endLat,
    this.endLon,
    this.initialCrew = const [],
    this.crewSuggestions = const [],
  });

  final double? distanceNm;
  final Duration? duration;
  final double? avgSpeed;
  final List<Port> nearbyPorts;
  final double? startLat;
  final double? startLon;
  final double? endLat;
  final double? endLon;

  /// Crew names to pre-fill (e.g. group members who RSVP'd "going").
  final List<String> initialCrew;

  /// Quick-add crew suggestions shown below the input.
  final List<String> crewSuggestions;

  @override
  State<TripCompletionDialog> createState() => _TripCompletionDialogState();
}

class _TripCompletionDialogState extends State<TripCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _engineHoursCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late List<String> _crew = List.of(widget.initialCrew);

  Port? _selectedDeparturePort;
  bool _useCustomDeparture = false;
  String? _customDepartureName;

  Port? _selectedArrivalPort;
  bool _useCustomArrival = false;
  String? _customArrivalName;

  List<Port> _departurePorts = [];
  List<Port> _arrivalPorts = [];

  @override
  void initState() {
    super.initState();
    _departurePorts = _sortedByDistance(widget.startLat, widget.startLon);
    _arrivalPorts = _sortedByDistance(widget.endLat, widget.endLon);

    if (_departurePorts.isNotEmpty) {
      _selectedDeparturePort = _departurePorts.first;
    } else {
      _useCustomDeparture = true;
    }

    if (_arrivalPorts.isNotEmpty) {
      _selectedArrivalPort = _arrivalPorts.first;
    } else {
      _useCustomArrival = true;
    }
  }

  List<Port> _sortedByDistance(double? lat, double? lon) {
    if (lat == null || lon == null) return widget.nearbyPorts;
    final sorted = List<Port>.from(widget.nearbyPorts);
    sorted.sort((a, b) {
      final dA = _haversine(lat, lon, a.lat, a.lon);
      final dB = _haversine(lat, lon, b.lat, b.lon);
      return dA.compareTo(dB);
    });
    return sorted;
  }

  Future<void> _openMapPicker({required bool isDeparture}) async {
    final l = AppLocalizations.of(context)!;
    final lat = isDeparture ? widget.startLat : widget.endLat;
    final lon = isDeparture ? widget.startLon : widget.endLon;
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isDeparture ? l.departurePort : l.selectArrivalPort,
          showNameField: true,
          initialLatitude: lat,
          initialLongitude: lon,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isDeparture) {
          _useCustomDeparture = true;
          _selectedDeparturePort = null;
          _customDepartureName = result.name;
        } else {
          _useCustomArrival = true;
          _selectedArrivalPort = null;
          _customArrivalName = result.name;
        }
      });
    }
  }

  @override
  void dispose() {
    _engineHoursCtrl.dispose();
    _fuelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 3440.065;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double? _distanceFromPoint(Port port, double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    return _haversine(lat, lon, port.lat, port.lon);
  }

  double _toRad(double deg) => deg * math.pi / 180;

  IconData _portIcon(PortType type) => switch (type) {
        PortType.marina => Icons.anchor,
        PortType.anchorage => Icons.water,
        PortType.fuel => Icons.local_gas_station,
        PortType.commercial => Icons.business,
        PortType.fishing => Icons.phishing,
        PortType.other => Icons.location_on,
      };

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: context.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.glassBorderColor,
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
                _buildHeader(context),
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
                      _buildPortSection(
                        context,
                        label: AppLocalizations.of(context)!.departurePort,
                        icon: Icons.flight_takeoff,
                        ports: _departurePorts,
                        refLat: widget.startLat,
                        refLon: widget.startLon,
                        selectedPort: _selectedDeparturePort,
                        useCustom: _useCustomDeparture,
                        customName: _customDepartureName,
                        onSelectPort: (port) => setState(() {
                          _selectedDeparturePort = port;
                          _useCustomDeparture = false;
                        }),
                        onPickMap: () => _openMapPicker(isDeparture: true),
                      ),
                      const SizedBox(height: 12),
                      _buildPortSection(
                        context,
                        label: AppLocalizations.of(context)!.arrivalPort,
                        icon: Icons.flight_land,
                        ports: _arrivalPorts,
                        refLat: widget.endLat,
                        refLon: widget.endLon,
                        selectedPort: _selectedArrivalPort,
                        useCustom: _useCustomArrival,
                        customName: _customArrivalName,
                        onSelectPort: (port) => setState(() {
                          _selectedArrivalPort = port;
                          _useCustomArrival = false;
                        }),
                        onPickMap: () => _openMapPicker(isDeparture: false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _engineHoursCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.engineHours,
                          prefixIcon: const Icon(Icons.engineering),
                          suffixText: 'h',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) {
                            return AppLocalizations.of(context)!
                                .enterValidNumber;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fuelCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.fuelUsed,
                          prefixIcon: const Icon(Icons.local_gas_station),
                          suffixText: 'L',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = double.tryParse(v);
                          if (n == null || n < 0) {
                            return AppLocalizations.of(context)!
                                .enterValidNumber;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CrewChipsField(
                        label: AppLocalizations.of(context)!.crewMembers,
                        initial: widget.initialCrew,
                        suggestions: widget.crewSuggestions,
                        onChanged: (crew) => _crew = crew,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.notes,
                          prefixIcon: const Icon(Icons.notes),
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
                        label: AppLocalizations.of(context)!.cancel,
                        variant: NavisButtonVariant.secondary,
                        compact: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NavisButton(
                        label: AppLocalizations.of(context)!.saveTrip,
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.glassBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.glassBorderColor,
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
          AppLocalizations.of(context)!.completeTrip,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildPortSection(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<Port> ports,
    required double? refLat,
    required double? refLon,
    required Port? selectedPort,
    required bool useCustom,
    required String? customName,
    required ValueChanged<Port> onSelectPort,
    required VoidCallback onPickMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: context.txtSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.txtSecondary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ports.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == ports.length) {
                return _buildCustomChip(
                  context,
                  isSelected: useCustom,
                  onTap: onPickMap,
                );
              }
              final port = ports[index];
              final isSelected = !useCustom && selectedPort == port;
              final dist = _distanceFromPoint(port, refLat, refLon);
              return _PortChip(
                port: port,
                isSelected: isSelected,
                distance: dist,
                icon: _portIcon(port.portType),
                onTap: () => onSelectPort(port),
              );
            },
          ),
        ),
        if (useCustom && customName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.cyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.cyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.cyan),
                  ),
                ),
                GestureDetector(
                  onTap: onPickMap,
                  child: Icon(
                    Icons.edit,
                    color: context.txtSecondary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomChip(
    BuildContext context, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyan.withValues(alpha: 0.15)
              : context.glassBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.cyan : context.glassBorderColor,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_location_alt,
              size: 20,
              color: isSelected ? AppColors.cyan : context.txtSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              l.other,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? AppColors.cyan : context.txtSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

    final crew = _crew.isEmpty ? null : List<String>.of(_crew);

    final departure = _useCustomDeparture
        ? _customDepartureName
        : _selectedDeparturePort?.name;

    final arrival =
        _useCustomArrival ? _customArrivalName : _selectedArrivalPort?.name;

    final data = TripCompletionData(
      departurePort: departure,
      arrivalPort: arrival,
      engineHours: double.tryParse(_engineHoursCtrl.text),
      fuelConsumedL: double.tryParse(_fuelCtrl.text),
      crewMembers: crew,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    Navigator.of(context).pop(data);
  }
}

class _PortChip extends StatelessWidget {
  const _PortChip({
    required this.port,
    required this.isSelected,
    required this.icon,
    required this.onTap,
    this.distance,
  });

  final Port port;
  final bool isSelected;
  final double? distance;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyan.withValues(alpha: 0.15)
              : context.glassBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.cyan : context.glassBorderColor,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? AppColors.cyan : context.txtSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    port.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              isSelected ? AppColors.cyan : context.txtPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 11,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (distance != null) ...[
              const SizedBox(height: 2),
              Text(
                '${distance!.toStringAsFixed(1)} NM',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.txtSecondary,
                      fontSize: 10,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: context.glassBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.glassBorderColor,
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
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
