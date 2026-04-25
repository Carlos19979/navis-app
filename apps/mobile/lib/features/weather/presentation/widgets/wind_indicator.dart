import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class WindIndicator extends StatelessWidget {
  const WindIndicator({
    super.key,
    required this.direction,
    required this.speed,
    this.size = 60,
  });

  final double direction;
  final double speed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WindArrowPainter(
              direction: direction,
              color: AppColors.cyan,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${speed.toStringAsFixed(0)} kt',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          _degreesToCardinal(direction),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  String _degreesToCardinal(double degrees) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

class _WindArrowPainter extends CustomPainter {
  _WindArrowPainter({required this.direction, required this.color});

  final double direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw circle
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw arrow
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(direction * math.pi / 180);

    final path = Path()
      ..moveTo(0, -radius + 4)
      ..lineTo(-6, radius * 0.3)
      ..lineTo(0, radius * 0.15)
      ..lineTo(6, radius * 0.3)
      ..close();

    canvas.drawPath(path, arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WindArrowPainter oldDelegate) {
    return direction != oldDelegate.direction || color != oldDelegate.color;
  }
}
