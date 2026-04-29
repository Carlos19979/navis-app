import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class WaveChart extends StatefulWidget {
  const WaveChart({super.key, required this.waveHeight});

  final double waveHeight;

  @override
  State<WaveChart> createState() => _WaveChartState();
}

class _WaveChartState extends State<WaveChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  Color _getWaveColor(double height) {
    if (height < 0.5) return AppColors.green;
    if (height < 1.5) return AppColors.cyan;
    if (height < 2.5) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final waveColor = _getWaveColor(widget.waveHeight);

    return NavisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wave Height',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: waveColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: waveColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${widget.waveHeight.toStringAsFixed(1)} m',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: waveColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: AnimatedBuilder(
              animation: _driftController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _WavePainter(
                    waveHeight: widget.waveHeight,
                    color: waveColor,
                    drift: _driftController.value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _WaveLabel(label: 'Calm', color: AppColors.green),
              _WaveLabel(label: 'Moderate', color: AppColors.amber),
              _WaveLabel(label: 'Rough', color: AppColors.red),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveLabel extends StatelessWidget {
  const _WaveLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.waveHeight,
    required this.color,
    required this.drift,
  });

  final double waveHeight;
  final Color color;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = (waveHeight / 4.0).clamp(0.1, 1.0) * size.height * 0.4;
    const frequency = 3.0;
    final driftOffset = drift * size.width;

    // Gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Stroke line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Build wave path
    final fillPath = Path();
    fillPath.moveTo(0, size.height);

    final linePath = Path();

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          amplitude *
              math.sin(
                  2 * math.pi * frequency * (x + driftOffset) / size.width);
      if (x == 0) {
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return waveHeight != oldDelegate.waveHeight ||
        color != oldDelegate.color ||
        drift != oldDelegate.drift;
  }
}
