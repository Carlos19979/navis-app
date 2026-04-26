import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class WaveChart extends StatelessWidget {
  const WaveChart({super.key, required this.waveHeight});

  final double waveHeight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wave Height',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${waveHeight.toStringAsFixed(1)} m',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _getWaveColor(waveHeight),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _WavePainter(
                  waveHeight: waveHeight,
                  color: _getWaveColor(waveHeight),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  Color _getWaveColor(double height) {
    if (height < 0.5) return AppColors.green;
    if (height < 1.5) return AppColors.cyan;
    if (height < 2.5) return AppColors.amber;
    return AppColors.red;
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
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.waveHeight, required this.color});

  final double waveHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final amplitude = (waveHeight / 4.0).clamp(0.1, 1.0) * size.height * 0.4;
    const frequency = 3.0;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          amplitude * math.sin(2 * math.pi * frequency * x / size.width);
      if (x == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final linePath = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          amplitude * math.sin(2 * math.pi * frequency * x / size.width);
      if (x == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return waveHeight != oldDelegate.waveHeight || color != oldDelegate.color;
  }
}
