import 'dart:async';
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
    required this.startTime,
    this.gpsAccuracy,
    this.onClose,
    this.closeSemanticLabel,
  });

  final double speedKnots;
  final double? heading;
  final double distanceNm;

  /// Recording start; the elapsed clock ticks inside its own widget so the
  /// map is not rebuilt every second.
  final DateTime? startTime;
  final double? gpsAccuracy;

  /// Optional leading close/exit action rendered inside the bar. Keeping it
  /// inside the HUD avoids a floating button overlapping the top-left stat.
  final VoidCallback? onClose;
  final String? closeSemanticLabel;

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
                    if (onClose != null) ...[
                      _HudCloseButton(
                        onTap: onClose!,
                        semanticLabel: closeSemanticLabel,
                      ),
                      _divider(),
                    ],
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
                      child: _ElapsedClock(
                        label: l.timeAbbr,
                        startTime: startTime,
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

/// Leading exit control that lives inside the HUD bar (see [NavigationHud.onClose]).
class _HudCloseButton extends StatelessWidget {
  const _HudCloseButton({required this.onTap, this.semanticLabel});

  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 32,
            height: 40,
            child: Icon(
              Icons.close,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-ticking elapsed clock: rebuilds only itself once per second instead
/// of forcing the whole map screen through setState.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.label, required this.startTime});

  final String label;
  final DateTime? startTime;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final start = widget.startTime;
    if (start == null) return '00:00:00';
    final elapsed = DateTime.now().difference(start);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _HudStat(
      label: widget.label,
      value: _formatted,
      unit: '',
      valueColor: AppColors.textPrimary,
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
        // Keep the value on a single line and scale it down if the column is
        // narrow, so ticking digits (the elapsed clock) never wrap and make
        // the whole bar grow/shrink every second.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            maxLines: 1,
            softWrap: false,
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
        ),
      ],
    );
  }
}
