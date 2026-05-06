import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

void showPortInfoSheet(
  BuildContext context, {
  required Port port,
  LatLng? userPosition,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navy,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _PortInfoContent(
      port: port,
      userPosition: userPosition,
    ),
  );
}

class _PortInfoContent extends StatelessWidget {
  const _PortInfoContent({
    required this.port,
    this.userPosition,
  });

  final Port port;
  final LatLng? userPosition;

  String _localizedPortType(AppLocalizations l, PortType type) =>
      switch (type) {
        PortType.marina => l.portTypeMarina,
        PortType.anchorage => l.portTypeAnchorage,
        PortType.fuel => l.portTypeFuel,
        PortType.commercial => l.portTypeCommercial,
        PortType.fishing => l.portTypeFishing,
        PortType.other => l.portTypeOther,
      };

  IconData _iconForType(PortType type) => switch (type) {
        PortType.marina => Icons.anchor,
        PortType.anchorage => Icons.water,
        PortType.fuel => Icons.local_gas_station,
        PortType.commercial => Icons.business,
        PortType.fishing => Icons.set_meal,
        PortType.other => Icons.location_on,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final distance = userPosition != null
        ? DistanceUtils.calculateDistance(
            userPosition!.latitude,
            userPosition!.longitude,
            port.lat,
            port.lon,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                child: Icon(
                  _iconForType(port.portType),
                  color: AppColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      port.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${_localizedPortType(l, port.portType)}'
                      ' \u00b7 ${port.country}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)} nm',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          if (port.facilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: port.facilities
                  .map(
                    (f) => Chip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.glassWhite,
                      side: const BorderSide(
                        color: AppColors.glassBorder,
                        width: 0.5,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (port.depthM != null || port.vhfChannel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (port.depthM != null)
                  Text(
                    l.depthLabel(port.depthM!.toStringAsFixed(1)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (port.depthM != null && port.vhfChannel != null)
                  Text(
                    ' \u00b7 ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (port.vhfChannel != null)
                  Text(
                    l.vhfChannelLabel(port.vhfChannel!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ],
          if (port.website != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                final uri = Uri.tryParse(port.website!);
                if (uri != null) launchUrl(uri);
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.language,
                    size: 14,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      port.website!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.cyan,
                            decoration: TextDecoration.underline,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + 16,
          ),
        ],
      ),
    );
  }
}
