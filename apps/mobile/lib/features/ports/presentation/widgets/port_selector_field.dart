import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/presentation/screens/map_picker_screen.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

/// Reusable port picker: horizontal chips of recommended ports (sorted by
/// distance to a reference point) plus an "Other" chip that opens the map
/// picker. Emits the chosen port name via [onChanged].
///
/// Shared by the trip-completion dialog and the regatta scheduling screen.
class PortSelectorField extends StatefulWidget {
  const PortSelectorField({
    required this.label,
    required this.icon,
    required this.ports,
    required this.onChanged,
    this.refLat,
    this.refLon,
    this.initialName,
    this.mapTitle,
    super.key,
  });

  final String label;
  final IconData icon;
  final List<Port> ports;
  final double? refLat;
  final double? refLon;

  /// Pre-selected port name (matched against [ports] or shown as custom).
  final String? initialName;

  /// Title for the map picker screen.
  final String? mapTitle;

  /// Called with the selected port name (or null if cleared).
  final ValueChanged<String?> onChanged;

  @override
  State<PortSelectorField> createState() => _PortSelectorFieldState();
}

class _PortSelectorFieldState extends State<PortSelectorField> {
  Port? _selectedPort;
  bool _useCustom = false;
  String? _customName;
  late List<Port> _sortedPorts;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(PortSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ports != widget.ports ||
        oldWidget.refLat != widget.refLat ||
        oldWidget.refLon != widget.refLon) {
      _recompute();
    }
  }

  void _recompute() {
    _sortedPorts = _sortedByDistance();
    // Try to match the initial/selected name against the available ports.
    final name = _customName ?? _selectedPort?.name ?? widget.initialName;
    Port? match;
    for (final p in _sortedPorts) {
      if (p.name == name) {
        match = p;
        break;
      }
    }
    if (match != null) {
      _selectedPort = match;
      _useCustom = false;
    } else if (name != null && name.isNotEmpty) {
      _useCustom = true;
      _customName = name;
    } else if (_sortedPorts.isNotEmpty) {
      _selectedPort = _sortedPorts.first;
      _useCustom = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_sortedPorts.first.name);
      });
    }
  }

  List<Port> _sortedByDistance() {
    if (widget.refLat == null || widget.refLon == null) return widget.ports;
    final sorted = List<Port>.from(widget.ports);
    sorted.sort((a, b) {
      final dA = _haversine(widget.refLat!, widget.refLon!, a.lat, a.lon);
      final dB = _haversine(widget.refLat!, widget.refLon!, b.lat, b.lon);
      return dA.compareTo(dB);
    });
    return sorted;
  }

  Future<void> _openSearch() async {
    final port = await showModalBottomSheet<Port>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PortSearchSheet(),
    );
    if (port != null && mounted) {
      setState(() {
        _useCustom = true;
        _selectedPort = null;
        _customName = port.name;
      });
      widget.onChanged(port.name);
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: widget.mapTitle ?? widget.label,
          showNameField: true,
          initialLatitude: widget.refLat,
          initialLongitude: widget.refLon,
        ),
      ),
    );
    if (result != null && result.name != null && mounted) {
      setState(() {
        _useCustom = true;
        _selectedPort = null;
        _customName = result.name;
      });
      widget.onChanged(result.name);
    }
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

  double? _distanceTo(Port port) {
    if (widget.refLat == null || widget.refLon == null) return null;
    return _haversine(widget.refLat!, widget.refLon!, port.lat, port.lon);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Row(
            children: [
              Icon(widget.icon, size: 16, color: context.txtSecondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.txtSecondary,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sortedPorts.length + 2,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == _sortedPorts.length) {
                return _ActionChip(
                  icon: Icons.search,
                  label: 'Buscar',
                  onTap: _openSearch,
                );
              }
              if (index == _sortedPorts.length + 1) {
                return _ActionChip(
                  icon: Icons.edit_location_alt,
                  label: 'Mapa',
                  isSelected: _useCustom,
                  onTap: _openMapPicker,
                );
              }
              final port = _sortedPorts[index];
              final isSelected = !_useCustom && _selectedPort == port;
              return _PortChip(
                port: port,
                isSelected: isSelected,
                distance: _distanceTo(port),
                icon: _portIcon(port.portType),
                onTap: () {
                  setState(() {
                    _selectedPort = port;
                    _useCustom = false;
                    _customName = null;
                  });
                  widget.onChanged(port.name);
                },
              );
            },
          ),
        ),
        if (_useCustom && _customName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.cyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _customName!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.cyan),
                  ),
                ),
                GestureDetector(
                  onTap: _openMapPicker,
                  child:
                      Icon(Icons.edit, color: context.txtSecondary, size: 16),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
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
              icon,
              size: 20,
              color: isSelected ? AppColors.cyan : context.txtSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
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
}

/// Bottom sheet to search all ports by name and pick one.
class _PortSearchSheet extends ConsumerStatefulWidget {
  const _PortSearchSheet();

  @override
  ConsumerState<_PortSearchSheet> createState() => _PortSearchSheetState();
}

class _PortSearchSheetState extends ConsumerState<_PortSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final portsAsync = ref.watch(allPortsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: context.dialogSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.glassBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              style: TextStyle(color: context.txtPrimary),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar puerto por nombre…',
                hintStyle: TextStyle(color: context.txtSecondary),
                prefixIcon: Icon(Icons.search, color: context.txtSecondary),
                filled: true,
                fillColor: context.glassBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: portsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.red))),
              data: (ports) {
                final filtered = _query.isEmpty
                    ? ports
                    : ports
                        .where((p) => p.name.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: context.txtSecondary)),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return ListTile(
                      leading: const Icon(Icons.anchor, color: AppColors.cyan),
                      title: Text(p.name,
                          style: TextStyle(color: context.txtPrimary)),
                      subtitle: Text(p.country,
                          style: TextStyle(color: context.txtSecondary)),
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
                Icon(icon,
                    size: 14,
                    color: isSelected ? AppColors.cyan : context.txtSecondary),
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
