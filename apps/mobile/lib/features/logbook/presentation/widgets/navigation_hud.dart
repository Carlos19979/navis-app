import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class NavigationHud extends StatelessWidget {
  const NavigationHud({
    super.key,
    required this.speedKnots,
    required this.heading,
    required this.distanceNm,
    required this.elapsed,
    this.gpsAccuracy,
  });

  final double speedKnots;
  final double? heading;
  final double distanceNm;
  final Duration elapsed;
  final double? gpsAccuracy;

  String get _formattedTime {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String get _headingLabel {
    if (heading == null) return '---';
    return '${heading!.toStringAsFixed(0)}\u00b0';
  }

  Color get _gpsColor {
    if (gpsAccuracy == null) return AppColors.textSecondary;
    if (gpsAccuracy! < 10) return AppColors.green;
    if (gpsAccuracy! < 25) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HudStat(
                        label: l.speedAbbr,
                        value: speedKnots.toStringAsFixed(1),
                        unit: 'kn',
                        valueColor: AppColors.cyan,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: _HudStat(
                        label: l.headingAbbr,
                        value: _headingLabel,
                        unit: '',
                        valueColor: AppColors.textPrimary,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: _HudStat(
                        label: l.distanceAbbr,
                        value: distanceNm.toStringAsFixed(2),
                        unit: 'nm',
                        valueColor: AppColors.green,
                      ),
                    ),
                    _divider(),
                    Expanded(
                      child: _HudStat(
                        label: l.timeAbbr,
                        value: _formattedTime,
                        unit: '',
                        valueColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (gpsAccuracy != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        size: 10,
                        color: _gpsColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\u00b1${gpsAccuracy!.toStringAsFixed(0)}m',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _gpsColor,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 0.5,
      height: 32,
      color: AppColors.glassBorder,
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 2),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
